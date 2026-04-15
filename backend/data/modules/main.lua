local nk = require("nakama")
local rpc = require("rpc")
local match = require("match")

-- Register Match handler
nk.register_match("match", match)

-- Register RPC functions
nk.register_rpc(rpc.find_match, "find_match")
nk.register_rpc(rpc.cancel_matchmaking, "cancel_matchmaking")
nk.register_rpc(rpc.get_leaderboard, "get_leaderboard")

-- Create Leaderboard if it doesn't exist
local function create_leaderboard()
  local id = "wins"
  local authoritative = true
  local sort_order = "desc"
  local operator = "best"
  local reset_schedule = nil
  local metadata = {}
  nk.leaderboard_create(id, authoritative, sort_order, operator, reset_schedule, metadata)
end

create_leaderboard()
nk.logger_info("Nakama backend initialized: Match registered and Leaderboard created.")