import React, { useState, useEffect } from "react";

const Timer = ({ deadline }) => {
  const calcLeft = () => Math.max(0, deadline - Math.floor(Date.now() / 1000));

  const [timeLeft, setTimeLeft] = useState(calcLeft);

  // FIX: Do NOT include `timeLeft` in deps — it caused the interval to be
  // torn down and recreated every second, causing flicker and drift.
  // Re-run only when `deadline` changes (i.e. a new turn starts).
  useEffect(() => {
    setTimeLeft(calcLeft());          // sync immediately when deadline changes
    const interval = setInterval(() => {
      const left = calcLeft();
      setTimeLeft(left);
      if (left <= 0) clearInterval(interval);
    }, 1000);
    return () => clearInterval(interval);
  }, [deadline]);

  const urgent = timeLeft <= 10;

  return (
    <div className={`timer ${urgent ? "urgent" : ""}`}>
      ⏱️ Time left: <strong>{timeLeft}s</strong>
    </div>
  );
};

export default Timer;