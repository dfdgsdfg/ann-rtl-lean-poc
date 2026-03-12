from __future__ import annotations

try:
    from .params import HIDDEN_SIZE, INPUT_SIZE
except ImportError:
    from params import HIDDEN_SIZE, INPUT_SIZE

TEACHER_VERSION = "relu_teacher_v2"
TEACHER_SOURCE = "fixed_relu_teacher_network"

TEACHER_W1 = (
    (1, -1, 1, -1),
    (0, 0, 0, 0),
    (0, 0, 0, 0),
    (0, 0, 0, 0),
    (0, 0, 0, 0),
    (0, 0, 0, 0),
    (0, 0, 0, 0),
    (0, 0, 0, 0),
)

TEACHER_B1 = (0, 0, 0, 0, 0, 0, 0, 0)
TEACHER_W2 = (2, 0, 0, 0, 0, 0, 0, 0)
TEACHER_B2 = -1


def teacher_payload() -> dict[str, object]:
    return {
        "schema_version": 1,
        "source": TEACHER_SOURCE,
        "version": TEACHER_VERSION,
        "input_size": INPUT_SIZE,
        "hidden_size": HIDDEN_SIZE,
        "w1": [list(row) for row in TEACHER_W1],
        "b1": list(TEACHER_B1),
        "w2": list(TEACHER_W2),
        "b2": TEACHER_B2,
    }
