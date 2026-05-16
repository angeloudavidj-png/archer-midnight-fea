# ANSYS_PROMPT.md

This prompt is end to end. It installs Ansys Student from `setup.exe` if needed, runs the Ansys verification via PyMAPDL, extracts the results, replaces the placeholders in the report and website, and pushes to GitHub. Phase 5 of `EXTENSIONS_PROMPT.md` should have generated the `.mac` and `.bdf` input decks first; if it has not, the master prompt's Phase A will tell you and stop.

## Preconditions

1. **Platform.** Ansys 2026 R1 Student is Windows only. If you are on macOS, see "If you are on macOS" near the bottom of this file for the three workarounds.

2. **Admin rights.** Installing Ansys requires elevated permissions. The first command in Phase 0 triggers a Windows UAC prompt that you must accept. Claude Code cannot click through UAC for you.

3. **Disk and time.** Roughly 10 GB free for the install, and 30 to 60 minutes wall clock for the install to complete. Phase 0 polls in the background; you can step away.

4. **One manual step.** The very first time Ansys Student launches, it asks you to accept the academic EULA and sign in with your U-M email. That single click-through is required by Ansys's license terms. Phase 0 tells you when to do it. Every subsequent launch is automated.

5. **Phase 5 of EXTENSIONS_PROMPT.md has run.** You should have these files on disk before pasting the master prompt:
   ```
   data/export/frame_LC2.bdf
   data/export/frame_LC2.mac
   data/export/joint_shell.mac
   data/export/strut_top_shell.mac
   docs/AnsysVerification.md
   ```
   If you don't, paste the Phase 5 block from `EXTENSIONS_PROMPT.md` first, then come back here.

## Limits to know

Ansys Student 2026 R1 caps at 128,000 nodes for structural problems and 32 cores. Our beam model has roughly 50 to 200 nodes, the joint shell submodel will be 5,000 to 20,000 nodes, and the strut top shell submodel similar. All well within the cap. If a future model overruns, the prompt will report the node count and stop cleanly.

---

## Master prompt

```
You are operating in the archer-midnight-fea repository. Your goal is to execute
the Ansys verification of Phase 5 end to end using PyMAPDL, then update the
report and the website with real numbers and screenshots, then commit and push.

Style rules for every file you write:
- Clean technical English, AIAA paper tone.
- No em dashes, no double hyphens, use commas instead.
- Never invent numbers. Every Ansys number comes from a PyMAPDL extraction call.
- Never reference a figure that does not exist on disk.


==============================================================================
PHASE 0: Install Ansys Student from setup.exe (skip if already installed)
==============================================================================

1. Detect platform.
     - If Windows, continue.
     - If macOS or Linux, stop and print:
         "Ansys 2026 R1 Student is Windows only. Use one of the workarounds in
          ANSYS_PROMPT.md (CAEN remote desktop, Parallels VM, or a separate
          Windows machine), then re-paste this prompt from there."

2. Check whether Ansys is already installed by looking for ansys261.exe at:
     C:\Program Files\ANSYS Inc\v261\ansys\bin\winx64\ansys261.exe
     C:\Program Files\ANSYS Inc\ANSYS Student\v261\ansys\bin\winx64\ansys261.exe
     Also try the AWP_ROOT261 environment variable.
   If found, print the path and SKIP TO PHASE A.

3. Locate setup.exe. From the screenshots, it lives in the ANSYSACADEMICST...
   directory. Common parent paths:
     C:\Users\<username>\Downloads\ANSYSACADEMICSTUDENT_2026R1_WINX64\
     C:\Users\<username>\Documents\ANSYSACADEMICSTUDENT_2026R1_WINX64\
     C:\ANSYSACADEMICSTUDENT_2026R1_WINX64\
   If not found at those, ask me for the full path to setup.exe and wait for
   my reply.

4. Print these warnings before launching the installer:
     - Windows UAC will prompt; the user must click Yes.
     - The install will take 30 to 60 minutes.
     - At first launch after install, Ansys will prompt for EULA acceptance and
       a U-M email. That one click-through is unavoidable per Ansys terms.

5. Launch the silent install. Try this command first:

     Start-Process -FilePath "<full path to setup.exe>" `
       -ArgumentList "-silent","-install_dir","C:\Program Files\ANSYS Inc\v261","-product_flags","-1" `
       -Verb RunAs -Wait

   Notes:
     - -Verb RunAs triggers UAC elevation.
     - -Wait blocks until the installer process exits.
     - -product_flags "-1" requests the default Student bundle.
   If the silent flag set is rejected by this installer build (Ansys sometimes
   changes them between releases), fall back to:

     Start-Process -FilePath "<full path to setup.exe>" -Verb RunAs

   This launches the GUI installer. Tell me explicitly that I need to click
   through it: accept license, default install path, finish. Then continue to
   step 6 to wait for completion.

6. Poll for installation completion. Loop every 30 seconds, up to 90 minutes:

     while (-not (Test-Path "C:\Program Files\ANSYS Inc\v261\ansys\bin\winx64\ansys261.exe")) {
         Start-Sleep -Seconds 30
         Write-Host "[install] still waiting..."
     }

   If the path appears, print "Install complete." and continue.
   If 90 minutes elapse, abort with the message: "Install did not complete in
   the expected window. Check the installer GUI, then re-paste from Phase 0."

7. Tell me to launch Ansys MAPDL once interactively (Start menu > ANSYS 2026 R1
   > Mechanical APDL Product Launcher, then click Run). On that first launch I
   must accept the academic EULA and sign in with my U-M email. Wait for me to
   reply "done" before continuing.

8. Run the one-line dry test from Phase A's step 3 to confirm the install
   responds to command line invocation. If yes, continue to Phase A.


==============================================================================
PHASE A: Locate Ansys and verify the install
==============================================================================

1. Find the Ansys MAPDL executable. Check these locations in order:
     Windows: C:\Program Files\ANSYS Inc\v261\ansys\bin\winx64\ansys261.exe
              C:\Program Files\ANSYS Inc\ANSYS Student\v261\ansys\bin\winx64\ansys261.exe
     Linux:   /ansys_inc/v261/ansys/bin/ansys261
              /usr/ansys_inc/v261/ansys/bin/ansys261
              ~/ansys_inc/v261/ansys/bin/ansys261
     Also try `which ansys261` and the AWP_ROOT261 environment variable.

2. If not found, stop and print:
     "Ansys 2026 R1 not located. From the ANSYSACADEMICST... directory in VS Code,
      run setup.exe and complete the install before retrying this prompt."

3. If found, run a one-line dry test:
     <ansys_exec> -b -p ANSYS -i nul -o data/export/ansys_install_check.out
   (Linux equivalent uses /dev/null.) Confirm exit code 0 and the .out file
   contains "ANSYS RELEASE 2026 R1".

4. Print the located path and version. Continue.


==============================================================================
PHASE B: PyMAPDL Python environment
==============================================================================

1. Create or activate a project venv at .venv (if Phase 0 of PROMPT.md already
   made one, reuse it).
     python3 -m venv .venv
     source .venv/bin/activate           # macOS/Linux
     .\.venv\Scripts\Activate.ps1        # Windows PowerShell

2. Install PyMAPDL and supporting packages:
     pip install --upgrade pip
     pip install ansys-mapdl-core matplotlib numpy pandas pyvista

3. Verify PyMAPDL can find Ansys without launching it yet:
     python -c "from ansys.mapdl import core as pymapdl; print(pymapdl.find_mapdl())"
   Expect it to print the same executable path found in Phase A. If it returns
   empty, set AWP_ROOT261 to the Ansys install root and retry.

4. Create scripts/ansys_runner.py as the orchestration script for Phases C
   through F. It should accept command-line args: --beam, --joint, --strut, --all.


==============================================================================
PHASE C: Beam cross-verification run
==============================================================================

Goal: run data/export/frame_LC2.mac via PyMAPDL, extract peak von Mises and peak
displacement, compare to the MATLAB result in data/results_summary.csv.

In scripts/ansys_runner.py, implement run_beam():

  from ansys.mapdl.core import launch_mapdl
  import pandas as pd, numpy as np, pathlib

  run_dir = pathlib.Path("data/ansys_run/beam")
  run_dir.mkdir(parents=True, exist_ok=True)
  mapdl = launch_mapdl(run_location=str(run_dir), override=True,
                       loglevel="WARNING")
  mapdl.input("data/export/frame_LC2.mac")
  mapdl.finish(); mapdl.post1(); mapdl.set("LAST")

  # Peak nodal von Mises
  mapdl.nsort("S", "EQV", 0, 1)
  peak_vm_pa  = mapdl.get_value("SORT", 0, "MAX")
  peak_vm_mpa = peak_vm_pa / 1e6
  peak_node   = int(mapdl.get_value("SORT", 0, "MAXLOC"))

  # Peak displacement magnitude
  mapdl.nsort("U", "SUM", 0, 1)
  peak_disp_m  = mapdl.get_value("SORT", 0, "MAX")
  peak_disp_mm = peak_disp_m * 1e3

  # Save a contour plot
  mapdl.show("png")
  mapdl.plnsol("S", "EQV")
  mapdl.show("close")
  # PyMAPDL drops the PNG into the run_dir; copy to docs/figures/
  ...
  mapdl.exit()

Read data/results_summary.csv for the MATLAB LC2 frame numbers. Write
data/ansys_verification_beam.csv with columns:
    metric, matlab, ansys, percent_diff, within_tolerance
where tolerance is 10 percent on peak VM and 5 percent on peak displacement.

Save the von Mises contour to docs/figures/ansys_beam_LC2_vm.png.

If the verification is outside tolerance, print a clear flag. Do not silently
proceed. Investigate likely causes: unit mismatch, boundary condition delta,
element type mismatch (the MATLAB code uses Euler-Bernoulli, MAPDL BEAM188 uses
Timoshenko by default, so a 5 to 8 percent gap from shear deformation is expected
on slender beams; larger gaps are real).


==============================================================================
PHASE D: Joint shell submodel run
==============================================================================

In scripts/ansys_runner.py, implement run_joint_shell():

  run_dir = pathlib.Path("data/ansys_run/joint_shell")
  run_dir.mkdir(parents=True, exist_ok=True)
  mapdl = launch_mapdl(run_location=str(run_dir), override=True)
  mapdl.input("data/export/joint_shell.mac")
  mapdl.finish(); mapdl.post1(); mapdl.set("LAST")

  # Peak shell von Mises at top and bottom surfaces
  mapdl.shell("TOP")
  mapdl.nsort("S", "EQV", 0, 1)
  peak_top_mpa = mapdl.get_value("SORT", 0, "MAX") / 1e6
  mapdl.shell("BOT")
  mapdl.nsort("S", "EQV", 0, 1)
  peak_bot_mpa = mapdl.get_value("SORT", 0, "MAX") / 1e6

  # Stress concentration factor: peak shell VM divided by beam-derived nominal
  # VM at the joint section
  ...

Capture the von Mises contour to docs/figures/ansys_joint_shell_vm.png and an
isometric mesh view to docs/figures/ansys_joint_shell_mesh.png.

Write data/ansys_joint_shell.csv with peak top/bottom VM, stress concentration
factor (Kt), reserve factor at the joint, and the node count.

If Kt is above 2.5, that is a red flag. The beam model under-predicted the joint
stress by that factor, which means the reserve factor at the joint is the
beam-derived RF divided by Kt. Update the report's recommendation section
accordingly.


==============================================================================
PHASE E: Strut top shell submodel run
==============================================================================

Same pattern as Phase D, applied to data/export/strut_top_shell.mac. Captures:
    docs/figures/ansys_strut_top_vm.png
    docs/figures/ansys_strut_top_mesh.png
    data/ansys_strut_top.csv

Note: this submodel uses the post-Phase-0 strut geometry (100 mm OD, 8 mm wall),
so the Kt here is applied to the new defensible RF, not the original failing one.


==============================================================================
PHASE F: Run all and consolidate
==============================================================================

Invoke `python scripts/ansys_runner.py --all` from the master prompt and confirm
all three runs complete cleanly. Print total wall-clock time, total CPU seconds,
and the three Kt values.

Consolidate into data/ansys_verification.csv with one row per analysis:
    analysis, peak_vm_mpa_matlab, peak_vm_mpa_ansys, percent_diff, Kt, RF_corrected


==============================================================================
PHASE G: Update docs/REPORT.md section 11 (Cross-verification)
==============================================================================

Open docs/REPORT.md. Find the "Cross-verification and joint submodels" section
that Phase 5 of EXTENSIONS_PROMPT.md created with placeholder text and screenshots.

Replace the placeholders with the real content:

  1. A comparison table from data/ansys_verification.csv with one row per
     analysis. Bold any row outside the 10 percent tolerance.

  2. The von Mises contour figures from docs/figures/ansys_*.png embedded inline.

  3. A short subsection "Stress concentration findings" stating each Kt and what
     it means for the reserve factor at the local feature versus the beam-derived
     RF. If any local RF (beam RF divided by Kt) falls below 1.5, recommend
     adding a doubler, increasing the local wall thickness, or rerunning Phase 4
     of EXTENSIONS_PROMPT.md with a constraint on the local feature.

  4. Update the limitations section to remove the "linear static beam only"
     caveat as it applies to the verified joints, since shell results are now
     available there.

Also update the executive summary at the top of REPORT.md to include one sentence
about cross-verification: something like "Cross-verification in Ansys MAPDL 2026 R1
matched the beam results within X percent on peak stress and Y percent on peak
displacement, with shell submodels of the wing-fuselage joint and landing gear
attachment revealing a stress concentration factor of Z that informs the joint
reserve factor."


==============================================================================
PHASE H: Update the website
==============================================================================

If website/midnight-fea/ exists (from Phase 6 of EXTENSIONS_PROMPT.md), update
both index.html and index.md to add a "Cross-verified in Ansys" badge to the
hero block and add the Kt findings to the result cards. Copy the Ansys
screenshots into website/midnight-fea/assets/.

If the website directory does not yet exist, skip this phase and note it as
deferred to the EXTENSIONS_PROMPT Phase 6 run.


==============================================================================
PHASE I: Stop, summarize, push
==============================================================================

1. Print:
     - The three percent-diff numbers from beam verification.
     - The two Kt values from the shell submodels.
     - Any flags raised.
     - REPORT.md word count delta.
     - git diff --stat.

2. Wait for me to reply "ship it" or "push".

3. After approval:
     git add scripts/ansys_runner.py data/ansys_run/ data/ansys_verification*.csv \
             docs/figures/ansys_*.png docs/REPORT.md website/
     git commit -m "Ansys MAPDL cross-verification: beam plus joint and strut shell submodels"
     git push origin <current branch>

   Print the commit hash. Confirm push success.


Failure handling:
- If MAPDL fails to launch, capture the stderr and check for the most common
  causes: license not activated, license server unreachable, Ansys Student node
  limit exceeded, executable path quoting issue on Windows.
- If a PyMAPDL command times out, increase the timeout and retry once. If it
  times out twice, abort and report.
- If a .mac file errors at a specific line, print the line and the context
  so we can fix the export script in Phase 5 of EXTENSIONS_PROMPT.md.
- Do not edit the .mac files to make them run. Fix the generator in Phase 5
  instead, then regenerate, then retry. The .mac files are derived artifacts.
```

---

## After the runs complete

You will have, in addition to whatever Phase 5 of `EXTENSIONS_PROMPT.md` produced:

- `scripts/ansys_runner.py`, the reusable orchestration script
- `data/ansys_run/` with the three Ansys working directories
- `data/ansys_verification.csv` and the per-analysis CSVs
- `docs/figures/ansys_*.png` with real contour plots
- An updated `docs/REPORT.md` section 11 with real numbers and figures
- A "cross-verified" badge on the website (if Phase 6 of EXTENSIONS_PROMPT has already run)

## Why PyMAPDL rather than batch mode

Three reasons. First, PyMAPDL captures results into Python data structures directly, so the comparison table builds itself from the same numbers Claude Code can write into the report. No log scraping. Second, PyMAPDL's plot capture writes PNGs straight to disk at controlled DPI, so the report embeds them without manual screenshot work. Third, when something fails, PyMAPDL surfaces the MAPDL error string into the Python exception, which Claude Code can read and reason about. Batch mode hides errors in `.out` files that have to be grepped.

The trade is that PyMAPDL adds a startup cost per run (a few seconds for the MAPDL kernel handshake). For a one-shot verification this is fine. For the parametric sweep in Phase 4 of `EXTENSIONS_PROMPT.md`, batch mode is faster, but that sweep is in MATLAB anyway.

## If you are on macOS

Ansys 2026 R1 has no native macOS build. Three options: install Ansys Student inside a Windows VM (Parallels or VMware Fusion), use Boot Camp on Intel Macs, or remote desktop into a U-M CAEN lab machine that has Ansys installed. The prompt itself runs from any machine that can launch the Ansys executable, so once Ansys is reachable, the workflow is identical.
