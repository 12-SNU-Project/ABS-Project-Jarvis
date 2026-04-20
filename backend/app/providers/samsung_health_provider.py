from __future__ import annotations

import json
from urllib.request import Request, urlopen


def fetch_samsung_health_data(api_url: str, api_key: str | None = None) -> dict:
    # The Samsung Health Data API is Android SDK based, so this provider expects
    # a companion bridge endpoint that exposes raw sleep payloads to the backend.
    headers = {"Content-Type": "application/json"}
    if api_key:
        headers["Authorization"] = f"Bearer {api_key}"

    request = Request(url=api_url, headers=headers, method="GET")
    with urlopen(request, timeout=15) as response:
        return json.loads(response.read().decode("utf-8"))
