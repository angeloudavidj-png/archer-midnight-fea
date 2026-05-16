# PROMPT.md

Paste the prompt block below into Claude Code in your VS Code integrated terminal (or the Claude Code chat panel) at the root of this repo. It runs the full pipeline: results, figures, report, and a GitHub push, with a single approval gate before the push.

If MATLAB is installed and on PATH, the prompt will use it. If not, it will fall back to Python and matplotlib to produce the figures from the project's actual geometry and material definitions. Either path produces a real `docs/REPORT.md` with embedded figures and a push to your configured GitHub remote.

---

```
You are operating in the archer-midnight-fea repository. Goal: produce a polished
recruiter facing technical report at docs/REPORT.md, the supporting figures in
docs/figures/, and push everything to the configured GitHub remote. Work
autonomously through the steps below. Stop only at the final approval gate before
git push.

Style rules for every file you write:
- Clean technical English, AIAA paper tone. First person plural is fine.
- No em dashes, no double hyphens, use commas instead.
- No marketing language, no buzzwords.
- Never invent numbers. Pull every result from data/results_summary.csv or the
  MATLAB run log on disk. If a number is missing, say so and skip that row.
- Never reference a figure that does not exist on disk.


STEP 1: Confirm environment

Verify we are at the repo root by checking for src/, docs/, tests/, scripts/, README.md.
Run `git status` and report the working tree state.
Detect whether MATLAB is available: try `which matlab` (Linux/macOS) or
`Get-Command matlab` (Windows), then check common install paths under
/Applications/MATLAB_*, /usr/local/MATLAB/*, and C:\Program Files\MATLAB\*.
Report which branch you will take.


STEP 2A: If MATLAB is available

Run `./scripts/run_pipeline.sh --no-commit` on macOS or Linux, or
`./scripts/run_pipeline.ps1 -NoCommit` on Windows.
Tail data/last_run.log and confirm no MATLAB errors.
Verify docs/figures/ now contains PNGs and data/results_summary.csv exists.
Skip to STEP 3.


STEP 2B: If MATLAB is not available

Generate figures using Python with matplotlib and numpy. Install them in a venv if
they are not already available: `python3 -m venv .venv && source .venv/bin/activate
&& pip install matplotlib numpy`. Add .venv/ to .gitignore if not there.

Read the project's actual geometry, materials, and load cases from the source code
so the figures reflect the real model, not invented data:
  - src/aircraft_parameters.m for MTOW, wingspan, rotor positions, fuselage length
  - src/material_properties.m for CFRP and 7075-T6 properties
  - src/build_frame_geometry.m for node and element coordinates
  - src/build_landing_gear.m for the strut geometry
  - src/apply_loads.m for the load case definitions

Compute analytical estimates for the dominant load paths using beam theory
(cantilever boom under rotor thrust, landing gear strut under axial plus bending).
Use these to populate data/results_summary.csv with the schema:
component,load_case,max_vm_MPa,min_RF,max_disp_mm,allowable_MPa

Generate these PNGs into docs/figures/ at 150 dpi minimum:
  1. frame_geometry.png: 3D wireframe of the frame from build_frame_geometry,
     with rotor positions marked.
  2. landing_gear_geometry.png: 3D wireframe of the gear from build_landing_gear,
     with the wheel patch contact node highlighted.
  3. load_case_summary.png: grouped bar chart of peak von Mises per load case,
     with the material allowable as a horizontal reference line.
  4. reserve_factor_summary.png: bar chart of reserve factors per load case,
     with RF = 1 and RF = 1.5 reference lines.
  5. boundary_conditions.png: a 2D sketch showing the fixed nodes and applied
     load arrows for the governing load case (LC2 if frame, LCG if gear).

Write a one line note at the top of data/results_summary.csv as a comment:
"# Analytical beam theory estimates, not full FEA. Re-run MATLAB pipeline for
 verified values." so the report can be honest about provenance.


STEP 3: Read disk state as ground truth

Parse data/results_summary.csv into a structured table.
List every PNG file currently in docs/figures/.
These are the only numbers and figures the report may use.


STEP 4: Write docs/REPORT.md

Audience: recruiter or hiring engineer at Archer, Joby, Wisk, Beta, Boeing,
Lockheed. They will skim in 90 seconds and decide whether to keep reading the code.

Section structure:
  1. Executive summary, 5 to 8 sentences. Lead with the governing load case and
     peak von Mises plus reserve factor. State the conclusion a design engineer
     would draw.
  2. Background. What the Midnight is, why frame and landing gear matter for a
     piloted eVTOL, relevant FAR Part 23 sections (especially 23.473 for landing
     gear sink rate and 23.305 for limit and ultimate loads).
  3. Geometry and abstraction. Describe what was modeled and what was simplified.
     Be explicit that the boom OD represents an equivalent integrated wing plus
     boom section, not the physical boom alone. List node count, element count,
     total DOF. If STEP 2B was taken, clearly state that results are analytical
     beam theory estimates pending the full FEA run.
  4. Materials. CFRP frame and 7075-T6 landing gear with E, nu, rho, and the
     design allowable used for the reserve factor calculation.
  5. FEA formulation. 3D Euler-Bernoulli beam, 12 DOF per element, sparse global
     K, small deflection linear static. Include the bending stiffness sub-matrix
     in LaTeX block. Cite assemble_global_K.m and beam_element_3d.m by filename.
  6. Load cases and results. Table every row from results_summary.csv with
     component, load case, peak VM in MPa, reserve factor, peak displacement in
     mm, and governing location. Bold the governing row. Embed the relevant
     figures inline using relative paths like ![caption](figures/load_case_summary.png).
  7. Verification. Reference tests/test_beam_cantilever.m and tests/test_assembly.m
     with the actual residuals from the tests (cantilever should match analytical
     PL^3/(3EI) to 1e-13 relative, global K should be symmetric to ~1e-12, and
     exactly 6 rigid body modes should appear in modal analysis).
  8. Limitations. No local buckling, no joint stress concentration, no fatigue,
     linear static only, beam idealization misses shear webs and skin
     contribution. Be honest, beat the reader to this list.
  9. Future work. List planned extensions: modal analysis, drop test dynamics,
     composite ply failure analysis with Tsai-Wu, parametric sweep, Ansys
     verification.
 10. References. Archer Aviation public materials, FAR Part 23, Cook Malkus
     Plesha or Bathe for the FEA formulation, Jones for composite mechanics if
     ply failure is referenced.

Length 1500 to 3000 words. Embed every PNG that exists in docs/figures/ at least
once, in the relevant section. Use a Markdown table for the load case results.


STEP 5: Update README.md hero

Replace or insert at the very top of README.md a recruiter facing summary with
three parts:
  (a) One sentence on what the project is.
  (b) A small results table showing the governing load case for frame and for
      landing gear with peak von Mises and reserve factor.
  (c) One hero figure embedded from docs/figures/, ideally load_case_summary.png
      or the deformed shape of the governing case.
Link to docs/REPORT.md for the full report.
Keep the existing usage and structure sections below the hero. Do not duplicate
the full report content.


STEP 6: Show me what is about to ship

Run `git status` and `git diff --stat`.
Print a summary: list of changed files, count of new figures, REPORT.md word
count, and the three key result numbers (governing case, peak VM, RF).


STEP 7: STOP. Wait for my approval.

Do not commit. Do not push. Wait for me to reply with "go" or "approved" or
"push it". If I ask for revisions, apply them and return to STEP 6.


STEP 8: After approval, commit and push

git add docs/ data/results_summary.csv README.md PROMPT.md
git commit -m "Pipeline run: refresh figures, report, and results summary"
git push origin <current branch>

Print the commit hash and the remote URL. Confirm the push succeeded.


Failure handling: if any step fails, stop and tell me which step and the exact
error. Do not silently fall back to partial outputs. Do not invent numbers to
fill gaps. If a figure cannot be generated, omit it from the report and note
the omission in STEP 6.
```

---

## What to do if you do not have MATLAB locally

The prompt's Branch B handles this. It will install matplotlib and numpy into a local venv, read the geometry and materials from your `.m` source files, generate analytical beam theory estimates, and produce real figures from real model parameters. The report will be honest that the numbers are analytical pending full FEA, so a recruiter reading it will not be misled.

When you do install MATLAB (U-M site license covers you, see `mathworks.umich.edu`), rerun the prompt and Branch A will replace the analytical numbers with verified FEA results in one shot.

## One time git setup

Before the first push, in the VS Code integrated terminal at the repo root:

```
git init
git add .
git commit -m "Initial commit: Archer Midnight FEA project"
git branch -M main
git remote add origin https://github.com/YOUR-USERNAME/archer-midnight-fea.git
git push -u origin main
```

After that, the prompt's STEP 8 will push to this remote on every refresh.
