# EXTENSIONS_PROMPT.md

This file holds the master extension prompt for the Archer Midnight FEA project. It takes the project from its current state (landing gear LCG failing with RF below 1) through six phases of engineering work and ends with a pushed GitHub repo, an updated report, and a portable website page.

## How to use

Paste the master prompt block below into Claude Code in your VS Code integrated terminal. The prompt is internally phased with explicit approval gates. At each gate Claude Code stops, summarizes what it did, and waits for you to reply "go" before continuing. If you only want to run one phase, scroll to "Individual phase prompts" at the bottom and paste just that block.

Realistic time budget: 4 to 8 hours of agentic execution plus your review time at the six gates. You can stop after any gate and resume later.

---

## Master prompt

```
You are operating in the archer-midnight-fea repository. You will execute six phases
of engineering work end to end. After each phase, stop, summarize what you did, show
me the diff and the key numbers, and wait for me to reply "go" or "approved" before
starting the next phase. If I ask for revisions, apply them and re-prompt at the
same gate.

Style rules for every file you write:
- Clean technical English, AIAA paper tone. First person plural is fine.
- No em dashes, no double hyphens, use commas instead.
- Do not invent numbers. Every result comes from an actual run.
- Reference figures by relative path and only if they exist on disk.


==============================================================================
PHASE 0: Landing gear strut resize (urgent, do this first)
==============================================================================

Context: the current 60 mm OD, 5 mm wall 7075-T6 landing gear strut fails the
LCG 3g hard landing case with a reserve factor near 0.27, meaning peak stress is
about 3.7 times the yield allowable. The fix is to grow the strut to a 100 mm OD
with 8 mm wall, which raises the second moment of area I by roughly 7.5x and the
bending stress drops by about 4.5x. Expected new RF is in the 1.1 to 1.3 range,
which is marginal but defensible. Verify this with the actual rerun.

Tasks:

1. Locate the strut definition. It lives in src/build_landing_gear.m and/or
   src/aircraft_parameters.m. Change OD from 60 mm to 100 mm and wall thickness
   from 5 mm to 8 mm. Make sure the dimensions are sourced from one place, not
   duplicated. If they were duplicated, refactor to a single source.

2. Re-run the pipeline:
       ./scripts/run_pipeline.sh --no-commit
   (or .ps1 on Windows). Confirm main.m runs cleanly and that
   data/results_summary.csv now shows the new landing gear RF.

3. Read the new RF from the CSV. If it is below 1.0, stop and tell me. If it is
   between 1.0 and 1.5, flag it as marginal. If above 1.5, proceed.

4. Add a "Design iteration" subsection to docs/REPORT.md under section 6 (Load
   cases and results) showing the before and after: 60 mm OD with RF 0.27 versus
   100 mm OD with RF X.YZ. Frame this as engineering judgment: we identified the
   failure, diagnosed the root cause (insufficient bending stiffness), sized the
   fix from beam theory, and verified with the rerun. This is the kind of loop a
   hiring engineer wants to see.

5. Update the landing gear section of README.md if the original dimensions are
   quoted there.

GATE 0: stop. Print the new RF, the percent change in mass for the strut (a 100 mm
strut is heavier than a 60 mm strut, quantify how much), and the diff stat. Wait
for "go".


==============================================================================
PHASE 1: Modal analysis of the airframe
==============================================================================

Goal: identify the airframe natural frequencies and check them against the rotor
RPM ranges so we can flag any resonance risks at hover and cruise rotor speeds.

Tasks:

1. Add src/build_mass_matrix.m: consistent mass matrix for the 3D beam element,
   12 by 12, using the standard lumped or consistent formulation. Document the
   choice in the file header.

2. Add src/assemble_global_M.m: assembles the global mass matrix from element
   mass matrices, parallel to assemble_global_K.m.

3. Add src/modal_analysis.m: solves the generalized eigenvalue problem
   K x = lambda M x using eigs() for the first 20 modes. Returns frequencies in Hz.
   Document that the first 6 modes should be near zero (rigid body) and elastic
   modes start at mode 7.

4. Extend src/main.m with a new section that calls modal_analysis on the frame
   (with rigid body modes removed by using the constrained K and M).

5. Compute the rotor blade pass frequencies. The Midnight has 12 rotors, hover
   RPM is roughly 1500 to 2000, cruise tilt rotor RPM lower. Compute n_blades x
   RPM / 60 for both regimes and overlay the airframe modes on a Campbell-style
   plot. Save to docs/figures/campbell_diagram.png.

6. Flag any airframe mode within 15 percent of a blade pass harmonic. This is
   the resonance avoidance margin used in helicopter design.

7. Add tests/test_modal_rigid_body.m: verifies that the first 6 modes of the
   unconstrained K, M pair are at zero frequency to numerical tolerance.

8. Add a new section to docs/REPORT.md titled "Modal analysis" between sections 6
   and 7. Include the Campbell diagram, a table of the first 10 elastic modes,
   and a discussion of any flagged resonances.

GATE 1: stop. Print the first 10 elastic mode frequencies, any resonance flags,
and the diff stat. Wait for "go".


==============================================================================
PHASE 2: Landing gear drop test dynamics
==============================================================================

Goal: replace the static 3g landing approximation with an explicit time
integration of the landing event at the FAR 23.473 sink rate of 2.6 m/s. Capture
the peak transient load and compare it against the static estimate. Real landings
overshoot 3g, sometimes significantly.

Tasks:

1. Add src/newmark_integrator.m: implements Newmark beta time integration
   (beta = 0.25, gamma = 0.5) for the linear dynamic equation M ddU + C dU + KU = F.

2. Add src/build_damping_matrix.m: Rayleigh damping C = alpha M + beta K with
   alpha and beta tuned for 3 percent modal damping on the first two elastic modes
   of the landing gear assembly. Use the modal analysis results from Phase 1.

3. Add src/drop_test.m: sets up the landing event. Initial velocity 2.6 m/s
   downward on every node. Ground reaction modeled as a stiff penalty contact at
   the wheel patch nodes (kN times penetration depth). Time step dt small enough
   to capture the contact pulse, target 1e-5 seconds. Total simulated time
   0.05 seconds.

4. Output peak axial force, peak bending moment, peak von Mises in the strut, and
   peak nodal vertical acceleration in g. Write these to
   data/drop_test_summary.csv.

5. Generate docs/figures/drop_test_strut_force.png showing strut axial force vs
   time, and docs/figures/drop_test_accel.png showing nodal acceleration vs time
   at the wheel and at the airframe attachment.

6. Compare to the static LCG 3g estimate. The dynamic factor (peak dynamic load
   over static 3g load) is the headline number. Report it in
   data/drop_test_summary.csv as dynamic_factor.

7. Add tests/test_newmark_sdof.m: verifies the integrator against the analytical
   solution of a single DOF spring-mass-damper system.

8. Extend docs/REPORT.md with a new section "Landing gear drop test dynamics"
   after the modal analysis section. Include both transient figures, the peak
   numbers, and a frank discussion of the dynamic factor. If the dynamic factor
   exceeds the 3g static estimate by more than 20 percent, recommend rerunning
   Phase 0 with the corrected design load.

GATE 2: stop. Print the dynamic factor, peak strut von Mises, and any
recommendation to revisit Phase 0. Wait for "go".


==============================================================================
PHASE 3: Composite ply failure on the boom layup
==============================================================================

Goal: replace the isotropic equivalent CFRP treatment with a proper layup analysis
on the highest stressed boom element. Use Tsai-Wu as the primary criterion and
Hashin as a cross-check for fiber versus matrix failure modes.

Tasks:

1. Add src/composite_layup.m: defines a quasi-isotropic [0/45/-45/90]_s layup with
   per-ply thickness 0.125 mm. Returns the ABD matrix from classical lamination
   theory.

2. Add src/material_composite.m: defines per-ply IM7/8552 or T800S/3900 properties
   (E1, E2, G12, nu12, plus strength allowables Xt, Xc, Yt, Yc, S). Cite the data
   source in the file header.

3. Add src/tsai_wu.m and src/hashin.m: compute the failure indices given a stress
   state in material axes.

4. Add src/boom_ply_analysis.m: takes the section forces and moments from the
   beam FEA at the boom's most stressed element, distributes them through the
   layup to per-ply stress states, and evaluates Tsai-Wu and Hashin per ply.
   Returns the critical ply, failure mode, and margin.

5. Output to data/boom_ply_summary.csv with columns ply_index, orientation,
   sigma_11, sigma_22, tau_12, tsai_wu_index, hashin_fiber, hashin_matrix.

6. Generate docs/figures/boom_layup_failure.png: a bar chart of failure indices
   per ply, with the critical ply highlighted.

7. Add tests/test_clt_isotropic.m: verifies that a [0/0/0/0] layup of an
   isotropic material recovers the expected isotropic ABD response.

8. Extend docs/REPORT.md with a new section "Composite ply failure analysis"
   after the drop test section. Include the table of per-ply states and the
   failure chart. Note explicitly which ply is critical and whether the failure
   mode is fiber tension, fiber compression, or matrix dominated, since the
   design responses to each are different.

GATE 3: stop. Print the critical ply, failure mode, peak Tsai-Wu index, and any
recommendation about adding plies or rotating the layup. Wait for "go".


==============================================================================
PHASE 4: Parametric sweep over boom OD, wall, and strut geometry
==============================================================================

Goal: map the design space against reserve factor and mass for the boom and the
landing gear strut together, so we can see the Pareto frontier and pick a design
that meets RF with minimum mass.

Tasks:

1. Add src/parametric_sweep.m: loops over a grid of boom OD (200 to 400 mm in 50 mm
   steps), boom wall (5 to 15 mm in 2.5 mm steps), strut OD (80 to 140 mm in 10 mm
   steps), strut wall (5 to 12 mm in 1 mm steps). For each combination, override
   the geometry in build_frame_geometry and build_landing_gear, run the governing
   load cases (LC2 for frame, LCG for gear), and record min RF and total mass.

2. Output data/parametric_sweep.csv with all combinations and their min RF, total
   mass, and a feasibility flag (RF greater than or equal to 1.5).

3. Generate docs/figures/pareto_mass_vs_rf.png: scatter plot of total mass on the
   x-axis and minimum RF on the y-axis, with feasible designs colored green and
   infeasible designs gray. Mark the current design and the Phase 0 design as
   labeled points. Draw the Pareto frontier as a line.

4. Identify the minimum mass design with RF greater than 1.5, and the minimum
   mass design with RF greater than 2.0. Print both.

5. Extend docs/REPORT.md with a new section "Parametric sizing study" after the
   ply failure section. Include the Pareto plot, the recommended optimum, and the
   sensitivity of the optimum to the RF target.

Implementation note: this sweep can be large (4 x 5 x 7 x 8 = 1120 combinations).
Run it in parallel with parfor if MATLAB Parallel Computing Toolbox is licensed,
otherwise serial is fine (estimate ~10 minutes per case at this beam size, so plan
accordingly or coarsen the grid).

GATE 4: stop. Print the recommended optimum, its mass, its RF, and the sweep run
time. Wait for "go".


==============================================================================
PHASE 5: Ansys or Nastran cross-verification plus shell joint follow-on
==============================================================================

Goal: prove the beam results by exporting to a commercial solver, then build a
shell-element submodel of the two highest stressed regions (wing-to-fuselage
joint and the top of the landing gear strut where it meets the airframe) to
capture local stress concentrations that the beam model cannot resolve.

Tasks:

1. Add src/export_bdf.m: writes a Nastran bulk data file (.bdf) of the frame
   beam model, including CBAR elements with PBARL properties, GRID nodes, MAT1
   material card, SPC constraints, and FORCE cards for LC2. Save to
   data/export/frame_LC2.bdf.

2. Add src/export_apdl.m: writes an Ansys APDL script of the same model. Save
   to data/export/frame_LC2.mac.

3. Add docs/AnsysVerification.md: a step-by-step checklist for running both
   solvers, capturing the max von Mises, and comparing against the MATLAB beam
   result. Target agreement is within 10 percent on peak stress and within 5
   percent on peak displacement. Larger gaps indicate either an export bug or a
   genuine modeling difference that should be flagged.

4. Build a shell submodel of the wing-fuselage joint. Identify the boom-to-
   fuselage attachment node from build_frame_geometry. Define a local cylindrical
   region 200 mm radius around that node, mesh with quadratic shell elements,
   import the beam-derived forces and moments as boundary conditions on the cut
   sections. Write the APDL script to data/export/joint_shell.mac. Use the same
   CFRP isotropic-equivalent properties for now (Phase 3 ply data is a future
   refinement).

5. Build a shell submodel of the landing gear strut top, same approach. APDL
   script to data/export/strut_top_shell.mac.

6. Add docs/figures/joint_shell_screenshot.png and
   docs/figures/strut_top_shell_screenshot.png as placeholder PNGs with a note
   "to be filled after Ansys run". The user (David) will run the Ansys scripts,
   capture the screenshots, and replace these placeholders.

7. Extend docs/REPORT.md with a new section "Cross-verification and joint
   submodels" after the parametric study section. Document the export procedure,
   the planned comparison table (to be filled in after Ansys runs), and the
   shell submodel geometry.

GATE 5: stop. Confirm all .bdf and .mac files exist and are non-empty. Print a
checklist of what David needs to do in Ansys to complete the verification. Wait
for "go".


==============================================================================
PHASE 6: Report finalization and website export
==============================================================================

Goal: polish the report to its final form with all five new sections integrated,
and generate a portable website page for David's portfolio.

Tasks:

1. Read the current docs/REPORT.md end to end. Verify all six new sections (the
   design iteration in Phase 0, plus the four major analyses in Phases 1 through 4,
   plus the verification plan in Phase 5) are present, the load case table reflects
   the Phase 0 fix, and the executive summary leads with the right governing number.

2. If the executive summary still references the old failing RF, rewrite it to
   reflect the new design. Lead with: governing case, peak von Mises, reserve
   factor, and the most interesting finding from Phases 1 to 5 (probably the
   dynamic factor or the critical ply mode).

3. Create the website export at website/midnight-fea/index.html. Make it
   self-contained, no external CSS frameworks, no JavaScript dependencies.
   Use semantic HTML and a small inline stylesheet (system fonts, dark text on
   white, max-width 720 px, generous line-height). Include:
       - Hero block with the project title, a one line tagline, and one hero
         image (the deformed frame plot of the governing case).
       - Three result cards showing governing RF, dynamic factor, and critical
         ply mode.
       - An "Approach" section, 200 words.
       - A "Results highlights" section with three or four embedded figures and
         their captions.
       - A "What I would do next" section listing the items from VSCODE_PROMPT.md
         that are not yet implemented.
       - A footer linking to the GitHub repo and to David's LinkedIn.

4. Also create website/midnight-fea/index.md, a Markdown version of the same
   content for Hugo, Jekyll, MkDocs, or any static site generator the portfolio
   might use. Same structure, same figures, plain Markdown.

5. Copy the four or five most important figures from docs/figures/ to
   website/midnight-fea/assets/, so the website is self-contained and does not
   reach across directory boundaries.

6. Add a "Featured project" link block to README.md pointing to the website
   directory and to the report.

7. Run `git status` and `git diff --stat`. Print the summary: total files
   changed, total lines added or removed, count of new figures, REPORT.md final
   word count, and the executive summary (the first paragraph of REPORT.md).

GATE 6: stop. Wait for me to reply "ship it" or "push".


==============================================================================
PHASE 7: Commit and push
==============================================================================

After my approval at Gate 6:

    git add src/ tests/ docs/ data/ website/ README.md PROMPT.md EXTENSIONS_PROMPT.md
    git commit -m "Add Phase 0 strut fix and Phases 1 to 5 extensions, plus website export"
    git push origin <current branch>

Print the commit hash and the remote URL. Confirm push success.

If the commit message looks too dense, suggest 6 smaller commits, one per phase,
and let me pick.


Failure handling:
- If any phase fails, stop at that gate, tell me which step in which phase failed
  and the exact error. Do not silently fall back. Do not invent numbers to fill
  gaps in the report.
- If a test you wrote fails after writing the implementation, debug the
  implementation, not the test. The tests encode the expected behavior.
- If the parametric sweep in Phase 4 is taking longer than 30 minutes, ask me
  whether to coarsen the grid or wait.
```

---

## Individual phase prompts

If you want to run just one phase later, paste only that phase's block from the master prompt above, with this preamble:

```
You are operating in the archer-midnight-fea repository. Style rules: clean
technical English, no em dashes or double hyphens, never invent numbers, never
reference figures that do not exist. Execute the phase below and stop at the
gate.

[paste the relevant phase block here]
```

---

## What this prompt produces, end to end

When all six phases complete and push, your repo will have:

- A landing gear that actually passes its governing load case with the design rationale documented in the report.
- A modal analysis module that flags resonance risk against the rotor RPM map.
- A Newmark explicit dynamics drop test that reveals the real peak landing load.
- A Tsai-Wu and Hashin ply failure analysis on the boom layup that names the critical ply and failure mode.
- A parametric sweep that maps the design space and proposes a minimum mass design at the target RF.
- Nastran and Ansys export with shell submodels staged for cross-verification.
- An updated `docs/REPORT.md` integrating all of the above.
- A portable `website/midnight-fea/index.html` and `index.md` for your portfolio.
- All of it pushed to GitHub in a clean commit.

That sequence is the engineering arc a recruiter wants to see: identify a failure, fix it with judgment, layer on the dynamic and material refinements, prove it with cross-verification, and present it cleanly.
