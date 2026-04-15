local nk = require("nakama")

local function read_stats_map(user_ids)
  local reads = {}
  for _, uid in ipairs(user_ids) do
    table.insert(reads, {
      collection = "player_stats",
      key = "summary",
      user_id = uid
    })
  end

  local records = nk.storage_read(reads)
  local by_user = {}
  for _, r in ipairs(records or {}) do
    by_user[r.user_id] = r.value or {}
  end
  return by_user
end

-- FIX: match_list signature: (limit, authoritative, label, min_size, max_size)
-- We want matches with exactly 1 player (waiting for opponent)
local function find_match(context, payload)
  local mode = "classic"

  if payload ~= nil and payload ~= "" then
    local ok, data = pcall(nk.json_decode, payload)
    if ok and data then
      -- Some clients may send a JSON-encoded string, which decodes to a Lua
      -- string first. Decode once more to get the actual object.
      if type(data) == "string" then
        local ok2, data2 = pcall(nk.json_decode, data)
        if ok2 and type(data2) == "table" then
          data = data2
        end
      end

      if type(data) == "table" and data.mode then
        mode = data.mode
      end
    end
  end

  -- List authoritative matches with label "tictactoe" that have exactly 1 player
  local matches = nk.match_list(10, true, "tictactoe", 1, 1)

  for _, m in ipairs(matches) do
    -- Join the first available match waiting for a second player
    return nk.json_encode({
      matchId = m.match_id,
      joined  = true,
      mode    = mode
    })
  end

  -- No open match found — create a new one
  local match_id = nk.match_create("match", { mode = mode })

  return nk.json_encode({
    matchId = match_id,
    created = true,
    mode    = mode
  })
end

local function cancel_matchmaking(context, payload)
  return nk.json_encode({
    status = "cancelled",
    userId = context.user_id
  })
end

local function get_leaderboard(context, payload)
  local ok, records, _, _, next_cursor = pcall(function()
    -- Lua runtime returns multiple values:
    -- records, owner_records, prev_cursor, next_cursor
    return nk.leaderboard_records_list("wins", nil, 10, nil)
  end)

  if not ok then
    nk.logger_error("Leaderboard fetch failed: " .. tostring(records))
    return nk.json_encode({ error = "leaderboard not found", records = {} })
  end

  local out = {}
  local raw_records = records or {}
  local user_ids = {}

  for _, r in pairs(raw_records) do
    local owner_id = r.owner_id or r.ownerId
    if owner_id then
      table.insert(user_ids, owner_id)
    end
  end

  local stats_map = read_stats_map(user_ids)

  for _, r in pairs(raw_records) do
    local owner_id = r.owner_id or r.ownerId
    local stats = stats_map[owner_id] or {}
    table.insert(out, {
      ownerId  = owner_id,
      username = r.username,
      score    = r.score or 0, -- wins from leaderboard
      wins     = stats.wins or (r.score or 0),
      losses   = stats.losses or 0,
      currentStreak = stats.currentStreak or 0,
      bestStreak    = stats.bestStreak or 0,
      subscore = r.subscore or 0,
      rank     = r.rank
    })
  end

  table.sort(out, function(a, b)
    if a.score == b.score then
      return (a.subscore or 0) > (b.subscore or 0)
    end
    return (a.score or 0) > (b.score or 0)
  end)

  return nk.json_encode({
    records    = out,
    nextCursor = next_cursor or nil
  })
end

return {
  find_match         = find_match,
  cancel_matchmaking = cancel_matchmaking,
  get_leaderboard    = get_leaderboard,
}