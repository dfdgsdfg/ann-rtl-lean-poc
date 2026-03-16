from __future__ import annotations

import argparse
import sys
from pathlib import Path

if __package__ in (None, ""):
    ROOT = Path(__file__).resolve().parents[2]
    if str(ROOT) not in sys.path:
        sys.path.insert(0, str(ROOT))

from smt.runners.contract_assumptions import main as assumptions_main
from smt.runners.contract_equivalence import main as equivalence_main
from smt.runners.contract_overflow import main as overflow_main
from smt.runners.rtl import main as rtl_main


def parse_args(argv: list[str] | None = None) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Run the repository SMT suite.")
    parser.add_argument("--yosys", default=None)
    parser.add_argument("--smtbmc", default=None)
    parser.add_argument("--solver", default=None)
    parser.add_argument("--build-root", type=Path, default=None)
    parser.add_argument("--report-root", type=Path, default=None)
    parser.add_argument("--run-id", default=None)
    return parser.parse_args(argv)


def _common_args(args: argparse.Namespace) -> list[str]:
    argv: list[str] = []
    if args.yosys is not None:
        argv.extend(["--yosys", args.yosys])
    if args.smtbmc is not None:
        argv.extend(["--smtbmc", args.smtbmc])
    if args.solver is not None:
        argv.extend(["--solver", args.solver])
    if args.build_root is not None:
        argv.extend(["--build-root", str(args.build_root)])
    if args.report_root is not None:
        argv.extend(["--report-root", str(args.report_root)])
    if args.run_id is not None:
        argv.extend(["--run-id", args.run_id])
    return argv


def _drop_option(argv: list[str], option: str) -> list[str]:
    result: list[str] = []
    skip_next = False
    for token in argv:
        if skip_next:
            skip_next = False
            continue
        if token == option:
            skip_next = True
            continue
        result.append(token)
    return result


def main(argv: list[str] | None = None) -> int:
    args = parse_args(argv)
    shared_args = _common_args(args)
    assumptions_args = _drop_option(_drop_option(_drop_option(shared_args, "--yosys"), "--smtbmc"), "--solver")
    rtl_args = list(shared_args)
    overflow_args = _drop_option(_drop_option(_drop_option(shared_args, "--yosys"), "--smtbmc"), "--solver")
    if args.solver is not None:
        overflow_args.extend(["--z3", args.solver])
    exit_codes = [
        assumptions_main(assumptions_args),
        rtl_main(["--branch", "rtl", *rtl_args]),
        rtl_main(["--branch", "rtl-formalize-synthesis", *rtl_args]),
        overflow_main(overflow_args),
        equivalence_main(overflow_args),
    ]
    return 0 if all(code == 0 for code in exit_codes) else 1


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
