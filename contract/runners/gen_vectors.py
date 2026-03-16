from __future__ import annotations

import sys
from pathlib import Path

if __package__ in (None, ""):
    ROOT = Path(__file__).resolve().parents[2]
    if str(ROOT) not in sys.path:
        sys.path.insert(0, str(ROOT))

from contract.src.gen_vectors import main as gen_vectors_main


def main(argv: list[str] | None = None) -> int:
    gen_vectors_main(argv)
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
