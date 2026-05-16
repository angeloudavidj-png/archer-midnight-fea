# Ansys and Nastran cross-verification checklist

This document explains how to use the export files in [data/export/](../data/export/) to cross-verify the MATLAB beam FEA against a commercial solver, and how to run the two shell submodels that capture local stress concentrations the beam model cannot resolve.

## What gets exported

`main.m` writes four files into `data/export/` on every run:

| File | Purpose | Solver |
|---|---|---|
| `frame_LC2.bdf` | Full frame beam model under LC2, Nastran free-field bulk data | MSC Nastran / NX Nastran / Simcenter Nastran |
| `frame_LC2.mac` | Full frame beam model under LC2, Ansys APDL | Ansys Mechanical APDL |
| `joint_shell.mac` | Wing-to-fuselage joint shell submodel with embedded LC2 boundary loads | Ansys Mechanical APDL |
| `strut_top_shell.mac` | Landing gear main strut top shell submodel with embedded LCG boundary loads | Ansys Mechanical APDL |

All files use SI units (m, N, Pa, kg) and isotropic-equivalent material properties (CFRP at 70 GPa, 7075-T6 at 71.7 GPa). Composite ply-level effects are documented separately in section 9 of the [report](index.md) and are not yet wired through the export pipeline.

## 1. Frame beam cross-verification

The goal is to confirm that a commercial beam solver returns the same peak von Mises stress and peak displacement as the MATLAB FEA on the LC2 case. Disagreements above the tolerance below indicate either an export bug, a sign error in load application, or a genuine modeling difference (for example, Timoshenko vs Euler-Bernoulli shear correction).

### Target tolerances

| Quantity | MATLAB reference (LC2) | Tolerance |
|---|---|---|
| Peak von Mises stress | 175.4 MPa | within 10 percent (157.9 to 192.9 MPa) |
| Peak nodal displacement | 193.81 mm | within 5 percent (184.1 to 203.5 mm) |
| Number of nodes | 19 | exact |
| Number of beam elements | 18 | exact |

### Nastran procedure

```bash
nastran frame_LC2.bdf
```

After the run completes, open `frame_LC2.f06` (or `.op2`) and look for:

- The `D I S P L A C E M E N T S` block: find the maximum total displacement magnitude across all grids.
- The `S T R E S S` block for CBAR elements: locate the maximum von Mises (Nastran reports `SMAX` and `SMIN`; for a tube under axial+bending these dominate).

### Ansys APDL procedure

```bash
ansysXXX -b -i frame_LC2.mac -o frame_LC2.out
```

(Substitute the version-specific Ansys executable name.) The script's final `/COM` statement prints the peak von Mises and peak displacement in the output file. Additionally:

- `frame_LC2_displacement.png` shows the total displacement contour.
- `frame_LC2_vm_stress.png` shows the von Mises stress contour.

### What to do if results disagree

- **Peak VM off by more than 10 percent.** Most common cause: load sign error or wrong PBARL convention. Check that the FORCE cards in the .bdf use positive Z for the rotor thrusts and negative Z for the weight on the spine. Verify that the PBARL TUBE second field is the inner diameter, not the wall thickness.
- **Peak displacement off by more than 5 percent.** Likely a shear stiffness difference (Nastran CBAR and Ansys BEAM188 both default to Timoshenko; if shear is excluded the answer will be slightly different from MATLAB Euler-Bernoulli for short stocky elements). For our slender booms this should be negligible.
- **Element count off.** The .bdf or .mac file was truncated. Re-run `main.m` to regenerate.

## 2. Joint shell submodel

The submodel covers a 200 mm cylindrical region around the wing-to-fuselage attachment at spine node 3 (coordinates 6.0, 0.0, 1.2 m). Four tube stubs intersect at the joint center: spine -x, spine +x, boom -y (left boom inboard), boom +y (right boom inboard). Each stub is 200 mm long with the same cross section as the parent boom (OD 300 mm, wall 10 mm). Boundary loads at the four cut faces are the section forces from the LC2 beam analysis, embedded directly in the APDL script.

### Procedure

```bash
ansysXXX -b -i joint_shell.mac -o joint_shell.out
```

The script:

1. Builds the four tube stubs using cylindrical primitives.
2. Meshes with quadratic SHELL281 elements at 10 mm target size.
3. Creates four "remote master" nodes at each cut centroid, couples the cut-edge nodes rigidly via CERIG, and applies the 6-component (Fx, Fy, Fz, Mx, My, Mz) load extracted from the beam analysis.
4. Solves a linear static.
5. Saves `joint_shell_screenshot.png` and prints peak VM stress.

### What to look for

- The joint center should show a stress concentration relative to the far-field stub VM stress. Typical concentration factor for an unreinforced tube intersection is 2 to 4 times the beam-derived nominal stress. Higher than 4 suggests local detail (fillet, fastener pattern) that the simple cylinder geometry does not represent.
- The cut-face VM should match the post-process VM from the beam model within ~10 percent. Larger discrepancies usually mean the CERIG coupling is over-constraining the cut face (compare the Saint-Venant zone, roughly 1 diameter from the cut).

### Refinements David should consider

- Replace the simple tube intersection with a more realistic fitting geometry (boss, gusset, or fastener pattern) before drawing conclusions about the joint design.
- Add fillets at the intersection to soften the geometric concentration.
- Iterate on mesh size: refine to 5 mm at the joint center and verify the peak VM is mesh-converged.
- Swap the isotropic CFRP with a ply-stack shell section (Ansys ACP) once the Phase 3 composite analysis is bridged through.

## 3. Landing gear strut top shell submodel

Submodel center at the main left attachment (3.2, -0.6, 0.85 m). Two stubs: the main strut (angled toward the wheel contact at -y and -z) and the cross brace (along +y to the right main attachment). Both stubs are 200 mm long with OD 100 mm, wall 8 mm, in 7075-T6 aluminum. Boundary loads are the section forces from the LCG case, embedded in the script.

```bash
ansysXXX -b -i strut_top_shell.mac -o strut_top_shell.out
```

The script structure mirrors the joint submodel. Output: `strut_top_shell_screenshot.png` and printed peak VM.

### What to look for

- The strut-to-brace intersection is the obvious stress concentration. The beam analysis missed this entirely.
- Compare the peak VM here against the beam result (427.9 MPa for the static LCG case). Expected: shell VM higher than beam VM by 1.5 to 2.5x, reflecting the local geometric concentration.
- If the shell VM is over the 503 MPa yield even with the resized 100x8 strut (Phase 0), this directly motivates either a reinforced fitting or a different topology (trailing arm, sandwich strut).

## 4. After Ansys

Once both shell scripts have run successfully, replace the placeholder PNGs:

- `docs/figures/joint_shell_screenshot.png`
- `docs/figures/strut_top_shell_screenshot.png`

with the actual von Mises contours saved by the scripts. The placeholders are regenerated by every MATLAB run, so do **not** check in the placeholders after replacing them; use a separate output directory or rename to a stable name and update [docs/index.md](index.md) to point at the new names.

Update the "Cross-verification and joint submodels" section of [docs/index.md](index.md) with the actual peak VM values once they're available. The section already contains an "Awaiting Ansys results" cell in the comparison table that you can fill in.
