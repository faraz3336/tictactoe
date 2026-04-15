local nk = require("nakama")
local rpc = require("rpc")

-- Register RPC functions
nk.register_rpc(rpc.find_match, "find_match")
nk.register_rpc(rpc.cancel_matchmaking, "cancel_matchmaking")
nk.register_rpc(rpc.get_leaderboard, "get_leaderboard")