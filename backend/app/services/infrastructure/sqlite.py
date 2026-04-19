from pathlib import Path
import sqlite3


DB_PATH = Path(__file__).resolve().parents[2] / "data" / "feature_runs.db"

def get_db_connection():
    DB_PATH.parent.mkdir(parents=True, exist_ok=True)
    conn = sqlite3.connect(DB_PATH)
    conn.row_factory = sqlite3.Row
    return conn


def init_db():
    conn = get_db_connection()
    cursor = conn.cursor()
    cursor.execute('''
        CREATE TABLE IF NOT EXISTS feature_runs (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            run_id TEXT,
            feature TEXT,
            owner TEXT,
            status TEXT,
            uses_mock INTEGER,
            latency_ms INTEGER,
            prompt_tokens INTEGER,
            completion_tokens INTEGER,
            total_tokens INTEGER,
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
        )
    ''')
    conn.commit()
    conn.close()
