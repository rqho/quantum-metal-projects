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

#figure(
  image("assets/substrate.png", width: 70%),
  caption: [
    Substrate editor view of `tech:subst`.
  ],
)

A summary of the layer roles and their corresponding materials is provided below:
- boundary: defines the physical extent of the chip and any keepout regions. In the layout editor, the designer can draw a rectangle or polygon to outline the chip.
- conductor: defines the superconducting metal layer, typically made of niobium or aluminum. This layer is used for the qubit pads, resonators, and CPW lines. It is treated as a perfect conductor for simulation.
- keepout: defines regions where no metal or other structures should be placed. This is used to prevent unwanted coupling or interference between components.
- ground fill: defines the ground plane for the CPW structures. This layer is typically connected to the conductor layer and provides a return path for the microwave signals.
- airbridge: defines the locations of airbridges that connect the ground planes across CPW gaps. Airbridges are used to suppress parasitic modes and improve the performance of the CPW structures.
- inductor: defines the location of the Josephson Junction (JJ) or other inductive elements in the circuit. In the layout, this is typically represented as a small rectangle or polygon that connects to the qubit pads.
- air / dielectric: defines the regions of air or dielectric material in the layout. This layer is used to model the electromagnetic environment around the superconducting structures.

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

- *Ports*: for each launchpad on a feedline, place two pins on the pads to form a port. These act as the input/output for the EM simulation and S-parameter extraction. 
- *Abstract Inductors*: for each Josephson Junction, place an abstract inductor component with the desired inductance value. This allows the EM solver to treat the JJ as a lumped element while still capturing its effect on the circuit. This is edited in the Component Model
- *Frequency Sweep*: We typically use Adaptive frequency sweeps to detect rapid changes in the S-parameters and shrink the simulation step size to map the exact shape of the resonance.
- *Meshing*: We increase the cells-per-wavelength (cpw) globally and even further near qubits and ports. For Momentum simulations, we use around 200 cpw globally and 1000-2000 cpw near ports. For FEM EPR simulations, we change the mesh density to 5 $mu$m edge length on center conductors.

= Example: Single-Qubit Chip
The goal of this design is to create a single-qubit chip with a transmon qubit and a CPW resonator.

=== Substrate Editor
We use *Single-Layer Technology* in the *Quantum Technology Library* to define the layout technology with the following thicknesses: 750 um Silicon dielectric, 200 nm perfect conductor, 8 um air.

=== Schematic
#figure(
  image("assets/1Qschematic.png"),
  caption: [
    Schematic view of the single-qubit chip.
  ],
)
The ports are defined by P1/P2 and P3/P4 and are loaded with a 50 $Omega$ lumped element. The JJ is defined by the `Q_InductorAbstract` component with an inductance of 11 nH.

=== Layout
#figure(
  image("assets/1Qlayout.png"),
  caption: [
    Layout view of the single-qubit chip.
  ],
)

After generating the layout with `Layout > Generate/Update Layout`, we can see the layout view of the single-qubit chip. Draw two rectangles in the `boundary` and `keepout` layers to define geometry of the chip.

=== Simulation
After opening QuantumPro, right-click on the plane enclosing the design on the model and set it as Ground. Then, create ports P1/P2 and P3/P4 and component models for the JJ in the Full EM Analysis and Energy Participation Analysis simulation setups.

= Example: Multi-Qubit Chip (GDS import)

=== Substrate Editor
We use *Single-Layer Technology* in the *Quantum Technology Library* to define the layout technology with the following thicknesses: 750 um Silicon dielectric, 200 nm perfect conductor, 8 um air.

=== Schematic

=== Layout

=== Simulation

= Example: Flip-Chip

=== Substrate Editor
We use *Single-Layer Technology* in the *Quantum Technology Library* to define the layout technology with the following thicknesses: 750 um Silicon dielectric, 200 nm perfect conductor, 8 um air.

=== Schematic

=== Layout

=== Simulation

= Example: SQUIDs and SNAILs

=== Substrate Editor
We use *Single-Layer Technology* in the *Quantum Technology Library* to define the layout technology with the following thicknesses: 750 um Silicon dielectric, 200 nm perfect conductor, 8 um air.

=== Schematic

=== Layout

=== Simulation

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
