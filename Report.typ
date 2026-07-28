#import "@preview/arkheion:0.1.2": arkheion, arkheion-appendices

#show: arkheion.with(
  title: "A Tutorial on the Design and Simulation of Superconducting Quantum Devices using Keysight ADS QuantumPro",
  authors: (
    (name: "Richard Ho", email: "rqho@umich.edu", affiliation: "University of Michigan"),
  ),
  abstract: [This tutorial is a practical guide for researchers designing and simulating superconducting quantum devices in Keysight ADS QuantumPro. Starting from the circuit-QED design cycle, we cover technology setup and layout construction with the Quantum Artwork library, CPW resonator sizing from the technology stackup, full-wave electromagnetic simulation (Method of Moments and Finite Element Method), S-parameter interpretation, energy-participation (EPR) analysis, and quantum-parameter extraction (anharmonicity, dispersive shift, and cross-Kerr). A flip-chip worked example illustrates multilayer technology setup, chip-to-chip coupling, and bump stitching. The material synthesizes concepts and workflows from Keysight QuantumPro application notes and is intended as filler guidance that can be adapted to laboratory-specific process design kits.],
  keywords: ("superconducting qubits", "QuantumPro", "ADS", "transmon", "CPW resonators", "EPR", "flip-chip"),
  date: "August 15, 2026",
)

= Introduction

Superconducting qubits operate as artificial atoms at milli-kelvin temperatures and gigahertz microwave frequencies. The essential nonlinear element is the Josephson junction: two superconducting electrodes separated by a thin insulator. In the low-excitation (quantum) regime the junction behaves as a nonlinear inductor that, together with shunt capacitance, yields anharmonic energy levels suitable for isolating a computational two-level system.

A typical chip comprises a network of qubits (often cross-shaped or pocket transmons) and coplanar-waveguide (CPW) resonators used for dispersive readout and for mediating qubit--qubit coupling. When the qubit--resonator detuning $Delta$ is large compared with the coupling strength $g$, the system is in the _dispersive regime_: the resonator frequency shifts by an amount set by the qubit state, enabling readout without destroying the computational subspace.

The PathWave ADS / QuantumPro design cycle is iterative:

+ Build a schematic from parametric Quantum Artwork cells and generate the synchronized layout.
+ Assign a Quantum technology stackup (single-layer or multilayer / flip-chip) and place ports across junctions and launchpads.
+ Run a linear electromagnetic (EM) analysis in which Josephson junctions are replaced by abstract lumped inductances expected at ultra-low drive.
+ Extract classical S-parameters and quantum figures of merit (anharmonicity, cross-Kerr / dispersive shift).
+ Retune geometry or junction inductance until modes are resolved and target parameters are met; export GDS for fabrication.

Planar circuits benefit from Method-of-Moments (MoM) solvers that solve for surface currents rather than volumetric fields, reducing cost for large chips. Finite-element (FEM) eigenmode analysis remains the gold standard for energy-participation quantization when a full Kerr matrix is required.

This tutorial walks through each stage with the equations and tables a new QuantumPro user needs to size devices, set up simulations, and interpret extracted quantum parameters.

= Layout Design

== Defining Layers

After creating a workspace, select a Quantum technology library. In recent ADS releases this appears as *Quantum Technology Library* with options such as *Single-Layer*, *Multi-Layer* (flip-chip), and *Coaxmon*. Completing the technology wizard creates a `tech:subst` stackup under the workspace.

A representative single-layer stackup for cryogenic aluminum-on-silicon designs is summarized in @tbl:layers. Conductors are often treated as perfect electric conductors (PEC) to mimic superconducting metals at millikelvin temperatures; silicon is assigned a cryogenic permittivity $epsilon_r approx 11.5$ and a very small loss tangent (e.g. $10^(-5)$).

#figure(
  table(
    columns: (auto, auto, auto, auto),
    align: (left, left, left, left),
    inset: 6pt,
    stroke: 0.5pt,
    [*Layer*], [*Role*], [*Typical material*], [*Notes*],
    [Boundary], [Chip outline / outer ground extent], [---], [Rectangle enclosing all artwork],
    [Conductor (`cond`)], [Signal metal: CPW centers, qubit islands, pads], [Al / Nb (PEC in EM)], [Primary signal layer],
    [Keep-out], [Gap between conductor and ground fill], [---], [Sets CPW gap / island clearance],
    [Ground-fill], [Ground plane between boundary and keep-out], [Al / Nb (PEC)], [Return path for CPW modes],
    [Airbridge conductor / via], [Ground stitching over CPW centers], [Metal + via], [Suppresses unwanted slotline / odd mode],
    [Inductor (abstract)], [Placeholder for Josephson junction], [Lumped LC], [Simulation / layout placeholder; not fabricated],
    [Air / dielectric], [Overburden and substrate], [Air, Si, etc.], [Edited in stackup / CILD],
  ),
  caption: [Common Quantum technology layers used when exporting layouts and GDS blueprints.],
) <tbl:layers>

Open `tech:subst` to edit thicknesses and material assignments. For CPW impedance and resonator sizing, use the *Controlled Impedance Line Designer* (CILD) from the technology tools menu (the "$Z=50$" icon). Configure a coplanar single-ended line (e.g. Top Plane `<None>`, Signal `cond`, Bottom Plane `<None>` for an open air-backed CPW) and set width $W$ and clearance (gap) $g$.

Running CILD reports transmission-line properties and the per-unit-length RGLC parameters. For a cryogenic silicon CPW with $(g, W, g) = (9, 15, 9)~mu m$ at $~10~$GHz, a typical result is

$ Z_0 approx 50.5 Omega, quad epsilon_"eff" approx 6.15, quad L' approx 418 "nH"/m, quad C' approx 164 "pF"/m. $

These numbers feed resonator length calculations (@eq:l-quarter) before any full-wave run.

== Creating Components

QuantumPro ships a parametric Quantum Artwork library. Core cells used in planar chips include:

#figure(
  table(
    columns: (auto, auto),
    align: (left, left),
    inset: 6pt,
    stroke: 0.5pt,
    [*Cell*], [*Typical use*],
    [`Q_TransmonCross` / `Q_TransmonPocket`], [Transmon qubit islands],
    [`Q_CpwLine`, `Q_CpwMeander`, `Q_CpwCurvedBend`], [Feedlines, buses, readout resonators],
    [`Q_CpwCouplerT`], [Capacitive tee coupler to a feedline],
    [`Q_CpwLaunchpadWirebond`], [Wirebond pads / EM excitation ports],
    [`Q_CpwLineOpen`], [Open stub termination],
    [`Q_InductorAbstract`], [Lumped JJ model for linear EM / quantum extraction],
    [`Q_CapacitorNInterdigital`], [Feed coupling capacitors],
    [`Q_Bump` (multilayer)], [Signal transition between chips],
  ),
  caption: [Selected Quantum Artwork components for superconducting circuit layout.],
) <tbl:components>

In the schematic, set orientation, length, width, gap, and connector options; the layout regenerates automatically. Meander resonators (`Q_CpwMeander`) preserve user-defined start/end offsets while adjusting meander count to meet a target electrical length. CPW cells can include periodic airbridges that short the coplanar grounds across the center conductor, suppressing the antisymmetric "odd" mode that degrades coherence and readout contrast.

*Josephson junctions in layout.* For EM, place pins across the qubit gap and insert `Q_InductorAbstract` with inductance $L_J$ (and optional junction capacitance $C_J$). Fabrication GDS typically keeps a dedicated inductor layer as a *placeholder* for the real junction process; that layer is not metalized in the foundry mask set.

*Sizing a quarter-wave readout resonator.* With effective permittivity from CILD, the physical length of an open (or shorted) quarter-wave resonator targeting frequency $f$ is

$ ell = lambda / 4 = c / (4 f sqrt(epsilon_"eff")), $<eq:l-quarter>

where $c$ is the vacuum speed of light. For $f = 6~$GHz and $epsilon_"eff" = 6.1453$,

$ ell = (3 times 10^8) / (4 times 6 times 10^9 sqrt(6.1453)) approx 5042~mu m. $

Total distributed capacitance and inductance follow as $C_"tot" = C' ell$ and $L_"tot" = L' ell$. Consistency check using the distributed resonance condition:

$ f = 1 / (4 sqrt(C_"tot" L_"tot")). $<eq:f-dist>

*Caveat on lumped formulas.* The familiar $f = 1/(2 pi sqrt(L_"res" C_"res"))$ applies to an *equivalent lumped* RLC model near resonance, not to the raw distributed totals. Equating the shorted quarter-wave input impedance to a parallel RLC near $omega_0$ yields @eq:cres and @eq:lres:

$ C_"res" = pi / (4 omega_0 Z_0) = C_"tot" / 2, $<eq:cres>

$ L_"res" = 1 / (omega_0^2 C_"res") = (8 / pi^2) L_"tot". $<eq:lres>

Use these equivalents when mapping a CPW resonator onto a lumped black-box model.

= Electromagnetic Simulation

Because the Josephson junction is strongly nonlinear, QuantumPro's linear EM flow replaces it with the small-signal inductance expected in the quantum (ultra-low power) regime. Enabling vs.\ disabling this inductance corresponds to the quantum ground-state vs.\ classical high-power regimes: resonator peaks shift slightly when the qubit is "turned on," and that shift is the dispersive information used for parameter extraction.

== Simulation Setup

A minimal setup for a feedline-coupled qubit--resonator circuit is:

+ *Ports.* Place input/output ports on launchpads (signal to ground). Place a lumped port across each qubit junction where `Q_InductorAbstract` attaches.
+ *Frequency span.* Sweep a band that covers all qubit and resonator modes (often $4$--$10~$GHz for GHz-class devices). Add dense local sweeps near expected resonances when quality factors are high.
+ *Solver choice.* Momentum RF (quasi-static Green functions) for fast early design; Momentum Microwave or FEM for higher accuracy at microwave frequencies; FEM eigenmode for Energy Participation Analysis.
+ *Mesh.* Increase cells-per-wavelength (cpw) globally and refine near qubit islands and junction ports. Keep ground planes coarser. Example starting point for MoM: $100$--$200~$cpw globally, $1000$--$2000~$cpw near qubit ports; for FEM EPR, $~5~mu m$ edge length on center conductors and islands.
+ *Materials.* Confirm cryogenic $epsilon_r$, loss tangent, and PEC conductors in the stackup.

@tbl:solvers compares the QuantumPro analysis paths.

#figure(
  table(
    columns: (auto, auto, auto, auto),
    align: (left, left, left, left),
    inset: 6pt,
    stroke: 0.5pt,
    [*Analysis*], [*Solver*], [*Primary outputs*], [*Best for*],
    [Full EM (QS)], [Momentum RF], [S-parameters, $C(f)$, $chi$ for neighbors], [Fast iteration],
    [Full EM (FD)], [Momentum Microwave / FEM], [S-parameters, dressed modes], [High-frequency accuracy],
    [Energy Participation], [FEM eigenmode], [Eigenfrequencies, $Q$, $T_1$, full $chi$ matrix], [Complete Kerr matrix, highest fidelity],
  ),
  caption: [QuantumPro analysis mes for superconducting circuits.],
) <tbl:solvers>

== Finite Element Method

The FEM discretizes Maxwell's equations over a volumetric mesh (tetrahedra / hexahedra) subject to the boundary conditions of the computational domain. Relative to MoM---which solves integral equations for surface currents on conductors---FEM:

- Captures full three-dimensional field structure, including substrate modes, chip-to-chip cavities, and radiation into air boxes.
- Supports *eigenmode* solutions: natural frequencies $omega_m$, quality factors $Q_m$, and modal field patterns without a driven port sweep.
- Scales with the number of volumetric unknowns and is typically more expensive than MoM for large planar chips.

In QuantumPro, FEM is the engine behind Energy Participation Analysis. Meshing strategy remains decisive: refine conductors that store electric energy at qubit frequencies (charge islands, CPW centers, coupling pads) while coarsening bulk ground and distant air regions. For flip-chip devices, also refine bump interfaces and overlapping coupling patches.

MoM and FEM frequency predictions for the same geometry often agree within a few percent; MoM can slightly underestimate capacitance (hence slightly higher resonant frequencies) unless islands are finely meshed.

== S-Parameters

Driven Full EM Analysis returns the scattering matrix $bold(S)(omega)$ among defined ports. For a two-port feedline, the transmission $S_21$ shows peaks (or dips, depending on coupling topology) at resonator and, when junction inductances are present, qubit resonances. Design goals typically include:

- Distinct, well-separated peaks for every qubit and every readout / bus resonator.
- Target frequencies for each mode (set by $L_J$, island capacitance, and resonator length).
- Adequate coupling for readout without excessive Purcell decay.

Admittance at a qubit port is obtained from the port S-parameters. Resonance of qubit $n$ (with junction inductance $L_(j,q n)$ and optional $C_(j,q n)$) is located by the zeros of @eq:fPn:

$ f_(P n')(omega) = Im[Y_(P n' P n')(omega)] - 1/(omega L_(j,q n)) + omega C_(j,q n), $<eq:fPn>

where $Y_(P n' P n')$ is the admittance seen at the junction port *without* the junction LC. The function $Im[Y]$ alone zeros at the *classical* (high-power) resonator frequencies $omega_r$; including the junction LC moves those zeros to the *dressed* frequencies $omega_r'$. The difference is the dispersive shift

$ "D.S." = g^2 / Delta. $<eq:ds>

In continuous-wave cryogenic measurements the same classical vs.\ dressed spectra appear when the drive power is swept from high to low on a network analyzer.

== Boundary Conditions

Correct boundary conditions are as important as mesh density:

- *PEC conductors.* Superconducting films are commonly modeled as perfect conductors in the linear EM flow (optionally with kinetic inductance via specialized stackup examples).
- *Ground stitching.* Airbridges and, in flip-chip, bump arrays connect coplanar grounds so that the desired CPW even mode is enforced.
- *Radiation / absorbing boundaries.* FEM domains require a finite air box; absorbing or radiation boundaries prevent artificial cavity modes from contaminating the spectrum.
- *Symmetry and chip outline.* The boundary layer defines the extent of the ground plane; incomplete grounds create spurious slotline modes.
- *Port calibration.* Lumped ports across junctions must span the gap cleanly; launchpad ports should reference the local ground.

When peaks fail to resolve, first check for overlapping modes of *like* elements (qubit--qubit or resonator--resonator), incomplete grounds, missing airbridges, and under-resolved meshes near islands---before changing target frequencies.

== Energy Participation Analysis

Energy Participation Ratio (EPR) quantization starts from modal field solutions. For any resonant mode the time-averaged inductive and capacitive energies are equal. In a Josephson circuit the inductive energy includes kinetic inductance of the junctions:

$ E_"ind" = E_"cap" = E_"elec" = E_"mag" + E_"kin". $<eq:e-balance>

The participation of junction $j$ in mode $m$ is

$ p_(m j) = E_"kin"^((m,j)) / E_"ind"^((m)) = (E_"elec"^((m)) - E_"mag"^((m))) / E_"elec"^((m)), $<eq:epr>

or, equivalently from junction current,

$ p_(m j) = (1/2) L_j I_(m,j)^2 \/ E_"ind"^((m)). $<eq:epr-I>

QuantumPro obtains $I_(m,j)$ from the line integral of the electric field across the junction path (voltage drop) divided by $j omega L_j$.

The Kerr matrix elements follow from the participations and junction energies $E_j = Phi_0^2 / (4 pi^2 L_j)$:

$ chi_(m n) = sum_(j=1)^J (planck omega_m omega_n)/(4 E_j) thin p_(m j) p_(n j) quad (m != n), $<eq:chi-mn>

$ alpha_(q\/r) = chi_(m m) = sum_(j=1)^J (planck omega_m^2)/(8 E_j) thin p_(m j)^2. $<eq:alpha-epr>

Unlike frequency-domain Full EM extraction---which typically returns cross-Kerr only between *directly coupled* neighbors---EPR yields a dense $chi$ matrix including weak couplings between non-adjacent modes (often kilohertz-scale). Eigenmode results also report quality factors and photon lifetimes $T_1$ for each mode.

== Quantum Parameter Extraction

*Anharmonicity from capacitance.* For a transmon, the lowest transition frequencies are

$ omega_01 = sqrt(8 E_J E_C) - E_C, quad omega_12 = sqrt(8 E_J E_C) - 2 E_C, $

so the anharmonicity is

$ alpha = omega_12 - omega_01 = - E_C, quad E_C = e^2 / (2 C), $<eq:alpha-ec>

with $C$ the total capacitance seen from the qubit port at resonance (extractable from the port reflection / capacitance vs.\ frequency in the quasi-static solution). Example: $C approx 61.5~$fF yields $alpha approx 315~$MHz.

*Cross-Kerr in the dispersive regime.* Between a qubit and a resonator,

$ chi_(q r) = (2 g^2 alpha_q) / (Delta (Delta + alpha_q)), $<eq:chi-disp>

with detuning $Delta = omega_q - omega_r$ (sign convention as in the design notes). Full EM analysis also constructs resonator anharmonicity $alpha_r$ from effective $L_r$, $C_r$ seen at the qubit port, then forms

$ chi_(q r) = 2 sqrt(alpha_q alpha_r) $<eq:chi-sqrt>

with

$ C_r = 1/2 thin f'_(P n)(omega_r), quad L_r = 1 / (omega_r^2 C_r). $<eq:cr-lr>

@tbl:qparams-1q and @tbl:qparams-4q reproduce representative QuantumPro comparisons from Keysight application notes (illustrative reference values for mesh and geometry in those examples).

#figure(
  table(
    columns: (auto, auto, auto, auto, auto, auto),
    align: center,
    inset: 5pt,
    stroke: 0.5pt,
    [*Qty*], [*QS*], [*FD*], [*EPR*], [*Unit*], [*Notes*],
    [$C_(Q 1)$], [61.53], [61.53], [---], [fF], [From port capacitance],
    [$alpha_(Q 1)$], [314.82], [314.84], [298.80], [MHz], [Within $~5%$],
    [$chi_(Q 1 R 1)$], [2.14], [2.14], [2.02], [MHz], [Neighbor coupling],
    [$alpha_(R 1)$], [3.62], [3.63], [3.43], [kHz], [Resonator self-Kerr],
  ),
  caption: [One-qubit / one-resonator extraction comparison (Momentum RF quasi-static, Momentum Microwave frequency-domain, FEM EPR). Values adapted from Keysight Quantum Parameter Extraction notes.],
) <tbl:qparams-1q>

#figure(
  table(
    columns: (auto, auto, auto, auto),
    align: (left, center, center, center),
    inset: 5pt,
    stroke: 0.5pt,
    [*Coupling*], [$chi$ QS (MHz)], [$chi$ FD (MHz)], [$chi$ EPR (MHz)],
    [$chi_(Q 1 R 2)$], [1.70], [1.71], [1.62],
    [$chi_(Q 1 R 4)$], [1.22], [1.23], [1.09],
    [$chi_(Q 2 R 1)$], [2.06], [2.07], [1.87],
    [$chi_(Q 2 R 4)$], [1.42], [1.43], [1.23],
    [$chi_(Q 3 R 2)$], [2.26], [2.27], [1.82],
    [$chi_(Q 3 R 3)$], [1.69], [1.70], [1.39],
    [$chi_(Q 4 R 1)$], [2.97], [2.99], [2.42],
    [$chi_(Q 4 R 3)$], [1.80], [1.80], [1.51],
  ),
  caption: [Four-qubit / four-resonator neighbor cross-Kerr strengths across solvers. EPR additionally reports non-adjacent couplings (e.g. $chi_(Q 1 R 3) ~ 1.2~$kHz) absent from Full EM tables.],
) <tbl:qparams-4q>

*Practical tuning knobs.*

- Increase (decrease) $L_J$ to lower (raise) qubit frequency: $omega_0 ~ 1\/sqrt(L C)$.
- Lengthen (shorten) CPW resonators to lower (raise) $f_r$.
- Adjust coupler geometry (`SecondParallelLength`, claw length, overlap area) to set $g$ and thus $chi$.

== Time Dynamics Analysis

Frequency-domain and eigenmode extractions characterize the linearized circuit near the vacuum / few-photon regime. Time-domain and nonlinear circuit analyses complement that picture when researchers need drive-dependent dynamics:

- *Dispersive readout waveforms.* With extracted $chi$ and resonator $kappa$, classical IQ trajectories under a readout pulse can be simulated in a circuit or system-level tool using the effective Hamiltonian $H\/planck = omega_r a^dagger a + (1\/2) omega_q sigma_z + chi a^dagger a thin sigma_z$.
- *Harmonic balance / transient with JJ models.* ADS circuit simulation (outside the linear EM quantum-parameter flow) can include nonlinear Josephson elements (`JJ2`, `JJ3`) for large-signal behavior, Rabi driving, and higher-level leakage estimates---subject to the usual caveats that full open-system master equations are often handled in dedicated quantum dynamics packages.
- *Ring-down and $T_1$.* Eigenmode quality factors from EPR map to photon lifetimes $T_1 approx Q \/ omega$; comparing simulated $Q$ against measured ring-down validates loss models (dielectric participation, seam loss, package modes).
- *Power-dependent spectra.* Sweeping drive amplitude in measurement (or in a nonlinear model) recovers the classical $arrow.r$ quantum transition used to identify dressed resonator peaks---the experimental counterpart of enabling `Q_InductorAbstract` in Full EM Analysis.

A recommended workflow is: (1) converge geometry and $chi$ matrix in QuantumPro, (2) export black-box parameters into a dynamics model for gate / readout pulse design, (3) close the loop with cryogenic S-parameter and time-domain measurements.

= Flip-Chip Design Example

Routing congestion grows quickly with qubit count. Flip-chip (face-to-face) integration places circuitry on two chips separated by a few micrometers of vacuum / helium, connected by superconducting bumps. QuantumPro supports this via *Quantum Multi-Layer* technology (two layer sets, one flipped).

*Technology setup (sketch).* Choose two stacks; set substrate thickness (e.g. $280~mu m$ Si), metal thickness (often $0~$ for PEC sheets), airbridge dielectric height (e.g. $1~mu m$), and inter-chip *Top Dielectric* air gap (e.g. $6~mu m$). With $1~mu m$ airbridges on each side and $6~mu m$ gap, the conductor-to-conductor spacing is $~8~mu m$. Define vias / bumps that galvanically stitch grounds (and optionally signal lines).

*Two CPW environments.*

- *Type A --- metal facing metal:* Top Plane `2_cond`, Signal `cond`. Fields partially divert into the inter-chip air gap $arrow.r$ lower $epsilon_"eff"$, longer resonators, strong sensitivity to gap height via image return currents.
- *Type B --- metal facing dielectric:* Top Plane `<None>`. Inductance is more stable vs.\ gap; capacitance still varies as fields penetrate the opposite silicon.

For Type A with $(g,W,g)=(12,12,12)~mu m$ at $6~$GHz, CILD may report $Z_0 approx 47~Omega$, $epsilon_"eff" approx 4.55$, $L' approx 335~$nH/m, $C' approx 151~$pF/m, giving

$ ell_(lambda\/4) = c / (4 f sqrt(epsilon_"eff")) approx 5859~mu m $<eq:flip-ell>

--- roughly $17%$ longer than a comparable single-chip resonator with $epsilon_"eff" ~ 6.2$, consistent with $ell_"flip" \/ ell_"single" = sqrt(epsilon_"eff,single" \/ epsilon_"eff,flip")$.

*Ballpark Xmon capacitance.* Approximating four CPW arms of length $ell_"arm"$ as

$ C_"qubit" approx 4 ell_"arm" C' $<eq:cq-approx>

with $ell_"arm" = 165~mu m$ and $C' = 151.2~$pF/m yields $C_"qubit" approx 100~$fF and $E_C \/ h approx e^2 \/ (2 h C) approx 194~$MHz---an underestimate that ignores corner fringing and the central pad, but useful before FEM.

*Layout recipe (single qubit + readout).*

+ Place feedline, `Q_CpwCouplerT`, and meander resonator on stack 1 (bottom).
+ Place `Q_TransmonCross` and `Q_InductorAbstract` on stack 2 by setting `LayerGroupPrefix` to `"2_"`.
+ In layout, extend the resonator with `cond` / `keepout` paths and an overlap pad (e.g. concentric circles) under the cross to set coupling capacitance.
+ Draw `boundary` and `2_boundary` ground outlines; stitch grounds with `Bump_1_2` circles (do *not* use `Q_Bump` for ground stitching---`Q_Bump` is for CPW signal transitions and includes keep-out).
+ Open QuantumPro, verify Z-exaggerated geometry, refine mesh on `cond`, `2_cond`, and bumps, and run Full EM and/or EPR.

*Illustrative extracted numbers* (Momentum Microwave vs.\ FEM EPR on a tutorial geometry) appear in @tbl:flip-results. From EPR anharmonicity one recovers

$ C_"qubit" = e^2 / (2 E_C), $<eq:c-from-ec>

and from cross-Kerr

$ chi = (g^2 E_C) / (Delta (Delta - E_C)) $<eq:chi-g>

one solves for $g$, then for the geometric coupling capacitance $C_g$ via the standard capacitive-coupling formula linking $g$ to $C_g$, $C_"qubit"$, and $C_"res"$ (with $C_"res" = C_"tot"\/2$ for a quarter-wave resonator).

#figure(
  table(
    columns: (auto, auto, auto),
    align: (left, center, center),
    inset: 6pt,
    stroke: 0.5pt,
    [*Quantity*], [*Full EM (MoM)*], [*EPR (FEM)*],
    [Qubit frequency], [$~4.55~$GHz], [$~4.37~$GHz],
    [Resonator frequency], [$~7.1~$GHz], [$~7.36~$GHz],
    [Qubit anharmonicity $E_C\/h$], [(from $chi$ table)], [$~159~$MHz],
    [Cross-Kerr $chi$], [(from $S$-param extract)], [$~0.17~$MHz],
    [Implied $C_"qubit"$], [---], [$~122~$fF],
    [Implied $g$], [---], [$~96~$MHz],
  ),
  caption: [Order-of-magnitude flip-chip qubit--resonator results from a QuantumPro tutorial geometry (values adapted from Keysight flip-chip application notes). Mesh refinement reduces MoM--FEM discrepancies.],
) <tbl:flip-results>

*Design warning.* Image currents on a metal plane above a meander track the resonator shape and *reduce* $L'$, shifting $f_r$ when the chip gap varies. Mitigation strategies include facing resonators toward dielectric (Type B), etching apertures in the opposite ground to break return paths, or lithographic interruption of image-current loops.

= Conclusion

Keysight ADS QuantumPro provides an end-to-end path from parametric superconducting layouts to fabrication GDS and to quantum figures of merit extracted from linear EM. Researchers should: size CPWs and resonators with CILD against the real stackup; enforce clean grounds and airbridges; choose MoM for rapid Full EM iteration and FEM EPR when a complete Kerr matrix or highest accuracy is required; and treat flip-chip gap sensitivity as a first-class design constraint. The equations and tables above are intended as working filler content---replace numerical examples with your process parameters and close the loop against cryogenic measurements.

#show: arkheion-appendices

= References and further reading

This tutorial synthesizes publicly documented Keysight QuantumPro application-note material and standard circuit-QED references. Consult the ADS Help tree under *Applications → Quantum* for the latest demos and PDFs shipped with your install.

+ P. Krantz et al., "A quantum engineer's guide to superconducting qubits," _Appl. Phys. Rev._ *6*, 021318 (2019).

+ J. Koch et al., "Charge-insensitive qubit design derived from the Cooper pair box," _Phys. Rev. A_ *76*, 042319 (2007).

+ A. Blais et al., "Cavity quantum electrodynamics for superconducting electrical circuits," _Phys. Rev. A_ *69*, 062320 (2004).

+ S. E. Nigg et al., "Black-box superconducting circuit quantization," _Phys. Rev. Lett._ *108*, 240502 (2012).

+ Z. K. Minev et al., "Energy-participation quantization of Josephson circuits," _npj Quantum Inf._ *7*, 131 (2021).

+ D. M. Pozar, _Microwave Engineering_, 4th ed., Wiley (2011).

+ M. Göppl et al., "Coplanar waveguide resonators for circuit quantum electrodynamics," _J. Appl. Phys._ *104*, 113904 (2008).

+ Keysight Technologies, "Designing for Superconducting Qubit Circuits," Appl. Note 3123-1286.EN (2023).

+ Keysight Technologies, "Quantum Parameter Extraction in QuantumPro," Appl. Note 3123-1662.EN (2023).

+ Keysight Technologies, "Calculation of CPW Resonator Properties Using the Quantum Technology File," Appl. Note 3125-1332.EN (2025).

+ Keysight Technologies, "Design of Transmon Qubit and CPW Resonator in Flip-Chip Technology with ADS, Quantum Pro," Appl. Note 3125-1427.EN (2025).

+ H.-X. Li et al., "Experimentally verified, fast analytic, and numerical design of superconducting resonators in flip-chip architectures," _IEEE Trans. Quantum Eng._ *4*, 1--12 (2023).
