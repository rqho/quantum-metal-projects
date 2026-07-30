#import "@preview/arkheion:0.1.2": arkheion, arkheion-appendices

#show: arkheion.with(
  title: "A Tutorial on the Design and Simulation of Superconducting Quantum Devices using Keysight ADS QuantumPro",
  authors: (
    (name: "Richard Ho", email: "rqho@umich.edu", affiliation: "University of Michigan"),
  ),
  abstract: [This tutorial outlines the end-to-end design and simulation workflow for a flip-chip superconducting quantum device using Keysight PathWave ADS and QuantumPro. It covers the creation of the parametric layout, setting up the 3D electromagnetic environment, extracting critical quantum parameters using Energy Participation Ratio (EPR) analysis, and preparing the design for fabrication. The primary device under test features transmon qubits coupled to coplanar waveguide (CPW) readout resonators in a multi-layer flip-chip architecture.],

  date: "August 15, 2026",
)

#set par(justify: false)
#set heading(numbering: none)

= Introduction

- Motivation: why this device / process matter
- Brief circuit-QED context (qubit + readout resonator)
- Software stack: PathWave ADS + QuantumPro
- Design cycle overview:
  + Schematic / Quantum Artwork layout
  + Technology stackup + ports
  + Linear EM (JJ $arrow.r$ abstract $L_J$)
  + Extract S-parameters / quantum parameters
  + Iterate geometry; export GDS
- Scope of this walkthrough (what you will build and simulate)
- Roadmap of remaining sections

= Device Targets

- Chip / process assumptions (substrate, metal, temperature)
- Target qubit frequency, anharmonicity $alpha$, $T_1$ goals
- Target resonator frequency, $kappa$, dispersive shift $chi$
- Coupling targets ($g$, nearest-neighbor if multi-qubit)
- Topology choice (planar single-layer vs flip-chip; Xmon vs pocket; etc.)

= Layout Design

== Defining Layers

- Create workspace; select Quantum Technology Library (Single-Layer / Multi-Layer)
- Open `tech:subst`: thicknesses, $epsilon_r$, loss tangent, PEC conductors
- Layer roles to document (fill table or bullets as you go):
  + `boundary`
  + `conductor` / `cond`
  + `keepout`
  + ground fill
  + airbridge
  + inductor (JJ placeholder)
  + air / dielectric
- Choose CPW $W$, $g$ for ~$50~Omega$; note $Z_0$, $epsilon_"eff"$, $L'$, $C'$
- Figure / screenshot: stackup editor

== Creating Components

- Schematic cells used in this design:
  + Qubit: `Q_TransmonCross` / `Q_TransmonPocket` / ...
  + Resonator / feed: `Q_CpwMeander`, `Q_CpwLine`, `Q_CpwCouplerT`, ...
  + Ports / pads: `Q_CpwLaunchpadWirebond`, ...
  + JJ model: `Q_InductorAbstract` ($L_J$, optional $C_J$)
  + Other: interdigital caps, bumps, ...
- Key geometry parameters set in schematic (orientation, lengths, gaps, claws)
- Airbridges: where placed and why
- Quarter-wave sizing checklist:
  + $ell = c / (4 f sqrt(epsilon_"eff"))$
  + Record target $f$, $epsilon_"eff"$, resulting $ell$
- Layout screenshots (schematic $arrow.r$ generated layout)

= Electromagnetic Simulation

- Why replace JJ with small-signal $L_J$ in linear EM
- Classical (high power / $L_J$ off) vs dressed (quantum / $L_J$ on) spectra

== Simulation Setup

- Ports: launchpad I/O; lumped port at each junction
- Frequency span and local dense sweeps
- Solver choice for this walkthrough (MoM QS / MoM Microwave / FEM)
- Mesh strategy (global cpw; local refine on islands / junctions)
- Materials confirmation checklist
- Figure: port placement / mesh preview

== Full EM and S-Parameters

- What you expect in $S_21$ / $S_11$
- Peak identification: resonators vs qubits
- Classical vs dressed shift $arrow.r$ dispersive information
- Troubleshooting if peaks missing / overlapping:
  + grounds / airbridges
  + mesh
  + mode collision
- Figures: S-parameter plots (annotate modes)

== Energy Participation Analysis (optional / recommended)

- When you use FEM eigenmode + EPR vs Full EM only
- Mesh notes for EPR
- What you extract: $omega_m$, $Q$, $T_1$, participations, $chi$ matrix
- Figures: mode fields / participation summary

== Quantum Parameter Extraction

- Extract / report:
  + $C$ (or $E_C$), anharmonicity $alpha$
  + Detuning $Delta$, coupling $g$, cross-Kerr $chi$
- Compare solvers if you ran more than one (QS / FD / EPR)
- Tuning knobs you actually used:
  + $L_J$ $arrow.r$ qubit frequency
  + resonator length $arrow.r$ $f_r$
  + coupler / claw / overlap $arrow.r$ $g$, $chi$
- Results table (fill with your numbers)

= Example: Single-Qubit Chip

=== Substrate Editor
We use *Single-Layer Technology* in the *Quantum Technology Library* to define the layout technology.
- 750 um Silicon substrate
- 200 nm perfect conductor layer
- 8 um air
- 200 nm air bridges

=== Electromagnetic Simulation
ADS QuantumPro supports two types of electromagnetic analysis methods:
- *Full EM Analysis* does a frequency sweep of the circuit with input and output ports. It returns the S-parameters of the circuit, which can be converted to Y-parameters, Z-parameters, capacitance/inductance matrices, etc. It can use the FEM solver or the MoM solver.
- *Energy Participation Analysis* finds the eigenfrequencies of the system along with electromagnetic field patterns supported by the modes. It only uses the FEM solver.
Types of Solvers:
- *Momentum RF*: a quasi-static solver that uses the method of moments
- *Momentum Microwave*: a full EM solver based on the method of moments suitable for planar structures
- *Finite Element Method*: a full EM solver based on the finite element method suitable for 3D structures

= Example: Multi-Qubit Chip (GDS import)

= Example: Flip-Chip

= Example: SQUIDs and SNAILs



= Conclusion

- What you designed and simulated
- Main quantitative outcomes
- Lessons for the next chip revision

= References

+ TODO: papers and Keysight app notes you relied on
+ P. Krantz et al., "A quantum engineer's guide to superconducting qubits," _Appl. Phys. Rev._ *6*, 021318 (2019).
+ Keysight Technologies, "Designing for Superconducting Qubit Circuits," Appl. Note 3123-1286.EN (2023).
+ Keysight Technologies, "Quantum Parameter Extraction in QuantumPro," Appl. Note 3123-1662.EN (2023).
+ Keysight Technologies, "Design of Transmon Qubit and CPW Resonator in Flip-Chip Technology with ADS, Quantum Pro," Appl. Note 3125-1427.EN (2025).
