from __future__ import annotations

from app.services.orchestrator import _extract_response_text


def test_extract_response_text_reads_openrouter_message_output() -> None:
    response_data = {
        "id": "resp-123",
        "output": [
            {
                "type": "message",
                "content": [
                    {
                        "type": "output_text",
                        "text": "OpenRouter generated summary.",
                    }
                ],
            }
        ],
    }

    assert _extract_response_text(response_data) == "OpenRouter generated summary."
