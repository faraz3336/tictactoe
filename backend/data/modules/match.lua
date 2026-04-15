local nk = require("nakama")

local function empty_board()
  return { "", "", "", "", "", "", "", "", "" }
end

local function check_winner(board)
  local wins = {
    { 1, 2, 3 }, { 4, 5, 6 }, { 7, 8, 9 },
    { 1, 4, 7 }, { 2, 5, 8 }, { 3, 6, 9 },
    { 1, 5, 9 }, { 3, 5, 7 }
  }
  for _, w in ipairs(wins) do
    if board[w[1]] ~= "" and
       board[w[1]] == board[w[2]] and
       board[w[2]] == board[w[3]] then
      return board[w[1]]
    end
  end
  return nil
end

-- Record a win on the leaderboard (fire-and-forget, errors are logged not raised)
local function record_win(winner_id)
  if not winner_id or winner_id == "draw" or winner_id == "abandoned" then
    return
  end
  local ok, err = pcall(function()
    -- increment = true, override = false
    nk.leaderboard_record_write("wins", winner_id, nil, 1, nil, nil)
  end)
  if not ok then
    nk.logger_error("record_win failed: " .. tostring(err))
  end
end

local function read_player_stats(user_id)
  local records = nk.storage_read({
    {
      collection = "player_stats",
      key = "summary",
      user_id = user_id
    }
  })

  if records and #records > 0 and records[1].value then
    return records[1].value
  end

  return {
    wins = 0,
    losses = 0,
    currentStreak = 0,
    bestStreak = 0
  }
end

local function write_player_stats(user_id, stats)
  nk.storage_write({
    {
      collection = "player_stats",
      key = "summary",
      user_id = user_id,
      value = stats,
      permission_read = 2,
      permission_write = 0
    }
  })
end

local function update_match_stats(winner_id, loser_id)
  if winner_id then
    local winner = read_player_stats(winner_id)
    winner.wins = (winner.wins or 0) + 1
    winner.currentStreak = (winner.currentStreak or 0) + 1
    winner.bestStreak = math.max(winner.bestStreak or 0, winner.currentStreak)
    write_player_stats(winner_id, winner)
  end

  if loser_id then
    local loser = read_player_stats(loser_id)
    loser.losses = (loser.losses or 0) + 1
    loser.currentStreak = 0
    loser.bestStreak = loser.bestStreak or 0
    write_player_stats(loser_id, loser)
  end
end

-- ─── INIT ───────────────────────────────────────────────────────────────────

function match_init(context, params)
  local mode = (params and params.mode) or "classic"

  local state = {
    board         = empty_board(),
    marks         = {},     -- userId -> "X" / "O"
    players       = {},     -- ordered list of userIds
    turn          = "",
    phase         = "waiting",
    winner        = nil,
    mode          = mode,
    move_count    = 0,
    deadline      = 0,
    turn_duration = (mode == "timed") and 30 or 0,
  }

  return state, 1, "tictactoe"
end

-- ─── JOIN ATTEMPT ────────────────────────────────────────────────────────────

function match_join_attempt(context, dispatcher, tick, state, presence, metadata)
  if #state.players >= 2 then
    return state, false, "match full"
  end
  return state, true
end

-- ─── JOIN ────────────────────────────────────────────────────────────────────

function match_join(context, dispatcher, tick, state, presences)
  for _, p in ipairs(presences) do
    -- Avoid duplicates
    local exists = false
    for _, uid in ipairs(state.players) do
      if uid == p.user_id then
        exists = true
        break
      end
    end

    if not exists then
      table.insert(state.players, p.user_id)
      state.marks[p.user_id] = (#state.players == 1) and "X" or "O"
    end
  end

  if #state.players == 2 and state.phase == "waiting" then
    state.phase = "playing"
    state.turn  = state.players[1]

    if state.mode == "timed" then
      state.deadline = os.time() + state.turn_duration
    end

    nk.logger_info("Match started: " .. context.match_id)
  end

  dispatcher.broadcast_message(1, nk.json_encode(state), nil, nil, true)
  return state
end

-- ─── LEAVE ───────────────────────────────────────────────────────────────────

function match_leave(context, dispatcher, tick, state, presences)
  for _, p in ipairs(presences) do
    -- FIX: remove from players array (was only removing from marks before)
    for i = #state.players, 1, -1 do
      if state.players[i] == p.user_id then
        table.remove(state.players, i)
        break
      end
    end
    state.marks[p.user_id] = nil
  end

  if state.phase == "playing" then
    state.phase  = "finished"
    state.winner = "abandoned"
    dispatcher.broadcast_message(1, nk.json_encode(state), nil, nil, true)
  end

  return state
end

function match_signal(context, dispatcher, tick, state, data)
  return state, nil
end

-- ─── LOOP ────────────────────────────────────────────────────────────────────

function match_loop(context, dispatcher, tick, state, messages)
  if state.phase ~= "playing" then
    return state
  end

  -- FIX: enforce turn timer expiry
  if state.mode == "timed" and state.deadline > 0 then
    if os.time() >= state.deadline then
      -- Current player forfeits their turn; if they ran out on every move
      -- we could award the opponent the win, but a simpler UX is to just
      -- rotate the turn and reset the clock.
      for _, p in ipairs(state.players) do
        if p ~= state.turn then
          state.turn     = p
          state.deadline = os.time() + state.turn_duration
          break
        end
      end
      dispatcher.broadcast_message(1, nk.json_encode(state), nil, nil, true)
      return state
    end
  end

  local state_changed = false

  for _, msg in ipairs(messages) do
    if msg.op_code ~= 1 then goto continue end
    if msg.sender.user_id ~= state.turn then goto continue end

    local ok, data = pcall(nk.json_decode, msg.data)
    if not ok or not data then goto continue end

    local cell = data.cell
    -- cell is 0-based from the client
    if type(cell) ~= "number" or cell < 0 or cell > 8 then goto continue end

    local idx = cell + 1   -- Lua is 1-based
    if state.board[idx] ~= "" then goto continue end

    -- Apply move
    state.board[idx]  = state.marks[msg.sender.user_id]
    state.move_count  = state.move_count + 1
    state_changed     = true

    local winner_mark = check_winner(state.board)

    if winner_mark then
      state.phase = "finished"
      for uid, mark in pairs(state.marks) do
        if mark == winner_mark then
          state.winner = uid
          break
        end
      end
      record_win(state.winner)
      local loser_id = nil
      for _, p in ipairs(state.players) do
        if p ~= state.winner then
          loser_id = p
          break
        end
      end
      update_match_stats(state.winner, loser_id)

    elseif state.move_count >= 9 then
      state.phase  = "finished"
      state.winner = "draw"

    else
      -- Rotate turn
      for _, p in ipairs(state.players) do
        if p ~= state.turn then
          state.turn = p
          break
        end
      end
      if state.mode == "timed" then
        state.deadline = os.time() + state.turn_duration
      end
    end

    ::continue::
  end

  if state_changed then
    dispatcher.broadcast_message(1, nk.json_encode(state), nil, nil, true)
  end

  return state
end

-- ─── TERMINATE ───────────────────────────────────────────────────────────────

function match_terminate(context, dispatcher, tick, state, grace_seconds)
  nk.logger_info("Match terminated: " .. context.match_id)
  dispatcher.broadcast_message(1, nk.json_encode({ phase = "terminated" }), nil, nil, true)
  return nil
end

return {
  match_init         = match_init,
  match_join_attempt = match_join_attempt,
  match_join         = match_join,
  match_leave        = match_leave,
  match_signal       = match_signal,
  match_loop         = match_loop,
  match_terminate    = match_terminate,
}