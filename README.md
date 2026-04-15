# Multiplayer Tic-Tac-Toe with Nakama

Production-ready multiplayer Tic-Tac-Toe with server-authoritative game logic powered by Nakama.

## Tech Stack

- Frontend: React (`frontend`)
- Backend runtime: Nakama Lua modules (`backend/data/modules`)
- Infrastructure: Docker Compose (`docker-compose.yml`)
- Database: PostgreSQL

## Features

- Server-authoritative match loop (all move validation on server)
- Real-time board updates over Nakama socket
- Match discovery and room creation through RPC matchmaking
- Timed mode (30-second per-turn deadline with forced turn rotation)
- Classic mode (no turn timer)
- Leaderboard with wins, losses, current streak, and best streak
- Mobile-friendly responsive UI

## Project Structure

- `frontend/src/App.js`: authentication, matchmaking, socket session, game UI
- `frontend/src/components/Board.js`: board rendering and move input
- `frontend/src/components/Timer.js`: timed mode turn countdown
- `frontend/src/components/Leaderboard.js`: leaderboard polling and display
- `backend/data/modules/main.lua`: runtime registration
- `backend/data/modules/rpc.lua`: matchmaking and leaderboard RPCs
- `backend/data/modules/match.lua`: authoritative match state and game rules

## Local Setup

### 1) Start Nakama + Postgres

```bash
docker compose up -d
```

Nakama endpoints:

- API/Socket: `http://localhost:7350`
- Console: `http://localhost:7351` (admin/password)

### 2) Run Frontend

```bash
cd frontend
npm install
npm start
```

Frontend default URL:

- `http://localhost:3000`

## Frontend Environment Variables

Create `frontend/.env` (or use your deployment provider env UI):

```bash
REACT_APP_NAKAMA_HOST=localhost
REACT_APP_NAKAMA_PORT=7350
REACT_APP_NAKAMA_SERVER_KEY=defaultkey
REACT_APP_NAKAMA_SSL=false
```

For production, set `REACT_APP_NAKAMA_HOST` to your public Nakama domain and `REACT_APP_NAKAMA_SSL=true`.

## Architecture and Design Decisions

- **Server-authoritative gameplay:** client only sends `{ cell }`; server validates turn, cell bounds, and occupancy before applying changes.
- **Match isolation:** each match has independent state (`board`, `turn`, `players`, `marks`, `deadline`, `phase`) in Nakama authoritative match state.
- **Cheat prevention:** no trusted client state transitions; only server-broadcast state is rendered.
- **Mode support:** mode passed from matchmaking RPC into `match_init` params.
- **Leaderboard stats:** server updates `wins`, `losses`, `currentStreak`, and `bestStreak` on match completion.
- **Ranking formula:** global leaderboard rank is sorted by `wins` (descending), then `subscore` (descending) as tie-breaker.

## Concurrent Game Support

- Multiple simultaneous games are supported because each Nakama authoritative match has isolated in-memory state.
- Match discovery filters only open lobbies, and full matches reject additional join attempts.
- Isolation guarantee: moves are routed by `match_id`, so one room cannot affect another room's board state.
- Validation approach:
  - Run 3+ browser pairs (or devices) and start matches concurrently.
  - Confirm each pair gets different `match_id`.
  - Confirm moves in one room never update other rooms.

## Deployment Process

### Backend (Nakama)

Deploy Nakama + Postgres on your preferred cloud provider using containers:

1. Build/push custom image from `backend/Dockerfile` (or mount modules as volume).
2. Provide persistent Postgres.
3. Expose ports `7350` (API/socket) and optionally `7351` (console, secured).
4. Replace insecure defaults (`console.password`, server/session keys).

### Frontend

Deploy `frontend` to Vercel/Netlify:

1. Build command: `npm run build`
2. Output directory: `build`
3. Configure `REACT_APP_*` env vars to point to deployed Nakama.

## API/Server Configuration Details

- Nakama server key: `defaultkey` (local only; change for production)
- RPCs:
  - `find_match`
  - `cancel_matchmaking`
  - `get_leaderboard`
- Match module name used by creation RPC: `match`

## How to Test Multiplayer

1. Start backend with `docker compose up -d`.
2. Run frontend and open in two browsers/devices.
3. Click **Find Match** in both clients.
4. Verify:
   - Both users join same room
   - Turns alternate correctly
   - Illegal moves are ignored
   - Win/draw resolves identically on both clients
   - Timed mode rotates turn on timeout
   - Leaving player ends match with abandoned status
   - Leaderboard updates winner/loser stats after completed games

## Leaderboard Verification

1. Complete one non-draw game.
2. Verify winner shows:
   - `wins + 1`
   - `currentStreak + 1`
   - `bestStreak` updated if needed
3. Verify loser shows:
   - `losses + 1`
   - `currentStreak = 0`
4. Verify rank ordering is by total wins.

## Deliverables Checklist

- Source repository: this project
- Frontend deployment URL: add your final URL here
- Nakama endpoint URL: add your final backend endpoint here

## Submission Checklist

- [ ] Public frontend URL added to this README
- [ ] Public Nakama endpoint added to this README
- [ ] Production secrets rotated (no local default keys/passwords)
- [ ] Multiplayer tested with at least two real clients
- [ ] Timed mode and disconnect behavior validated
- [ ] Leaderboard stats (wins/losses/streaks) validated
