#import "@preview/arkheion:0.1.2": arkheion, arkheion-appendices

#show: arkheion.with(
  title: "A Tutorial on the Design and Simulation of Superconducting Quantum Devices using Keysight ADS QuantumPro",
  authors: (
    (name: "Richard Ho", email: "rqho@umich.edu", affiliation: "University of Michigan"),
  ),
  abstract: [This tutorial outlines the end-to-end design and simulation workflow for a flip-chip superconducting quantum device using Keysight PathWave ADS and QuantumPro. It covers the creation of the parametric layout, setting up the 3D electromagnetic environment, extracting critical quantum parameters using Energy Participation Ratio (EPR) analysis, and preparing the design for fabrication. The primary device under test features transmon qubits coupled to coplanar waveguide (CPW) readout resonators in a multi-layer flip-chip architecture.],

  date: "August 15, 2026",
)

#show link: underline

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
After opening QuantumPro, right-click on the plane enclosing the design on the model and set it as Ground. Then, create ports P1/P2 and P3/P4 and component models for the JJ in the Full EM Analysis and Energy Participation Analysis simulation setups. For the inductor component model, change the model to Lumped and set the inductance to 11 nH.

#figure(
  image("assets/ComponentModel.png", width: 70%),
  caption: [
    The component model editor for the `Q_InductorAbstract` component.
  ],
)


For Full EM Analysis :
- The frequency sweep is Adaptive from 1 to 10 GHz with 300 points.
- Mesh should be refined (under Simulator) to approximately 200 cpw.
- For better simulation accuracy and to capture the capacitive effects around the transmon pocket, it is recommended to increase the mesh density near the transmon pocket.
- Clicking the simulation setup button (the wrench icon) brings up Advanced Simulator Setup as shown below. The meshes for Nets 5 and 6 should be set to 2000 cpw (green box).
- Edge mesh should be enabled (set to Automatic) to accurately capture the current distribution across the CPW lines.

#figure(
  grid(
    columns: 2,
    gutter: 0.5em,
    image("assets/1Qfemsimulator1.png", width: 100%),
    image("assets/1Qfemsimulator.png", width: 100%),
  ),
  caption: [
    Advanced Simulator Setup for Full EM Analysis.
  ],
)

For Energy Participation Analysis :
- The frequency sweep is from 1 to 10 GHz.
- In Advanced Simulator, the Target Mesh Size should be set Automatic
- For the overriding condition, conductors cond(1) should be set to 5 um. This secures two mesh elements per the CPW line strip.

#figure(
  image("assets/1Qeprsimulator.png", width: 70%),
  caption: [
    Advanced Simulator Setup for Energy Participation Analysis.
  ],
)

=== Results
The simulation results include the mesh and extracted parameters for both FEM and EPR simulations. Note that the extracted parameters window only shows if the simulator sees a qubit in the design. The extracted parameters are the qubit frequency, anharmonicity, and cross-Kerr coupling strength. 
#table(
  columns: (auto, auto, auto),
  stroke: none,

  [], [Full EM Analysis], [Energy Participation Analysis],
  [Mesh], [#image("assets/1Qfemmesh.png")], [#image("assets/1Qeprmesh.png")],
  [Extracted\ Parameters], [#image("assets/1Qfemparams.png")], [#image("assets/1Qeprparams.png")],
)

= Example: Multi-Qubit Chip (GDS import)

=== Layout
When importing a design from a GDSII file into ADS, map the layers to the Quantum Technology Library layers. This design was created in Quantum Metal (formerly Qiskit Metal) and then exported to GDSII. We use the layer mapping below (following this #link("https://www.youtube.com/watch?v=PFE4E2bohyI&t=364s")[video tutorial]).

#figure(
  image("assets/GDSImport.png", width: 80%),
  caption: [
    Layer mapping for the GDS import.
  ],
)

#figure(
  image("assets/MultiQubitLayout.png", width: 70%),
  caption: [
    Layout view of the three-qubit chip.
  ],
)

To prepare the design for simulation, we need to add ports to the launchpads and inductors to the Josephson junctions at the qubits.

#table(
  columns: (auto, auto),
  stroke: none,

  [#image("assets/MultiQubitPorts.png", width: 70%)], [#image("assets/MultiQubitInductors.png", width: 100%)],
)

=== Simulation
Following the same steps as the single-qubit example, we can set up the simulation for the three-qubit chip. When viewing the simulation results, we can select Near Field to view the electric field distribution at each eigenfrequency.

#table(
  columns: (auto, auto, auto),
  align: center,
  stroke: none,

  [#image("assets/MultiQubit1.png")], [#image("assets/MultiQubit2.png")], [#image("assets/MultiQubit3.png")],
  [Qubit 1: 3.82 GHz], [Qubit 2: 3.95 GHz], [Qubit 3: 4.15 GHz],
)

= Example: Flip-Chip
This example demonstrates the design and simulation of a flip-chip qubit with a CPW resonator.

=== Substrate Editor
We use *Multi-Layer Technology* in the *Quantum Technology Library* to define the layout technology with the following thicknesses: 280 um Silicon dielectric, 0 nm perfect conductor, 1 um airbridge, and 6 um air dielectric spacing between the chips. The total chip-to-chip distance is 8 um.

#figure(
  grid(
    columns: 2,
    gutter: 0.5em,
    image("assets/FlipChipLayer1.png", width: 100%),
    image("assets/FlipChipLayer2.png", width: 100%),
  ),
  caption: [
    Layer setup for the flip-chip qubit design.
  ],
)

#figure(
  image("assets/FlipChipSubstrate.png"),
  caption: [
    Substrate editor view of the flip-chip qubit.
  ],
)

=== Schematic
#figure(
  image("assets/FlipChipSchematic.png"),
  caption: [
    Schematic view of the flip-chip qubit design.
  ],
)

When editing the schematic/layout, you can specify what components are on the top chip and the bottom chip by editing the parameter `LayerGroupPrefix`. In this example, we use "2\_" for the transmon and inductor for the top chip.

=== Layout
#figure(
  image("assets/FlipChipLayout.png"),
  caption: [
    Layout view of the flip-chip qubit design.
  ],
)

In the layout, we draw a rectangle in the `boundary` (the bigger rectangle enclosing the resonator and feedline) layer to define the geometry of the bottom chip. The top chip is defined by the `2_boundary` (the smaller rectangle enclosing the qubit) layer in the layout of the top chip. We also create cirles in the `bump1_2` (red) layer to define the locations of the bumps that connect the two chips.

=== Simulation

#figure(
  image("assets/FlipChipQuantumPro.png", width: 70%),
  caption: [
    3D view for the flip-chip qubit design in QuantumPro. Use the zoom tool to expand the figure.
  ],
)

#table(
  columns: (auto, auto),
  align: center,
  stroke: none,

  [#image("assets/FlipChipQubit.png")], [#image("assets/FlipChipResonator.png")],
  [Qubit: 4.27 GHz], [Resonator: 7.17 GHz],
)

= Example: SQUIDs and SNAILs
This example demonstrates the design and simulation of a SQUID and SNAIL devices. There are tutorials in the Keysight ADS documentation for simulating SQUID circuits in the schematic editor but there are none for designing their layout.
- A SQUID consists of two Josephson Junctions located on opposite sides of a rectangular loop.
- A SNAIL consists of a superconducting loop interrupted by $n$ large Josephson junctions on one arm (here $n = 3$) and a single smaller junction on the opposite arm.

=== Layout
#figure(
  image("assets/SQUIDChip.png", width: 60%),
  caption: [
    Layout view of the SQUID chip.
  ],
)
Specifications:
- Top Left Resonator: Designed for $f_r = 4.8$ GHz with $Q_c = 400$k
  - Shorted to ground
- Bottom Left Resonator: Designed for $f_r = 4.2$ GHz with $Q_c = 500$k
  - Terminated with SQUID with 51.7 pH large inductor and 128.8 pH small inductor
- Top Right Resonator: Designed for $f_r = 6.4$ GHz with $Q_c = 200$k
  - Terminated with SQUID with 51.7 pH large inductor and 128.8 pH small inductor
- Bottom Right Resonator: Designed for $f_r = 6.2$ GHz with $Q_c = 230$k
  - Terminated with SNAIL with 3 $times$ 0.685nH large inductor and 6.42 nH small inductor

A `Q_SquidLoop` component from Quantum Artwork is used to create the loop and the geometry of the loop and the inductors are modified to fit into the gap between the resonator and the ground plane as shown.

#figure(
  image("assets/SQUIDLoop.png", width: 60%),
  caption: [
    Layout view of the SQUID loop.
  ],
)

=== Simulation
Using a combination of full EM analysis and energy participation analysis, we can extract the eigenfrequencies and the electric field distribution at each eigenfrequency.

#pagebreak()

#table(
  columns: (auto, auto),
  align: center,
  stroke: none,

  [#image("assets/SQUIDTL.png", height: 40%) Top Left Resonator: 4.47 GHz], [#image("assets/SQUIDBL.png", height: 40%) Bottom Left: 8.55 GHz],
  [Top Right Resonator: 6.4 GHz], [#image("assets/SQUIDBR.png", height: 40%) Bottom Right: 11.35 GHz],
)

#figure(
  table(
    columns: 5,
    stroke: none,
    inset: (x: 8pt, y: 6pt),
    align: (left, center, center, center, center),
    table.hline(stroke: 0.08em),
    table.header(
      [*Resonator*],
      [*Termination*],
      [*Designed*\ $f_r$ (GHz)],
      [*Simulated*\ (shorted) (GHz)],
      [*Simulated*\ (SQUID/SNAIL) (GHz)],
    ),
    table.hline(stroke: 0.05em),
    [Top Left], [Short], [4.8], [4.601], [4.47\*],
    [Bottom Left], [SQUID], [4.2], [4.178], [8.55],
    [Top Right], [SQUID], [6.4], [6.291], [---],
    [Bottom Right], [SNAIL], [6.2], [6.159], [11.35],
    table.hline(stroke: 0.08em),
  ),
  caption: [Comparison of designed and simulated eigenfrequencies for the SQUID/SNAIL chip resonators.],
)

#pagebreak()

= References

+ P. Krantz et al., "A quantum engineer's guide to superconducting qubits," _Appl. Phys. Rev._ *6*, 021318 (2019).
+ Keysight Technologies, "Designing for Superconducting Qubit Circuits," Appl. Note 3123-1286.EN (2023).
+ Keysight Technologies, "Quantum Parameter Extraction in QuantumPro," Appl. Note 3123-1662.EN (2023).
+ Keysight Technologies, "Design of Transmon Qubit and CPW Resonator in Flip-Chip Technology with ADS, Quantum Pro," Appl. Note 3125-1427.EN (2025).
