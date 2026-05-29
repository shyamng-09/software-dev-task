# Real-Time Quiz Platform

A Kahoot-style real-time quiz app built with Flutter (frontend) and Node.js + Socket.IO + MongoDB (backend).

## Features

- Host creates a room and gets a 6-digit PIN
- Participants join by PIN and nickname
- Slide types: Info, MCQ (multiple choice with timer + scoring), Q&A
- Live answer bar chart for the host during MCQ slides
- Time-based scoring — faster answers earn more points
- Live leaderboard / podium after each MCQ
- Host can kick participants from the lobby
- Q&A slides: participants submit questions, host can spotlight or dismiss them
- Play Again resets all scores for a fresh game

## Project Structure

```
backend/   — Node.js / Express / Socket.IO / Mongoose
frontend/  — Flutter (Dart)
```

## Setup

### Backend

```bash
cd backend
npm install
# Edit .env — set MONGO_URI and PORT
npm run dev
```

### Frontend

```bash
cd frontend
flutter pub get
# Edit lib/config.dart — set serverUrl to your backend address
flutter run
```

## Configuration

Edit `frontend/lib/config.dart` to point at your backend:

```dart
// Local dev (iOS simulator / web)
static const String serverUrl = 'http://localhost:8000';

// Android emulator
static const String serverUrl = 'http://10.0.2.2:8000';

// Real device / production
static const String serverUrl = 'http://<your-server-ip>:8000';
```

## Socket Events

| Event | Direction | Description |
|---|---|---|
| `host-join` | client → server | Host joins a room |
| `join-room` | client → server | Participant joins |
| `joined-successfully` | server → client | Confirms join, returns room state |
| `start-question` | client → server | Host sends MCQ data |
| `question-started` | server → client | Broadcasts question to participants |
| `submit-answer` | client → server | Participant submits answer |
| `answer-result` | server → client | Correct/wrong + score for that participant |
| `answer-aggregate` | server → client | Live answer counts for host chart |
| `change-state` | client → server | Host changes room state |
| `state-changed` | server → client | Broadcasts new state to all |
| `leaderboard` | server → client | Sorted participant scores |
| `next-slide` | client → server | Host advances slide |
| `slide-advanced` | server → client | Tells host presenter to advance |
| `reset-scores` | client → server | Resets all scores for a new game |
| `kick-user` | client → server | Host kicks a participant |
| `kicked` | server → client | Notifies kicked participant |
| `submit-qa` | client → server | Participant submits a Q&A question |
| `qa-question-received` | server → client | Broadcasts Q&A question to host |
| `spotlight-qa` | client → server | Host spotlights a question |
| `qa-spotlighted` | server → client | Broadcasts spotlighted question ID |
| `dismiss-qa` | client → server | Host dismisses a question |
| `qa-dismissed` | server → client | Broadcasts dismissed question ID |
| `participants-updated` | server → client | Updated participant list |
