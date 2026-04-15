import React, { useEffect, useState } from "react";

const Leaderboard = ({ client, session }) => {
  const [leaders, setLeaders] = useState([]);

  useEffect(() => {
    if (!session) return;

    // FIX: renamed inner function from `fetch` to `fetchLeaders` to avoid
    // shadowing the global `fetch` built-in, which could break network calls.
    const fetchLeaders = async () => {
      try {
        const result = await client.rpc(session, "get_leaderboard", "{}");

        const data =
          typeof result.payload === "string"
            ? JSON.parse(result.payload)
            : result.payload;

        const rawRecords = data?.records;
        const normalizedRecords = Array.isArray(rawRecords)
          ? rawRecords
          : Array.isArray(rawRecords?.records)
            ? rawRecords.records
            : rawRecords && typeof rawRecords === "object"
              ? Object.values(rawRecords)
              : [];

        setLeaders(normalizedRecords);
      } catch (err) {
        console.error("Leaderboard fetch error:", err);
        setLeaders([]);
      }
    };

    fetchLeaders();
    const interval = setInterval(fetchLeaders, 15000);
    return () => clearInterval(interval);
  }, [client, session]);

  return (
    <div className="leaderboard">
      <h3>🏅 Leaderboard</h3>
      {leaders.length === 0 ? (
        <p>No records yet.</p>
      ) : (
        <table>
          <thead>
            <tr>
              <th>#</th>
              <th>Player</th>
              <th>Wins</th>
              <th>Losses</th>
              <th>Streak</th>
              <th>Best</th>
            </tr>
          </thead>
          <tbody>
            {leaders.map((l, i) => (
              <tr key={l.ownerId || i}>
                <td>{i + 1}</td>
                <td>{l.username || l.ownerId}</td>
                <td>{l.wins ?? l.score ?? 0}</td>
                <td>{l.losses ?? 0}</td>
                <td>{l.currentStreak ?? 0}</td>
                <td>{l.bestStreak ?? 0}</td>
              </tr>
            ))}
          </tbody>
        </table>
      )}
    </div>
  );
};

export default Leaderboard;