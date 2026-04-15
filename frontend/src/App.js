import React, { useState, useEffect, useRef } from "react";
import { Client } from "@heroiclabs/nakama-js";
import Board from "./components/Board";
import Leaderboard from "./components/Leaderboard";
import Timer from "./components/Timer";
import "./App.css";

const NAKAMA_HOST = process.env.REACT_APP_NAKAMA_HOST || "localhost";
const NAKAMA_PORT = Number(process.env.REACT_APP_NAKAMA_PORT || "7350");
const NAKAMA_SERVER_KEY = process.env.REACT_APP_NAKAMA_SERVER_KEY || "defaultkey";
const NAKAMA_USE_SSL = process.env.REACT_APP_NAKAMA_SSL === "true";

function App() {
  const [client] = useState(
    () => new Client(NAKAMA_SERVER_KEY, NAKAMA_HOST, NAKAMA_PORT, NAKAMA_USE_SSL)
  );

  const [session, setSession]       = useState(null);
  const [matchId, setMatchId]       = useState(null);
  const [matchState, setMatchState] = useState(null);
  const [loading, setLoading]       = useState(false);
  const [mode, setMode]             = useState("classic");
  const [statusText, setStatusText] = useState("Waiting for an opponent...");

  const socketRef = useRef(null);

  useEffect(() => {
    authenticate();
    return () => socketRef.current?.disconnect();
  }, []);

  // ─── AUTH ──────────────────────────────────────────────────────────────────
  const authenticate = async () => {
    try {
      let deviceId = localStorage.getItem("deviceId");
      if (!deviceId) {
        deviceId =
          (typeof crypto !== "undefined" && crypto.randomUUID?.()) ||
          Math.random().toString(36).substring(2);
        localStorage.setItem("deviceId", deviceId);
      }

      const sess = await client.authenticateDevice(deviceId, true);
      setSession(sess);

      const socket = client.createSocket(NAKAMA_USE_SSL, true);
      await socket.connect(sess, false);
      socketRef.current = socket;

      socket.onmatchdata = (data) => {
        if (data.op_code !== 1) {
          return;
        }

        try {
          const payload = typeof data.data === "string"
            ? data.data
            : new TextDecoder().decode(data.data);
          const state = JSON.parse(payload);
          setMatchState(state);
        } catch (err) {
          console.error("Failed to parse match state payload:", err);
        }
      };

      socket.onmatchpresence = (presenceEvent) => {
        const joins = presenceEvent?.joins?.length || 0;
        const leaves = presenceEvent?.leaves?.length || 0;
        if (joins > 0 || leaves > 0) {
          setStatusText("Match presence changed. Waiting for server update...");
        }
      };
    } catch (err) {
      console.error("Auth error:", err);
    }
  };

  // ─── FIND MATCH ────────────────────────────────────────────────────────────
  const findMatch = async () => {
    if (!session || loading) return;
    setLoading(true);
    setStatusText("Finding a room...");

    try {
      const result = await client.rpc(session, "find_match", { mode });

      const data = typeof result.payload === "string"
        ? JSON.parse(result.payload)
        : result.payload;

      const id = data?.matchId;
      if (!id) throw new Error("matchId missing from RPC response");

      await socketRef.current.joinMatch(id);
      setMatchId(id);
      setStatusText("Connected. Waiting for an opponent...");
    } catch (err) {
      console.error("Find match error:", err);
      const message = err?.message || err?.statusText || `HTTP ${err?.status || "unknown"}`;
      alert("Error finding match: " + message);
      setStatusText("Failed to find a match.");
    }

    setLoading(false);
  };

  // ─── MOVE ──────────────────────────────────────────────────────────────────
  const makeMove = (cellIndex) => {
    if (!matchState || !socketRef.current || !matchId) return;
    if (matchState.phase !== "playing") return;
    if (matchState.turn !== session.user_id) return;

    // FIX: sendMatchState expects (matchId, opCode, data) where data must be
    // a JSON string or Uint8Array — NOT a plain object.
    socketRef.current
      .sendMatchState(matchId, 1, JSON.stringify({ cell: cellIndex }))
      .catch((err) => console.error("Send move failed:", err));
  };

  // ─── LEAVE ─────────────────────────────────────────────────────────────────
  const leaveMatch = async () => {
    if (socketRef.current && matchId) {
      await socketRef.current.leaveMatch(matchId);
    }
    setMatchId(null);
    setMatchState(null);
    setStatusText("Left match.");
  };

  // ─── UI ────────────────────────────────────────────────────────────────────
  if (!session) {
    return <div className="loading">🔄 Connecting to server…</div>;
  }

  const myMark     = matchState?.marks?.[session.user_id] ?? "?";
  const isMyTurn   = matchState?.turn === session.user_id;
  const isFinished = matchState?.phase === "finished";

  const resultText = (() => {
    if (!isFinished) return null;
    if (matchState.winner === "draw")      return "🤝 It's a draw!";
    if (matchState.winner === "abandoned") return "💨 Opponent left.";
    if (matchState.winner === session.user_id) return "🏆 You win!";
    return "😔 You lose.";
  })();

  return (
    <div className="app">
      <h1>🎮 Tic Tac Toe Multiplayer</h1>

      {!matchId ? (
        <div className="menu">
          <h2>Select Mode</h2>
          <div className="mode-buttons">
            <button
              className={mode === "classic" ? "active" : ""}
              onClick={() => setMode("classic")}
            >
              Classic
            </button>
            <button
              className={mode === "timed" ? "active" : ""}
              onClick={() => setMode("timed")}
            >
              ⏱ Timed
            </button>
          </div>
          <button onClick={findMatch} disabled={loading}>
            {loading ? "Searching…" : "Find Match"}
          </button>
        </div>
      ) : (
        <div className="game">
          {matchState ? (
            <>
              <div className="info">
                <div>You are: <strong>{myMark}</strong></div>
                <div>{isMyTurn ? "⚡ Your turn" : "⏳ Opponent's turn"}</div>
              </div>

              {matchState.mode === "timed" && !isFinished && (
                <Timer deadline={matchState.deadline} />
              )}

              <Board
                board={matchState.board}
                onMove={makeMove}
                disabled={isFinished || !isMyTurn}
              />

              {isFinished && (
                <div className="result">
                  <div>{resultText}</div>
                  <button onClick={leaveMatch}>Back to Menu</button>
                </div>
              )}
            </>
          ) : (
            <div>⏳ {statusText}</div>
          )}
        </div>
      )}

      <Leaderboard client={client} session={session} />
    </div>
  );
}

export default App;