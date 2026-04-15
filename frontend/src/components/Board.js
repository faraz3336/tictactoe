import React from "react";

const Board = ({ board, onMove, disabled }) => {
  return (
    <div className="board">
      {board.map((value, idx) => (
        <div
          key={idx}
          className={`cell${disabled ? " disabled" : ""}${value ? " filled" : ""}`}
          onClick={() => !disabled && !value && onMove(idx)}
        >
          {value && (
            <span className={value === "X" ? "mark-x" : "mark-o"}>
              {value}
            </span>
          )}
        </div>
      ))}
    </div>
  );
};

export default Board;