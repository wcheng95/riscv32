#!/usr/bin/env python3
"""Generate the line-preserving PicoRV32 RV32I study projection."""

from __future__ import annotations

import hashlib
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SRC = ROOT / "picorv32" / "picorv32.v"
DST = ROOT / "docs" / "rtl" / "picorv32-rv32i-study.v"

# Git blob SHA of picorv32/picorv32.v in this repository.
EXPECTED_GIT_BLOB = "cc45fa998f1857b06a856ea59b931f6c37e06b34"

FIXED = {
    "parameter [ 0:0] ENABLE_COUNTERS = 1,":
        "parameter [ 0:0] ENABLE_COUNTERS = 0,",
    "parameter [ 0:0] ENABLE_COUNTERS64 = 1,":
        "parameter [ 0:0] ENABLE_COUNTERS64 = 0,",
    "parameter [ 0:0] ENABLE_IRQ_QREGS = 1,":
        "parameter [ 0:0] ENABLE_IRQ_QREGS = 0,",
    "parameter [ 0:0] ENABLE_IRQ_TIMER = 1,":
        "parameter [ 0:0] ENABLE_IRQ_TIMER = 0,",
}

ALLOWED_EDIT_LINES = {23, 63, 64, 80, 81}


def git_blob_sha(data: bytes) -> str:
    header = f"blob {len(data)}\0".encode()
    return hashlib.sha1(header + data).hexdigest()


def blank_begin_end_block(lines: list[str], needle: str) -> tuple[int, int]:
    start = next(i for i, line in enumerate(lines) if needle in line)
    depth = 0
    seen = False
    for i in range(start, len(lines)):
        code = lines[i].split("//", 1)[0]
        begins = sum(tok == "begin" for tok in code.replace("(", " ").replace(")", " ").split())
        ends = sum(tok == "end" for tok in code.replace(";", " ").split())
        if begins:
            seen = True
        depth += begins - ends
        if seen and depth == 0:
            for j in range(start, i + 1):
                lines[j] = ""
            return start + 1, i + 1
    raise RuntimeError(f"unterminated block: {needle}")


def main() -> None:
    data = SRC.read_bytes()
    actual = git_blob_sha(data)
    if actual != EXPECTED_GIT_BLOB:
        raise SystemExit(
            f"Refusing to regenerate: source blob is {actual}, "
            f"expected {EXPECTED_GIT_BLOB}"
        )

    original = data.decode().split("\n")
    out = original.copy()

    # Fixed parameter defaults: intentional retained-line edits.
    for i, line in enumerate(out):
        stripped = line.strip()
        if stripped in FIXED:
            indent = line[: len(line) - len(line.lstrip())]
            out[i] = indent + FIXED[stripped]

    # Apply preprocessor conditionals with no optional study defines enabled.
    macros: set[str] = set()
    stack: list[dict[str, bool]] = []
    active = True

    def recompute() -> bool:
        return all(frame["active"] for frame in stack)

    for i, raw in enumerate(out):
        text = raw.strip()

        if text.startswith("`ifdef "):
            name = text.split()[1]
            cond = name in macros
            stack.append({"parent": active, "active": active and cond, "taken": cond})
            out[i] = ""
            active = recompute()
            continue

        if text.startswith("`ifndef "):
            name = text.split()[1]
            cond = name not in macros
            stack.append({"parent": active, "active": active and cond, "taken": cond})
            out[i] = ""
            active = recompute()
            continue

        if text.startswith("`elsif "):
            name = text.split()[1]
            top = stack[-1]
            cond = (not top["taken"]) and (name in macros)
            top["active"] = top["parent"] and cond
            top["taken"] = top["taken"] or cond
            out[i] = ""
            active = recompute()
            continue

        if text.startswith("`else"):
            top = stack[-1]
            cond = not top["taken"]
            top["active"] = top["parent"] and cond
            top["taken"] = True
            out[i] = ""
            active = recompute()
            continue

        if text.startswith("`endif"):
            out[i] = ""
            stack.pop()
            active = recompute()
            continue

        if not active:
            out[i] = ""
            continue

        if text.startswith("`define "):
            macros.add(text.split()[1].split("(")[0])
        elif text.startswith("`undef "):
            macros.discard(text.split()[1])

    # C-only self-contained blocks. Do not simplify mixed live expressions.
    blank_begin_end_block(
        out,
        "if (COMPRESSED_ISA && mem_done && (mem_do_prefetch || mem_do_rinst)) begin",
    )
    blank_begin_end_block(
        out,
        "if (COMPRESSED_ISA && mem_rdata_latched[1:0] != 2'b11) begin",
    )

    # Keep only the primary picorv32 module, but preserve original line count.
    module_start = next(
        i for i, line in enumerate(out) if line.lstrip().startswith("module picorv32 #(")
    )
    module_end = next(
        i for i in range(module_start + 1, len(out)) if out[i].strip() == "endmodule"
    )
    for i in range(module_end + 1, len(out)):
        out[i] = ""

    # Use an existing blank source line for a marker; line numbers do not shift.
    assert out[22].strip() == ""
    out[22] = "// STUDY PROJECTION: fixed RV32I configuration; see docs/rtl/README.md"

    # Audit retained lines.
    bad = []
    for i, line in enumerate(out, 1):
        if line and line != original[i - 1] and i not in ALLOWED_EDIT_LINES:
            bad.append(i)
    if bad:
        raise SystemExit(f"Unexpected modified retained lines: {bad[:20]}")

    DST.parent.mkdir(parents=True, exist_ok=True)
    DST.write_text("\n".join(out))

    kept = sum(bool(line) for line in out)
    print(f"wrote {DST}")
    print(f"lines: {len(out)} (same as source)")
    print(f"nonblank retained: {kept}")
    print("audit: PASS")


if __name__ == "__main__":
    main()
