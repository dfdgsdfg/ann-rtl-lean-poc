from __future__ import annotations

import sys
from pathlib import Path

if __package__ in (None, ""):
    ROOT = Path(__file__).resolve().parents[2]
    if str(ROOT) not in sys.path:
        sys.path.insert(0, str(ROOT))

from smt.contract.equivalence.check_equivalence import main as equivalence_main


def main(argv: list[str] | None = None) -> int:
    return equivalence_main(argv)


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
