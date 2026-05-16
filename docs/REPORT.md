# Archer Midnight: Structural FEA of Frame and Landing Gear

**Author:** David Angelou
**Affiliation:** Department of Mechanical Engineering, University of Michigan
**Date:** 2026
**Tools:** MATLAB R2025b (no toolbox dependency, base MATLAB only)

---

## 1. Executive summary

We present a 3D Euler-Bernoulli beam finite element analysis of the Archer Aviation Midnight, a 5-seat, 12-rotor electric vertical takeoff and landing (eVTOL) aircraft. The composite airframe is sized against four flight load cases (1g hover, 2g symmetric maneuver, cruise, and motor-out asymmetric thrust) and the aluminum tricycle landing gear is sized against a 3g hard landing with 0.5g sliding friction at the contact patches. The governing flight case is the 2g symmetric maneuver, which produces a peak von Mises stress of 175.4 MPa in the inboard boom segments against a CFRP design allowable of 350 MPa, a reserve factor of 2.00. The frame therefore carries positive margin in every flight case studied. The landing gear, by contrast, produces a peak von Mises stress of 1881 MPa in the main struts against the 7075-T6 yield of 503 MPa, a reserve factor of 0.27, well below the design target of unity. The dominant load is bending in the main struts driven by the 0.6 m lateral offset between the attachment and the wheel contact, combined with the horizontal inertia of the airframe. The analysis therefore flags the landing gear as a design iteration target: a larger strut section, an internally reinforced shell, or a trailing-arm topology with an energy-absorbing oleo would all close this gap.

## 2. Background

Archer Aviation's Midnight is a piloted eVTOL targeting urban air mobility, with 6 forward tilt rotors and 6 fixed lift rotors arranged on two outboard booms. Public sources put the maximum takeoff weight near 3,175 kg (~7,000 lb), wingspan near 15 m, and design cruise near 150 mph. Archer has cleared three of the four FAA Type Certification phases as of 2026, has been named the official air taxi provider for the LA28 Olympics, and is co-developing a clean-sheet hybrid VTOL with Anduril for defense applications.

The structural sizing problem for a piloted eVTOL is non-trivial because the airframe must simultaneously carry distributed rotor thrust that varies through hover, transition, and cruise; aerodynamic wing lift in forward flight; asymmetric one-engine-inoperative loads; and ground reactions through the landing gear during taxi, takeoff, and landing. Two FAR Part 23 sections are particularly load-relevant:

- **FAR 23.305** establishes limit and ultimate load conditions. The structure must withstand limit loads without permanent deformation and ultimate loads (typically 1.5 times limit) without failure.
- **FAR 23.473** sets minimum landing sink rate criteria for the design of the landing gear and supporting structure. A 3g vertical load factor is a representative quasi-static surrogate for the dynamic energy absorption that an oleo or trailing arm provides.

This analysis builds a tractable beam-element model that captures the dominant load paths through the airframe and gear and reports stress and reserve factors for structural assessment.

## 3. Geometry and abstraction

### 3.1 Frame model

The Midnight airframe is idealized as a 3D space frame of beam elements (see [figures/frame_LC1_hover_static_deformed.png](figures/frame_LC1_hover_static_deformed.png) for the undeformed topology in light gray):

- A central fuselage spine of 5 nodes from nose (x = 0) to tail (x = 12 m).
- Two booms running spanwise from the mid-fuselage attachment (spine node 3) to outboard tips at y = ±6.5 m. Each boom carries 6 motor stations.
- A V-tail of 2 beams from the aft spine node to upper aft tip nodes.

The frame totals **19 nodes and 18 beam elements**. With 6 degrees of freedom per node, the global system has **114 total DOFs**. The boundary condition fully fixes spine node 3 (the wing-to-fuselage attachment) in all 6 DOFs as an inertia-relief surrogate for trim flight, leaving **108 free DOFs**.

A critical modeling note: in the real Midnight the wing skin and spar caps provide the primary spanwise moment-carrying structure, not the boom. Since this beam idealization does not include the wing as a separate distributed-stiffness member, the "boom" cross section in the model represents the **equivalent integrated wing-plus-boom moment of inertia** at each spanwise station. This gives a defensible cantilever bending response without the complexity of a coupled wing-boom shell model. The reader should not interpret the boom outer diameter as a physical boom; it is an equivalent stiffness.

### 3.2 Landing gear model

The tricycle gear is modeled separately from the frame as a 6-node, 4-element assembly: a nose strut from a nose attachment to a single nose contact, two main struts angled outboard from their attachments to their respective wheel contacts, and a cross brace between the two main attachments. The global system has **36 total DOFs**, of which the three contact nodes are fully clamped (18 DOFs), leaving **18 free DOFs**.

The decision to clamp all 6 DOFs at the contacts (rather than just translation) reflects a brake-locked condition during the spin-down phase of a hard landing. Pinning translations only leaves the nose strut free to rotate about its contact and the main subassembly free to spin about the line through the two main contacts, which produces a singular stiffness matrix; the clamped condition removes those rigid-body modes.

### 3.3 Cross sections

| Member | Material | Cross section | A (mm²) |
|---|---|---|---|
| Frame booms and spine | CFRP quasi-isotropic | Hollow tube, OD 300 mm, wall 10 mm (equivalent wing+boom) | 9,111 |
| Landing gear struts | 7075-T6 Aluminum | Hollow tube, OD 60 mm, wall 5 mm | 864 |

Section properties (area, second moments, polar moment) are computed in [src/tube_section.m](../src/tube_section.m) from the hollow circular tube formulas:

$$A = \frac{\pi}{4}(OD^2 - ID^2), \quad I = \frac{\pi}{64}(OD^4 - ID^4), \quad J = \frac{\pi}{32}(OD^4 - ID^4)$$

## 4. Materials

| Property | CFRP quasi-iso | 7075-T6 |
|---|---|---|
| Young's modulus E (GPa) | 70 | 71.7 |
| Shear modulus G (GPa) | 27 | 26.9 |
| Poisson ratio ν | 0.30 | 0.33 |
| Density ρ (kg/m³) | 1600 | 2810 |
| Design allowable (MPa) | 350 (knockdown on 600 ultimate) | 503 (yield) |

The CFRP design allowable applies a 0.58 knockdown on the conservative 600 MPa tensile allowable, covering environmental, fatigue, and damage tolerance margins typical for a quasi-isotropic [0/45/-45/90]s layup. The 7075-T6 allowable is the published tensile yield.

## 5. FEA formulation

### 5.1 Element

Each member is modeled with a 3D Euler-Bernoulli beam element with 6 DOFs per node (three translations and three rotations) for a 12-DOF element stiffness matrix in local coordinates. The local stiffness decomposes into decoupled axial, torsional, and two-plane bending sub-matrices. The bending blocks use Hermite cubic shape functions and take the standard form:

$$K_{bend} = \frac{EI}{L^3} \begin{bmatrix} 12 & 6L & -12 & 6L \\ 6L & 4L^2 & -6L & 2L^2 \\ -12 & -6L & 12 & -6L \\ 6L & 2L^2 & -6L & 4L^2 \end{bmatrix}$$

Local-to-global transformation is a 3×3 rotation expanded block-diagonally to 12×12 (one block per 3-DOF subvector). Implementation is in [src/beam_element_3d.m](../src/beam_element_3d.m).

### 5.2 Assembly and solution

The global stiffness matrix is assembled in [src/assemble_global_K.m](../src/assemble_global_K.m) using sparse triplet construction. For each element we compute 144 triplets and concatenate, then call `sparse(I, J, V)` once. The global system K U = F is solved by direct elimination of constrained DOFs after applying boundary conditions ([src/apply_boundary_conditions.m](../src/apply_boundary_conditions.m)); the reduced system is solved with MATLAB's backslash, which dispatches to a sparse LU factorization. Conditioning is checked with `condest` before solving and flags any system with condition number above 1e14.

### 5.3 Post-processing

Element internal forces are recovered by transforming the element nodal displacements back to local coordinates and multiplying by the element local stiffness ([src/post_process.m](../src/post_process.m)). From the internal axial force, transverse shears, torsion, and two bending moments, we compute:

- Axial stress σ_axial = N / A
- Bending stress σ_bend = √((M_y c/I_y)² + (M_z c/I_z)²)
- Torsional shear τ = T c / J
- Combined von Mises σ_VM = √((σ_axial + σ_bend)² + 3 τ²)
- Reserve factor RF = σ_allow / σ_VM

The outer fiber radius c = OD/2 is used since the maximum stress in a hollow circular tube occurs at the outermost fiber under combined bending.

## 6. Load cases and results

Five load cases are evaluated. Numerical results below are read directly from [data/results_summary.csv](../data/results_summary.csv), which is regenerated by `main.m` on every run.

### 6.1 Load case definitions

| Case | Description | Load factor | Application |
|---|---|---|---|
| LC1 | 1g hover, all 12 rotors at trim thrust | 1.0 | T per rotor = MTOW·g / 12 = 2,595 N at each motor node |
| LC2 | 2g symmetric pull-up maneuver | 2.0 | All rotor thrusts and weights scaled by 2 |
| LC3 | Trimmed cruise | 1.0 | Elliptical wing lift at motor nodes, 6 tilt rotors carry cruise drag ≈ 0.05·W |
| LC4 | Outboard tilt rotor out, others at 1.5x | 1.5 | Worst asymmetric thrust case |
| LCG | 3g hard landing, FAR 23.473 inspired | 3.0 | Nose 10% / mains 45% each vertical, + 0.5g forward inertia drag |

### 6.2 Results table

| Component | Load case | Max σ_VM (MPa) | Min RF | Max disp (mm) | Allowable (MPa) |
|---|---|---|---|---|---|
| Frame | LC1 hover static | 87.70 | 3.99 | 96.90 | 350 |
| **Frame** | **LC2 2g maneuver** | **175.40** | **2.00** | **193.81** | **350** |
| Frame | LC3 cruise | 87.70 | 3.99 | 87.70 | 350 |
| Frame | LC4 motor out | 100.49 | 3.48 | 145.36 | 350 |
| **Landing gear** | **LCG 3g landing** | **1881.26** | **0.27** | **289.42** | **503** |

The two governing rows are bolded: LC2 governs the frame at RF 2.00, and the landing gear LCG case is critical with RF below unity.

### 6.3 Frame discussion

The frame results are consistent across load cases. LC1 hover and LC3 cruise produce nearly identical peak stresses (87.7 MPa) because the total vertical force is the same in both, and the equivalent boom stiffness used in the model integrates the wing into the spanwise load path; the difference between distributed elliptical lift and discrete rotor thrust is small at the resolution of this beam model. LC2 doubles every load and produces twice the linear elastic response (175.4 MPa, two times 87.7). LC4 produces a moderate 100.5 MPa peak: the loss of the outboard starboard rotor creates a rolling moment, but the inboard rotors at 1.5x compensate and the net rolling moment is reacted at the wing attachment, which is the fully-fixed boundary node.

In every flight case the boom remains below the CFRP allowable with reserve factor above 2. Both [figures/frame_LC2_2g_maneuver_deformed.png](figures/frame_LC2_2g_maneuver_deformed.png) (deformed shape, exaggeration ×100) and [figures/frame_LC2_2g_maneuver_stress.png](figures/frame_LC2_2g_maneuver_stress.png) (color-coded von Mises) confirm that the highest stresses occur at the inboard boom segments adjacent to the wing attachment, where the cantilevered moment arm from the outboard motor stations is largest.

![Frame LC2 2g maneuver, deformed shape (×100)](figures/frame_LC2_2g_maneuver_deformed.png)

![Frame LC2 2g maneuver, von Mises stress](figures/frame_LC2_2g_maneuver_stress.png)

For completeness, the deformed shape and stress contour for the remaining flight cases are reproduced below.

![Frame LC1 hover, deformed shape (×100)](figures/frame_LC1_hover_static_deformed.png)

![Frame LC1 hover, von Mises stress](figures/frame_LC1_hover_static_stress.png)

![Frame LC3 cruise, deformed shape (×100)](figures/frame_LC3_cruise_deformed.png)

![Frame LC3 cruise, von Mises stress](figures/frame_LC3_cruise_stress.png)

![Frame LC4 motor out, deformed shape (×100)](figures/frame_LC4_motor_out_deformed.png)

![Frame LC4 motor out, von Mises stress](figures/frame_LC4_motor_out_stress.png)

### 6.4 Landing gear discussion

The landing gear analysis returns a peak von Mises of 1881 MPa, which exceeds the 7075-T6 yield strength by a factor of 3.7 and gives an RF of 0.27. This is unambiguous: the gear strut, as parameterized in [src/aircraft_parameters.m](../src/aircraft_parameters.m), would not survive the modeled 3g landing with 0.5g forward inertia.

The driver of the failure can be traced from the geometry in [src/build_landing_gear.m](../src/build_landing_gear.m). Each main attachment is at [3.2, ±0.6, 0.85] m and the corresponding contact is at [3.2, ±1.2, 0] m. The strut therefore carries a horizontal offset of 0.6 m between the attachment and the contact. The vertical landing load at each main attachment is 0.45 · 3 · MTOW · g = 42,030 N, applied downward at the attachment. With the contact clamped, this load develops a bending moment at the contact end of order 42,030 N × 0.6 m ≈ 25 kN·m. For the 60 mm OD, 5 mm wall strut with I_z ≈ 3.30e5 mm⁴ and outer fiber c = 30 mm, the resulting bending stress is on the order of 2.3 GPa, consistent with the 1.88 GPa observed in the FEA (which spreads the bending across the strut length and adds the axial and drag contributions). The peak disp of 289 mm is similarly large because the small section is very compliant for the moment arm.

The conclusion is that the as-specified strut section is undersized for the modeled landing condition by a large margin. Realistic remedies include (i) increasing the strut OD substantially, since I grows as OD^4 and σ falls as OD^{-3}, (ii) replacing the rigid-strut topology with a trailing arm and oleo, where the contact is closer to the load line and energy absorption reduces the static-equivalent factor, or (iii) including the tire compliance and the actual horizontal load path through the brakes rather than as an attachment-side inertia.

![Landing gear deformed shape (×50)](figures/landing_gear_deformed.png)

![Landing gear, von Mises stress](figures/landing_gear_stress.png)

## 7. Verification

Two unit tests in [tests/](../tests/) cover the implementation:

- [tests/test_beam_cantilever.m](../tests/test_beam_cantilever.m) applies a 1 kN tip load to a 5-element cantilever beam (1 m, solid 20 mm circular section, steel) and compares the tip deflection against the closed-form Euler-Bernoulli result δ = P L³ / (3 E I). The FEA tip deflection on the reference run is 2.122066e-01 m; the analytical value is 2.122066e-01 m; the relative error is **1.05e-13**. The test passes well below its 1e-6 threshold.
- [tests/test_assembly.m](../tests/test_assembly.m) verifies the assembled frame stiffness matrix is symmetric and has the expected rigid-body content. On the reference run the maximum asymmetry max |K - K^T| is **1.86e-09** (essentially numerical noise), the number of near-zero eigenvalues is exactly **6** (the 3D rigid-body translation and rotation modes, as expected), and the first non-zero eigenvalue is **3.30e+04**, comfortably separated from the rigid-body modes. The test passes.

Both verification residuals are at the level of double-precision round-off, which is the expected outcome for a correctly assembled linear stiffness matrix with consistent shape functions.

## 8. Limitations

The analysis carries several explicit limitations that an industry-strength sizing study would have to remove:

- **Beam idealization.** Skin panels, spar caps, bulkheads, fasteners, cutouts, and joint flexibility are not modeled. The boom section in this model is an equivalent wing-plus-boom stiffness, not a physical tube.
- **Linear static only.** No vibration, no impact dynamics, no aerodynamic flutter, no thermal loads from battery or motor bays.
- **No local buckling.** A composite hollow tube under compression-bending can fail by local crippling at a stress well below the material allowable. A shell model with composite ply definitions would catch this.
- **No joint stress concentration.** All connections are perfectly rigid in the beam model; real bolted, bonded, and co-cured joints concentrate stress and may govern over the section stress.
- **No composite ply failure analysis.** Tsai-Wu and Hashin failure criteria are not applied. The CFRP allowable is a single scalar.
- **Landing gear quasi-static.** The 3g vertical factor is a static surrogate for a dynamic energy-absorption problem. No tire compliance, no oleo, no brake transient dynamics.
- **Geometry is approximate.** Boom locations, fuselage length, and landing gear dimensions are public-domain estimates based on Archer renderings and FAA filings. No proprietary geometry is used.

## 9. Future work

Logical extensions, in order of value:

1. **Resize the landing gear strut** and rerun, closing the RF 0.27 gap. A 100 mm OD, 8 mm wall strut would lift I by an order of magnitude and bring the stress into a defensible range.
2. **Modal analysis** of the airframe to identify natural frequencies relative to rotor RPM ranges, avoiding resonance at hover and cruise rotor speeds.
3. **Drop test dynamics** of the landing gear at the FAR 23.473 sink rate (typical 2.6 m/s for utility category), with explicit time integration to capture peak transient loads versus the static 3g approximation.
4. **Composite ply failure analysis** using Tsai-Wu or Hashin on the boom layup.
5. **Parametric sweep** over boom OD, wall thickness, and strut geometry to map the design space against RF and mass.
6. **Ansys or Nastran cross-verification** of the beam results, then a shell-element follow-on for the wing-to-fuselage joint and the highest-stress strut region.

## 10. References

1. Cook, R. D., Malkus, D. S., Plesha, M. E., Witt, R. J., *Concepts and Applications of Finite Element Analysis*, 4th ed., John Wiley & Sons, 2002.
2. Bathe, K.-J., *Finite Element Procedures*, 2nd ed., Klaus-Jürgen Bathe, 2014.
3. Logan, D. L., *A First Course in the Finite Element Method*, 6th ed., Cengage Learning, 2017.
4. Jones, R. M., *Mechanics of Composite Materials*, 2nd ed., Taylor & Francis, 1999.
5. FAA, *Title 14 CFR Part 23, Airworthiness Standards: Normal Category Airplanes*, current edition, sections 23.305 and 23.473.
6. Archer Aviation Inc., public Type Certification status updates and press materials, 2024 to 2026.

## 11. Reproducibility

The full analysis is reproduced from a clean checkout by:

```bash
cd archer-midnight-fea/src
matlab -batch "main"
```

All figures in [docs/figures/](figures/) and the summary in [data/results_summary.csv](../data/results_summary.csv) are deterministic given the parameters in [src/aircraft_parameters.m](../src/aircraft_parameters.m) and [src/material_properties.m](../src/material_properties.m). Modifying these files and rerunning regenerates every output.
