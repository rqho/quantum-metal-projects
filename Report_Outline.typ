#import "@preview/arkheion:0.1.2": arkheion, arkheion-appendices

#show: arkheion.with(
  title: "A Tutorial on the Design and Simulation of Superconducting Quantum Devices using Keysight ADS QuantumPro",
  authors: (
    (name: "Richard Ho", email: "rqho@umich.edu", affiliation: "University of Michigan"),
  ),
  abstract: [This tutorial outlines the end-to-end design and simulation workflow for a flip-chip superconducting quantum device using Keysight PathWave ADS and QuantumPro. It covers the creation of the parametric layout, setting up the 3D electromagnetic environment, extracting critical quantum parameters using Energy Participation Ratio (EPR) analysis, and preparing the design for fabrication. The primary device under test features transmon qubits coupled to coplanar waveguide (CPW) readout resonators in a multi-layer flip-chip architecture.],

  date: "August 15, 2026",
)
#set text(
  font: "New Computer Modern",
  size: 12pt
)
#set par(justify: false)
#set heading(numbering: none)

= Introduction

The transition from few-qubit testbeds to scalable quantum processors requires rigorous microwave engineering and tightly controlled electromagnetic environments. In circuit quantum electrodynamics (cQED), components such as transmon qubits and coplanar waveguide (CPW) resonators must be carefully tuned to hit specific target frequencies, anharmonicities, and coupling strengths.

Historically, this required patching together disparate open-source layout scripts, standalone electromagnetic solvers, and custom Python extraction code. Keysight PathWave ADS with QuantumPro provides a unified, all-in-one ecosystem for this workflow. By treating the Josephson Junction (JJ) as a linear lumped inductor, this workflow bridges classical RF/microwave simulation with quantum mechanical parameter extraction via the Energy Participation Ratio (EPR) method. This report details the end-to-end iterative design cycle: from generating the native parametric layout and defining the substrate stack-up, to executing 3D EM simulations, extracting the quantum Hamiltonian, and finally exporting the fabrication-ready GDSII blueprint.

The iterative design and simulation workflow using the PathWave ADS + QuantumPro software stack can be summarized as follows:
1. Define the target device parameters (qubit frequency, anharmonicity, resonator frequency, coupling strengths).
2. Define the substrate and metal stack-up using the Quantum Technology library and the substrate editor.
3. Create the schematic and parametric layout using Quantum Artwork and Quantum Devices components.
4. Set up the electromagnetic simulation environment, including ports, mesh, and solver selection.
5. Run full EM simulations to extract S-parameters, identify resonant modes, and extract quantum parameters.
6. Iterate the design based on simulation results, adjusting geometry and layout to meet target specifications.
7. Export the final design to GDSII for fabrication.

= Layout Design

== Defining Layers

When creating a workspace, the Quantum Technology Library provides a set of predefined layers and materials for superconducting quantum devices. You can select either a single-layer or multi-layer technology, and the substrate editor allows you to define the materials and thicknesses of each layer of the stack-up. The library is stored in `tech:subst`.

A summary of the layer roles and their corresponding materials is provided below:
- boundary: defines the physical extent of the chip and any keepout regions. In the layout editor, the designer can draw a rectangle or polygon to outline the chip.
- conductor: defines the superconducting metal layer, typically made of niobium or aluminum. This layer is used for the qubit pads, resonators, and CPW lines. It is treated as a perfect conductor for simulation.
- keepout: defines regions where no metal or other structures should be placed. This is used to prevent unwanted coupling or interference between components.
- ground fill: defines the ground plane for the CPW structures. This layer is typically connected to the conductor layer and provides a return path for the microwave signals.
- airbridge: defines the locations of airbridges that connect the ground planes across CPW gaps. Airbridges are used to suppress parasitic modes and improve the performance of the CPW structures.
- inductor: defines the location of the Josephson Junction (JJ) or other inductive elements in the circuit. In the layout, this is typically represented as a small rectangle or polygon that connects to the qubit pads.
- air / dielectric: defines the regions of air or dielectric material in the layout. This layer is used to model the electromagnetic environment around the superconducting structures.

- TODO: Figure / screenshot: stackup editor

== Controlled Impedance Line Designer (CILD)

Before drawing your meander resonators or feedlines in the layout environment, you need to determine the physical dimensions (trace width and gap) required to achieve your target characteristic impedance, which is typically 50 $Omega$ for standard microwave components.

- Choose CPW $(g, W, g)$ for ~50 $Omega$; note $Z_0$, $epsilon_"eff"$, $L'$, $C'$


== Creating Components

The ADS schematic and layout view has a library of parametric components for superconducting quantum devices in Quantum Artwork with customizable geometry and material properties. Parametric components include

- qubits: `Q_TransmonCross`, `Q_TransmonPocket`
- resonators: `Q_CpwMeander`, `Q_CpwLine`, `Q_CpwCouplerT`
- ports/pads: `Q_CpwLaunchpadWirebond`
- JJ model: `Q_InductorAbstract`
- other: interdigital capacitors, bumps, etc.

= Electromagnetic Simulation
ADS QuantumPro supports two types of electromagnetic analysis methods:
- *Full EM Analysis* does a frequency sweep of the circuit with input and output ports. It returns the S-parameters of the circuit, which can be converted to Y-parameters, Z-parameters, capacitance/inductance matrices, etc. It can use  Momentum RF, Momentum Microwave, and Finite Element Method solvers.
- *Energy Participation Analysis* finds the eigenfrequencies of the system along with electromagnetic field patterns supported by the modes. It only uses the FEM solver.
Types of Solvers:
- *Momentum RF*: a quasi-static solver that uses the method of moments. This is recommended for fast analysis of planar structures.
- *Momentum Microwave*: a full EM solver based on the method of moments suitable for planar structures. This solver is recommended for more accurate analysis of planar structures, especially when the quasi-static approximation is not valid.
- *Finite Element Method*: a full EM solver based on the finite element method suitable for 3D structures.

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
