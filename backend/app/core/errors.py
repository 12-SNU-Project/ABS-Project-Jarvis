from __future__ import annotations

from dataclasses import dataclass, field
from typing import TypedDict


class AppErrorDetail(TypedDict):
    code: str
    message: str
    field: str | None


def error_detail(
    *, code: str, message: str, field: str | None = None
) -> AppErrorDetail:
    return {"code": code, "message": message, "field": field}


@dataclass(slots=True)
class AppError(Exception):
    code: str
    message: str
    status_code: int
    details: list[AppErrorDetail] = field(default_factory=list)

    def __str__(self) -> str:
        return self.message
