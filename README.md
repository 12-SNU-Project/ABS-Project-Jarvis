# Jarvis Multi-Agent MVP

Professional, typed, and decoupled multi-agent system.

## Architecture

### Backend (`backend/`)
- **FastAPI**: Modern, high-performance web framework.
- **Pydantic Schemas**: Strict data contracts between agents and the UI.
- **Service Layer**: Business logic isolated in `app/services/`. File-or-folder-per-service.
- **Provider Pattern**: Data fetching (mocks or real APIs) decoupled in `app/providers/`.

### Frontend (`frontend/`)
- **React + Vite**: Fast development and building.
- **Feature-Based**: Logic organized by domain features (`briefing`, `admin`).
- **TanStack Query**: Efficient data fetching and caching.

## Directory Structure

```text
.
├── backend/
│   ├── app/
│   │   ├── api/            # Routes and Routers
│   │   ├── schemas/        # Pydantic Models (The Contracts)
│   │   ├── services/       # Agent Logic (Team ownership here)
│   │   ├── providers/      # Data/API Clients
│   │   └── core/           # Config & Settings
│   ├── main.py             # Entry point
│   └── pyproject.toml
├── frontend/
│   ├── src/
│   │   ├── features/       # Feature-based components and APIs
│   │   ├── components/     # Shared UI Primitives
│   │   └── types/          # TypeScript definitions
│   └── package.json
└── docs/                   # Specifications and Workflows
```

## Work Allocation

- **배민규**: `backend/app/services/orchestrator.py`
- **조수빈**: `backend/app/services/weather.py`
- **김재희**: `backend/app/services/calendar.py`
- **문이현**: `backend/app/services/slack_summary.py`
- **나정연**: `backend/app/services/admin.py`
- **오승담**: `frontend/`

## Quick Start

### Backend
```bash
cd backend
python3 -m venv .venv
source .venv/bin/activate
pip install -e .
uvicorn main:app --reload
```

### Frontend
```bash
cd frontend
npm install
npm run dev
```

