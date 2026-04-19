from .sqlite import get_db_connection, init_db
from typing import Optional, List, Dict


def log_feature_run(run_id: str, feature: str, owner: str, status: str, uses_mock: bool, latency_ms: int, prompt_tokens: int, completion_tokens: int, total_tokens: int):
    conn = get_db_connection()
    cursor = conn.cursor()
    cursor.execute(
        '''INSERT INTO feature_runs (run_id, feature, owner, status, uses_mock, latency_ms, prompt_tokens, completion_tokens, total_tokens)
           VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)''',
        (run_id, feature, owner, status, int(uses_mock), latency_ms, prompt_tokens, completion_tokens, total_tokens)
    )
    conn.commit()
    conn.close()


def get_recent_feature_runs(limit: int = 20) -> List[Dict]:
    conn = get_db_connection()
    cursor = conn.cursor()
    cursor.execute('''
        SELECT * FROM feature_runs ORDER BY created_at DESC LIMIT ?
    ''', (limit,))
    rows = cursor.fetchall()
    conn.close()
    return [dict(row) for row in rows]
