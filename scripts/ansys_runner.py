"""Ansys MAPDL cross-verification runner (batch mode).

Wraps each Phase 5 .mac deck with an APDL extraction block that writes
peak metrics through ``/COM,*** RESULT,<key>,<value>`` lines into the .out
file and contour PNGs through ``/SHOW,PNG``. Runs MAPDL in batch via
subprocess. No PyMAPDL gRPC session is started, which avoids the
launcher/exit hangs we hit on this CAEN VDI + MAPDL 2025 R2 combo.

Usage:
    python scripts/ansys_runner.py --beam
    python scripts/ansys_runner.py --joint
    python scripts/ansys_runner.py --strut
    python scripts/ansys_runner.py --all
"""

from __future__ import annotations

import argparse
import math
import os
import pathlib
import re
import shutil
import subprocess
import sys
import time

import pandas as pd

REPO = pathlib.Path(__file__).resolve().parents[1]
EXPORT_DIR = REPO / "data" / "export"
RUN_ROOT = REPO / "data" / "ansys_run"
FIG_DIR = REPO / "docs" / "figures"
DATA_DIR = REPO / "data"
RESULTS_SUMMARY_CSV = DATA_DIR / "results_summary.csv"

ANSYS_EXE = pathlib.Path(
    os.environ.get(
        "ANSYS252_EXE",
        r"C:\Program Files\ANSYS Inc\v252\ansys\bin\winx64\ANSYS252.exe",
    )
)

VM_TOL = 0.10
DISP_TOL = 0.05

# Section: hollow circular tube from frame_LC2.mac (SECDATA RI,RO in metres).
BEAM_RI = 0.140
BEAM_RO = 0.150
BEAM_A = math.pi * (BEAM_RO**2 - BEAM_RI**2)
BEAM_IZ = math.pi / 4.0 * (BEAM_RO**4 - BEAM_RI**4)
BEAM_C = BEAM_RO

RESULT_LINE = re.compile(r"\*\*\*\s*RESULT,(\S+?),\s*([\-+0-9.eEdD]+)")


# ----------------------------------------------------------------------
# APDL extraction blocks
# ----------------------------------------------------------------------

# BEAM188 has no PLNSOL/NSORT path to nodal von Mises, so we extract the
# section forces via ETABLE,SMISC and compute combined axial + bending
# stress at the section perimeter in APDL. Result is broadcast as
# /COM,*** RESULT,<key>,<value> lines we grep from the .out file.
BEAM_EXTRACT_APDL = f"""
/POST1
SET,LAST
ALLSEL
ESEL,S,ENAME,,188
*SET,SECA,{BEAM_A:.6e}
*SET,SECIZ,{BEAM_IZ:.6e}
*SET,SECC,{BEAM_C:.6e}
ETABLE,FXI,SMISC,1
ETABLE,MYI,SMISC,2
ETABLE,MZI,SMISC,3
ETABLE,FXJ,SMISC,14
ETABLE,MYJ,SMISC,15
ETABLE,MZJ,SMISC,16
*SET,MAXVM,0.0
*SET,EID,0
EID = ELNEXT(EID)
*DOWHILE,EID
*GET,FX,ELEM,EID,ETAB,FXI
*GET,MY,ELEM,EID,ETAB,MYI
*GET,MZ,ELEM,EID,ETAB,MZI
SI = ABS(FX)/SECA + SQRT(MY**2 + MZ**2)*SECC/SECIZ
*IF,SI,GT,MAXVM,THEN
*SET,MAXVM,SI
*ENDIF
*GET,FX,ELEM,EID,ETAB,FXJ
*GET,MY,ELEM,EID,ETAB,MYJ
*GET,MZ,ELEM,EID,ETAB,MZJ
SJ = ABS(FX)/SECA + SQRT(MY**2 + MZ**2)*SECC/SECIZ
*IF,SJ,GT,MAXVM,THEN
*SET,MAXVM,SJ
*ENDIF
EID = ELNEXT(EID)
*ENDDO
ALLSEL
NSORT,U,SUM,0,1
*GET,UMAX,SORT,0,MAX
*GET,NUMN,NODE,0,COUNT
ESEL,S,ENAME,,188
*GET,NUME,ELEM,0,COUNT
ALLSEL
/COM,*** RESULT,peak_vm_pa,%MAXVM%
/COM,*** RESULT,peak_disp_m,%UMAX%
/COM,*** RESULT,n_nodes,%NUMN%
/COM,*** RESULT,n_beam_elem,%NUME%
/ESHAPE,1
/VIEW,1,1,1,1
/AUTO,1
/SHOW,PNG
ETABLE,SVM,NMISC,1
PLETAB,SVM
/SHOW,CLOSE
/SHOW,PNG
PLNSOL,U,SUM
/SHOW,CLOSE
FINISH
"""

SHELL_EXTRACT_APDL = """
/POST1
SET,LAST
ALLSEL
! Restrict to SHELL281 nodes so MASS21 phantom masters don't dilute NSORT.
ESEL,S,ENAME,,281
NSLE,S
SHELL,TOP
NSORT,S,EQV,0,1
*GET,VTOP,SORT,0,MAX
SHELL,BOT
NSORT,S,EQV,0,1
*GET,VBOT,SORT,0,MAX
*GET,NUMN,NODE,0,COUNT
*GET,NUME,ELEM,0,COUNT
ALLSEL
/COM,*** RESULT,peak_vm_top_pa,%VTOP%
/COM,*** RESULT,peak_vm_bot_pa,%VBOT%
/COM,*** RESULT,n_nodes,%NUMN%
/COM,*** RESULT,n_shell_elem,%NUME%
ESEL,S,ENAME,,281
SHELL,TOP
/VIEW,1,1,1,1
/AUTO,1
/SHOW,PNG
PLNSOL,S,EQV
/SHOW,CLOSE
/SHOW,PNG
EPLOT
/SHOW,CLOSE
ALLSEL
FINISH
"""


# ----------------------------------------------------------------------
# Batch runner
# ----------------------------------------------------------------------

def _clean_run_dir(run_dir: pathlib.Path):
    """Drop the stale file.lock and old MAPDL outputs so override is safe."""
    run_dir.mkdir(parents=True, exist_ok=True)
    for stale in run_dir.glob("file*"):
        try:
            stale.unlink()
        except OSError:
            pass
    lock = run_dir / "file.lock"
    if lock.exists():
        try:
            lock.unlink()
        except OSError:
            pass


def _run_mapdl_batch(
    deck: pathlib.Path,
    run_dir: pathlib.Path,
    extraction: str,
    label: str,
    timeout_s: int = 600,
):
    """Run MAPDL in batch on a wrapper that /INPUTs the deck then runs extraction.

    Returns (proc, out_log_path, wall_seconds).
    """
    _clean_run_dir(run_dir)
    # Copy the deck into run_dir so the wrapper can /INPUT it with a short name.
    deck_local = run_dir / "deck.mac"
    shutil.copy(deck, deck_local)

    wrapper = run_dir / "_wrapper.mac"
    wrapper.write_text(
        "/INPUT,deck,mac\n" + extraction.lstrip("\n"),
        encoding="ascii",
        newline="\n",
    )

    out_log = run_dir / f"{label}.out"
    cmd = [
        str(ANSYS_EXE),
        "-b",
        "-i",
        str(wrapper),
        "-o",
        str(out_log),
        "-np",
        "2",
    ]
    t0 = time.time()
    proc = subprocess.run(
        cmd,
        cwd=str(run_dir),
        timeout=timeout_s,
        capture_output=True,
        text=True,
    )
    wall = time.time() - t0
    return proc, out_log, wall


def _parse_results(out_log: pathlib.Path) -> dict:
    text = out_log.read_text(errors="replace")
    out: dict = {}
    for line in text.splitlines():
        m = RESULT_LINE.search(line)
        if m:
            out[m.group(1)] = float(m.group(2).replace("D", "E").replace("d", "e"))
    return out


def _matlab_ref() -> dict:
    df = pd.read_csv(RESULTS_SUMMARY_CSV)
    lc2 = df[(df.component == "frame") & (df.load_case == "LC2_2g_maneuver")].iloc[0]
    lcg = df[(df.component == "landing_gear") & (df.load_case == "LCG_3g_landing")].iloc[0]
    return {
        "frame_LC2": {
            "vm_MPa": float(lc2.max_vm_MPa),
            "disp_mm": float(lc2.max_disp_mm),
            "RF": float(lc2.min_RF),
            "allow_MPa": float(lc2.allowable_MPa),
        },
        "landing_gear_LCG": {
            "vm_MPa": float(lcg.max_vm_MPa),
            "disp_mm": float(lcg.max_disp_mm),
            "RF": float(lcg.min_RF),
            "allow_MPa": float(lcg.allowable_MPa),
        },
    }


def _collect_pngs(run_dir: pathlib.Path) -> list[pathlib.Path]:
    """Return PNGs in run_dir sorted by mtime (oldest first)."""
    return sorted(run_dir.glob("*.png"), key=lambda p: p.stat().st_mtime)


def _copy_fig(src: pathlib.Path | None, dest: pathlib.Path):
    if src is not None and src.exists() and src.stat().st_size > 100:
        FIG_DIR.mkdir(parents=True, exist_ok=True)
        shutil.copy(src, dest)


# ----------------------------------------------------------------------
# Per-analysis runs
# ----------------------------------------------------------------------

def run_beam() -> dict:
    label = "beam"
    run_dir = RUN_ROOT / label
    deck = EXPORT_DIR / "frame_LC2.mac"
    print(f"[{label}] running MAPDL batch in {run_dir}", flush=True)
    proc, out_log, wall = _run_mapdl_batch(deck, run_dir, BEAM_EXTRACT_APDL, label)
    print(f"[{label}] returncode={proc.returncode}, wall={wall:.1f}s", flush=True)

    res = _parse_results(out_log)
    missing = [k for k in ("peak_vm_pa", "peak_disp_m", "n_nodes", "n_beam_elem") if k not in res]
    if missing:
        print(f"[{label}] !! missing results from .out: {missing}", flush=True)

    pngs = _collect_pngs(run_dir)
    # APDL emitted, in order: PLETAB,SVM (VM) then PLNSOL,U,SUM (disp).
    vm_png = pngs[-2] if len(pngs) >= 2 else (pngs[-1] if pngs else None)
    disp_png = pngs[-1] if pngs else None
    _copy_fig(vm_png, FIG_DIR / "ansys_beam_LC2_vm.png")
    _copy_fig(disp_png, FIG_DIR / "ansys_beam_LC2_disp.png")

    ref = _matlab_ref()["frame_LC2"]
    peak_vm_MPa = res.get("peak_vm_pa", float("nan")) / 1e6
    peak_u_mm = res.get("peak_disp_m", float("nan")) * 1e3
    vm_diff = (peak_vm_MPa - ref["vm_MPa"]) / ref["vm_MPa"]
    u_diff = (peak_u_mm - ref["disp_mm"]) / ref["disp_mm"]
    within_vm = abs(vm_diff) <= VM_TOL
    within_u = abs(u_diff) <= DISP_TOL

    pd.DataFrame([
        {"metric": "peak_VM_MPa", "matlab": ref["vm_MPa"], "ansys": peak_vm_MPa,
         "percent_diff": vm_diff * 100, "within_tolerance": within_vm},
        {"metric": "peak_disp_mm", "matlab": ref["disp_mm"], "ansys": peak_u_mm,
         "percent_diff": u_diff * 100, "within_tolerance": within_u},
    ]).to_csv(DATA_DIR / "ansys_verification_beam.csv", index=False)

    print(
        f"[{label}] peak VM   = {peak_vm_MPa:.2f} MPa "
        f"(MATLAB {ref['vm_MPa']:.2f}, diff {vm_diff*100:+.2f}%) "
        f"{'OK' if within_vm else 'FLAG'}",
        flush=True,
    )
    print(
        f"[{label}] peak disp = {peak_u_mm:.2f} mm "
        f"(MATLAB {ref['disp_mm']:.2f}, diff {u_diff*100:+.2f}%) "
        f"{'OK' if within_u else 'FLAG'}",
        flush=True,
    )

    return {
        "analysis": "frame_LC2_beam",
        "n_nodes": int(res.get("n_nodes", 0)),
        "peak_vm_mpa_matlab": ref["vm_MPa"],
        "peak_vm_mpa_ansys": peak_vm_MPa,
        "peak_disp_mm_matlab": ref["disp_mm"],
        "peak_disp_mm_ansys": peak_u_mm,
        "vm_percent_diff": vm_diff * 100,
        "disp_percent_diff": u_diff * 100,
        "Kt": float("nan"),
        "RF_corrected": ref["RF"],
        "wall_s": wall,
    }


def _run_shell_submodel(
    label: str,
    deck_name: str,
    run_subdir: str,
    matlab_key: str,
    vm_fig: str,
    mesh_fig: str,
    per_run_csv: str,
    analysis_tag: str,
) -> dict:
    run_dir = RUN_ROOT / run_subdir
    deck = EXPORT_DIR / deck_name
    print(f"[{label}] running MAPDL batch in {run_dir}", flush=True)
    proc, out_log, wall = _run_mapdl_batch(deck, run_dir, SHELL_EXTRACT_APDL, label)
    print(f"[{label}] returncode={proc.returncode}, wall={wall:.1f}s", flush=True)

    res = _parse_results(out_log)
    missing = [k for k in ("peak_vm_top_pa", "peak_vm_bot_pa", "n_nodes") if k not in res]
    if missing:
        print(f"[{label}] !! missing results from .out: {missing}", flush=True)

    pngs = _collect_pngs(run_dir)
    # APDL emitted, in order: PLNSOL,S,EQV (VM contour) then EPLOT (mesh).
    vm_png = pngs[-2] if len(pngs) >= 2 else (pngs[-1] if pngs else None)
    mesh_png = pngs[-1] if pngs else None
    _copy_fig(vm_png, FIG_DIR / vm_fig)
    _copy_fig(mesh_png, FIG_DIR / mesh_fig)

    peak_top_MPa = res.get("peak_vm_top_pa", float("nan")) / 1e6
    peak_bot_MPa = res.get("peak_vm_bot_pa", float("nan")) / 1e6
    peak_MPa = max(peak_top_MPa, peak_bot_MPa)

    ref = _matlab_ref()[matlab_key]
    Kt = peak_MPa / ref["vm_MPa"] if ref["vm_MPa"] > 0 else float("nan")
    RF_corrected = ref["RF"] / Kt if Kt and Kt > 0 else float("nan")

    pd.DataFrame([
        {"metric": "peak_VM_top_MPa", "value": peak_top_MPa},
        {"metric": "peak_VM_bot_MPa", "value": peak_bot_MPa},
        {"metric": "peak_VM_MPa", "value": peak_MPa},
        {"metric": "beam_nominal_VM_MPa", "value": ref["vm_MPa"]},
        {"metric": "allowable_MPa", "value": ref["allow_MPa"]},
        {"metric": "Kt", "value": Kt},
        {"metric": "beam_RF", "value": ref["RF"]},
        {"metric": "RF_corrected", "value": RF_corrected},
        {"metric": "n_nodes", "value": int(res.get("n_nodes", 0))},
        {"metric": "n_shell_elem", "value": int(res.get("n_shell_elem", 0))},
        {"metric": "wall_s", "value": wall},
    ]).to_csv(DATA_DIR / per_run_csv, index=False)

    print(
        f"[{label}] n_nodes = {int(res.get('n_nodes', 0))}, "
        f"n_shell_elem = {int(res.get('n_shell_elem', 0))}",
        flush=True,
    )
    print(
        f"[{label}] peak VM top = {peak_top_MPa:.2f} MPa, "
        f"bot = {peak_bot_MPa:.2f} MPa, nominal beam = {ref['vm_MPa']:.2f} MPa",
        flush=True,
    )
    print(
        f"[{label}] Kt = {Kt:.2f}, RF_corrected = {ref['RF']:.2f} / {Kt:.2f} "
        f"= {RF_corrected:.2f}",
        flush=True,
    )
    if Kt > 2.5:
        print(f"[{label}] !! Kt > 2.5, local feature dominates reserve factor", flush=True)
    if RF_corrected < 1.5:
        print(f"[{label}] !! RF_corrected < 1.5, recommend doubler or thicker wall", flush=True)

    return {
        "analysis": analysis_tag,
        "n_nodes": int(res.get("n_nodes", 0)),
        "peak_vm_mpa_matlab": ref["vm_MPa"],
        "peak_vm_mpa_ansys": peak_MPa,
        "peak_disp_mm_matlab": float("nan"),
        "peak_disp_mm_ansys": float("nan"),
        "vm_percent_diff": (peak_MPa - ref["vm_MPa"]) / ref["vm_MPa"] * 100,
        "disp_percent_diff": float("nan"),
        "Kt": Kt,
        "RF_corrected": RF_corrected,
        "wall_s": wall,
    }


def run_joint_shell() -> dict:
    return _run_shell_submodel(
        label="joint",
        deck_name="joint_shell.mac",
        run_subdir="joint_shell",
        matlab_key="frame_LC2",
        vm_fig="ansys_joint_shell_vm.png",
        mesh_fig="ansys_joint_shell_mesh.png",
        per_run_csv="ansys_joint_shell.csv",
        analysis_tag="joint_shell_LC2",
    )


def run_strut_top_shell() -> dict:
    return _run_shell_submodel(
        label="strut",
        deck_name="strut_top_shell.mac",
        run_subdir="strut_top_shell",
        matlab_key="landing_gear_LCG",
        vm_fig="ansys_strut_top_vm.png",
        mesh_fig="ansys_strut_top_mesh.png",
        per_run_csv="ansys_strut_top.csv",
        analysis_tag="strut_top_shell_LCG",
    )


def consolidate(results: list) -> pathlib.Path:
    df = pd.DataFrame(results)[[
        "analysis", "n_nodes",
        "peak_vm_mpa_matlab", "peak_vm_mpa_ansys", "vm_percent_diff",
        "peak_disp_mm_matlab", "peak_disp_mm_ansys", "disp_percent_diff",
        "Kt", "RF_corrected", "wall_s",
    ]]
    csv_path = DATA_DIR / "ansys_verification.csv"
    df.to_csv(csv_path, index=False)
    return csv_path


def main(argv=None):
    p = argparse.ArgumentParser(description="Ansys MAPDL cross-verification runner (batch)")
    p.add_argument("--beam", action="store_true", help="run frame_LC2.mac")
    p.add_argument("--joint", action="store_true", help="run joint_shell.mac")
    p.add_argument("--strut", action="store_true", help="run strut_top_shell.mac")
    p.add_argument("--all", action="store_true", help="run all three")
    a = p.parse_args(argv)
    if not any([a.beam, a.joint, a.strut, a.all]):
        p.error("specify --beam, --joint, --strut, or --all")
    if not ANSYS_EXE.exists():
        p.error(f"ANSYS executable not found at {ANSYS_EXE}")

    results = []
    t0 = time.time()
    if a.all or a.beam:
        results.append(run_beam())
    if a.all or a.joint:
        results.append(run_joint_shell())
    if a.all or a.strut:
        results.append(run_strut_top_shell())

    if len(results) >= 2:
        csv_path = consolidate(results)
        print(f"[consolidate] wrote {csv_path}", flush=True)

    print(f"[total] wall = {time.time() - t0:.1f}s", flush=True)


if __name__ == "__main__":
    sys.exit(main() or 0)
