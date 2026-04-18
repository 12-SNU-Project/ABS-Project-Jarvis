# Jarvis Multi-Agent MVP


<div align="center">

![Project Status](https://img.shields.io/badge/status-in%20progress-yellow)

</div>

## 프로젝트 소개
Professional, typed, and decoupled multi-agent system.

---

## 🛠 기술 스택
### 
### 사용 언어
![Python](https://img.shields.io/badge/Python-3776AB?style=for-the-badge&logo=python&logoColor=white)

### Tools
![Conda](https://img.shields.io/badge/Anaconda-44A833?style=for-the-badge&logo=anaconda&logoColor=white)
![ChromaDB](https://img.shields.io/badge/ChromaDB-004A7C?style=for-the-badge&logo=google-cloud&logoColor=white) 
![Cursor](https://img.shields.io/badge/cursor-000000?style=for-the-badge&logo=cursor&logoColor=white)
![FastAPI](https://img.shields.io/badge/FastAPI-009688?style=for-the-badge&logo=fastapi&logoColor=white)
![LangGraph](https://img.shields.io/badge/LangGraph-1C3C3C?style=for-the-badge&logo=langgraph&logoColor=white)
---
## Architecture

### Backend (`backend/`)
- **FastAPI**: Modern, high-performance web framework.
- **Pydantic Schemas**: Strict data contracts between agents and the UI.
- **Service Layer**: Business logic isolated in `app/services/`. File-or-folder-per-service.
- **Provider Pattern**: Data fetching (mocks or real APIs) decoupled in `app/providers/`.

### Frontend (`frontend/`)
- **Feature-Based**: Logic organized by domain features (`briefing`, `admin`).

---

## Directory Structure
```
📦 root
│
├── 📂backend/
│   ├── 📂 app/
│   │   ├── 📂api/            # Routes and Routers
│   │   ├── 📂schemas/        # Pydantic Models (The Contracts)
│   │   ├── 📂services/       # Agent Logic (Team ownership here)
│   │   ├── 📂providers/      # Data/API Clients
│   │   └── 📂core/           # Config & Settings
│   ├── main.py             # Entry point
│   └── pyproject.toml
├── 📂frontend/
│   ├── 📂src/
│   │   ├── 📂features/       # Feature-based components and APIs
│   │   ├── 📂components/     # Shared UI Primitives
│   │   └── 📂types/          # TypeScript definitions
│   └── package.json
├──  📂docs/        
├── .gitignore
└──  README.md
```
---

## Teammate
| 이름 | 역할 | GitHub |
|--------|------|--------|
| 오승담 | UI | [@seungdam](https://github.com/seungdam) |
| 배민규 | 개발 | [@yachom](https://github.com/yachom) |
| 김재희 | 메인테이너 | [@RekHet](https://github.com/RekHet) |
| 나정연 | 개발 | []() |
| 문이현 | 개발 | [@dlgus0919](https://github.com/dlgus0919) |
| 조수빈 | 개발 | [@soobincho-gif](https://github.com/soobincho-gif) |

### 구체적인 할당 작업은 TEAM_WORKFLOW.md 참조

---
## Quick Start

### frontend

### Backend
```bash
cd backend
python3 -m venv .venv
source .venv/bin/activate
pip install -e .
uvicorn main:app --reload
```

---
### Branch Convention
- `main`: 최종 Release용 브랜치 
- `dev`: 개발 작업물 merge용 브랜치
- `feature/<기능명>`: 기능 작업용 브랜치
- `bugfix/<이슈명>`: merge 후 발생한 버그 픽스용 브랜치


### Commit Convention
- `feat`: 새로운 기능 추가
- `fix`: 버그 수정
- `docs`: 문서 수정
- `style`: 코드 포맷팅, 세미콜론 누락 등
- `refactor`: 코드 리팩토링
- `test`: 테스트 코드
- `chore`: 빌드, 프로젝트 설정 등
---
