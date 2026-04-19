from __future__ import annotations

from app.services.calendar.conflicts import detect_conflicts


def make_event(event_id: str, title: str, start: str, end: str) -> dict[str, str]:
    return {
        "id": event_id,
        "title": title,
        "start": start,
        "end": end,
    }


def test_detect_conflicts_finds_nested_overlap_pair_missed_by_adjacent_scan() -> None:
    conflicts = detect_conflicts(
        [
            make_event("outer", "Deep Work", "2026-04-18T09:00:00+09:00", "2026-04-18T12:00:00+09:00"),
            make_event("inner", "1:1", "2026-04-18T10:00:00+09:00", "2026-04-18T10:30:00+09:00"),
            make_event("tail", "Review", "2026-04-18T11:30:00+09:00", "2026-04-18T12:30:00+09:00"),
        ]
    )

    assert conflicts == [
        {
            "type": "overlap",
            "message": "'Deep Work' overlaps with '1:1'.",
            "severity": "high",
            "event_ids": ["outer", "inner"],
        },
        {
            "type": "overlap",
            "message": "'Deep Work' overlaps with 'Review'.",
            "severity": "high",
            "event_ids": ["outer", "tail"],
        },
    ]


def test_detect_conflicts_finds_chain_overlap_pairs() -> None:
    conflicts = detect_conflicts(
        [
            make_event("a", "Workshop A", "2026-04-18T09:00:00+09:00", "2026-04-18T11:00:00+09:00"),
            make_event("b", "Workshop B", "2026-04-18T10:00:00+09:00", "2026-04-18T12:00:00+09:00"),
            make_event("c", "Workshop C", "2026-04-18T10:30:00+09:00", "2026-04-18T13:00:00+09:00"),
        ]
    )

    assert conflicts == [
        {
            "type": "overlap",
            "message": "'Workshop A' overlaps with 'Workshop B'.",
            "severity": "high",
            "event_ids": ["a", "b"],
        },
        {
            "type": "overlap",
            "message": "'Workshop A' overlaps with 'Workshop C'.",
            "severity": "high",
            "event_ids": ["a", "c"],
        },
        {
            "type": "overlap",
            "message": "'Workshop B' overlaps with 'Workshop C'.",
            "severity": "high",
            "event_ids": ["b", "c"],
        },
    ]


def test_detect_conflicts_reports_tight_buffer_below_threshold() -> None:
    conflicts = detect_conflicts(
        [
            make_event("a", "Standup", "2026-04-18T09:00:00+09:00", "2026-04-18T10:00:00+09:00"),
            make_event("b", "Planning", "2026-04-18T10:29:00+09:00", "2026-04-18T11:00:00+09:00"),
        ]
    )

    assert conflicts == [
        {
            "type": "tight_buffer",
            "message": "Only 29 minutes separate 'Standup' and 'Planning'.",
            "severity": "medium",
            "event_ids": ["a", "b"],
        }
    ]


def test_detect_conflicts_ignores_gap_at_buffer_threshold() -> None:
    conflicts = detect_conflicts(
        [
            make_event("a", "Standup", "2026-04-18T09:00:00+09:00", "2026-04-18T10:00:00+09:00"),
            make_event("b", "Planning", "2026-04-18T10:30:00+09:00", "2026-04-18T11:00:00+09:00"),
        ]
    )

    assert conflicts == []


def test_detect_conflicts_returns_deterministic_ordering() -> None:
    events = [
        make_event("c", "Workshop C", "2026-04-18T10:20:00+09:00", "2026-04-18T11:20:00+09:00"),
        make_event("a", "Workshop A", "2026-04-18T09:00:00+09:00", "2026-04-18T10:30:00+09:00"),
        make_event("d", "Workshop D", "2026-04-18T11:35:00+09:00", "2026-04-18T12:00:00+09:00"),
        make_event("b", "Workshop B", "2026-04-18T10:00:00+09:00", "2026-04-18T11:00:00+09:00"),
    ]

    expected = [
        {
            "type": "overlap",
            "message": "'Workshop A' overlaps with 'Workshop B'.",
            "severity": "high",
            "event_ids": ["a", "b"],
        },
        {
            "type": "overlap",
            "message": "'Workshop A' overlaps with 'Workshop C'.",
            "severity": "high",
            "event_ids": ["a", "c"],
        },
        {
            "type": "overlap",
            "message": "'Workshop B' overlaps with 'Workshop C'.",
            "severity": "high",
            "event_ids": ["b", "c"],
        },
        {
            "type": "tight_buffer",
            "message": "Only 15 minutes separate 'Workshop C' and 'Workshop D'.",
            "severity": "medium",
            "event_ids": ["c", "d"],
        },
    ]

    assert detect_conflicts(events) == expected
    assert detect_conflicts(list(reversed(events))) == expected
