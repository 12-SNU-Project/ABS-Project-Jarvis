import sqlite3
import os

DB_PATH = os.path.join(os.path.dirname(__file__), '../data/feature_runs.db')

def get_db_connection():
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
            used_llm INTEGER,
            latency_ms INTEGER,
            prompt_tokens INTEGER,
            completion_tokens INTEGER,
            total_tokens INTEGER,
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
        )
    ''')
    conn.commit()
    conn.close()
