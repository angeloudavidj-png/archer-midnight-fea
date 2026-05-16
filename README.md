# Archer Midnight: MATLAB FEA of Frame and Landing Gear

A from-scratch 3D Euler-Bernoulli beam finite element analysis of the Archer Aviation Midnight eVTOL airframe and tricycle landing gear, written in base MATLAB with no toolbox dependencies. The project sizes structural members against four flight load cases and a FAR 23.473 hard landing case, and reports stress, displacement, and reserve factors.

### Headline results

| Component | Governing case | Peak σ_VM (MPa) | Reserve factor | Allowable (MPa) |
|---|---|---|---|---|
| Frame (CFRP) | LC2 2g symmetric maneuver | 175.4 | 2.00 | 350 |
| Landing gear (7075-T6) | LCG 3g landing + 0.5g drag | 1881.3 | 0.27 | 503 |

The frame carries positive margin in every flight case studied. The landing gear, with the as-specified 60 mm OD 5 mm wall strut, falls well short under the modeled 3g landing and is flagged for redesign (larger section or trailing-arm topology with energy absorption).

![Frame LC2 von Mises stress contour](docs/figures/frame_LC2_2g_maneuver_stress.png)

Full methodology, derivations, verification residuals, and a per-element discussion are in [docs/REPORT.md](docs/REPORT.md). Numerical results are read directly from [data/results_summary.csv](data/results_summary.csv), which is regenerated on every MATLAB run.

**Author:** David Angelou, B.S.E. Mechanical Engineering, University of Michigan (Class of 2027)
**Status:** Educational portfolio project. All Midnight parameters are public-domain estimates or reasonable engineering approximations; no proprietary Archer data is used.

---

## Why this project

Archer's Midnight is a 6-tilt / 6-lift, 5-seat eVTOL targeting ~150 mph cruise and ~100 mi range. The structural challenges of an eVTOL frame, distributed thrust booms, integrated wing/boom load paths, and a landing gear that must survive hard vertical descents at high disk-loading, map well onto a first-principles FEA exercise.

This repository was built to:

1. Demonstrate hand-rolled 3D beam FEA in MATLAB (no PDE Toolbox dependency for the frame solver).
2. Apply realistic eVTOL load cases (hover, transition, 3g hard landing per FAR 23.473) to a representative airframe topology.
3. Produce a clean, reviewable engineering report comparable to the BERGR FRR and VTI deliverables I produce at U-M.

## Repository layout

```
archer-midnight-fea/
├── README.md                       # This file
├── VSCODE_PROMPT.md                # Prompt for Claude Code / Copilot in VS Code to extend project
├── src/
│   ├── main.m                      # Master driver script
│   ├── aircraft_parameters.m       # Midnight geometry, mass, load factors
│   ├── material_properties.m       # CFRP and 7075-T6 properties
│   ├── build_frame_geometry.m      # Generate nodes and elements for the airframe
│   ├── build_landing_gear.m        # Generate nodes and elements for tricycle gear
│   ├── beam_element_3d.m           # 12x12 3D beam stiffness in global coordinates
│   ├── assemble_global_K.m         # Sparse global stiffness assembly
│   ├── apply_loads.m               # Build force vectors for each load case
│   ├── apply_boundary_conditions.m # Penalty / direct elimination of constrained DOFs
│   ├── solve_fea.m                 # Solve KU = F
│   ├── post_process.m              # Element forces, stress, reserve factors
│   ├── visualize_deformed.m        # 3D plot of undeformed + deformed structure
│   └── plot_stress_contour.m       # Color-coded stress on members
├── data/
│   └── midnight_params.mat         # Saved parameter struct (generated on first run)
├── docs/
│   ├── REPORT.md                   # Technical report
│   └── figures/                    # Output plots from MATLAB
├── tests/
│   ├── test_beam_cantilever.m      # Verify beam element against analytical cantilever
│   └── test_assembly.m             # Verify global K symmetry and positive semi-definite
├── .gitignore
└── LICENSE
```

## Quick start

Requires MATLAB R2022a or later. No toolboxes required for the core solver (the optional contour plotting uses `patch`, which is base MATLAB).

```matlab
>> cd src
>> main
```

`main.m` runs all four load cases on the frame and the 3g hard landing case on the landing gear, then writes figures to `../docs/figures/`.

## Load cases summarized

| Case | Description | Multiplier on weight | Reference |
|------|-------------|----------------------|-----------|
| LC1  | 1g static, all rotors at hover trim thrust | 1.0 | Baseline |
| LC2  | 2g symmetric maneuver (transition pull-up) | 2.0 | FAR 23.337 inspired |
| LC3  | Cruise wing lift + 6 forward rotors | 1.0 (steady) | Trim cruise |
| LC4  | Motor-out asymmetric thrust on one tilt rotor | 1.5 | One-engine-inoperative gust |
| LCG  | 3g vertical hard landing on tricycle gear | 3.0 | FAR 23.473 |

## Key results

See the headline table at the top of this README and the full per-case discussion in [docs/REPORT.md](docs/REPORT.md). Numbers are sourced from [data/results_summary.csv](data/results_summary.csv), which `main.m` regenerates on every run.

## Limitations and assumptions

This is a beam-element idealization, so it will not capture local skin buckling, joint stress concentrations, or composite ply-by-ply failure modes. The Midnight geometry used is a public-domain approximation based on Archer's published renderings, FAA filings, and press materials. Aerodynamic loads are applied as resultant forces at boom and wing nodes rather than from a coupled CFD solution. For a higher-fidelity follow-on, see the extensions listed in `VSCODE_PROMPT.md`.

## License

MIT. See LICENSE.
