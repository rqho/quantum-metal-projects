# Metal → ADS QuantumPro parameter mapping

Source: `5QubitChip.ipynb` (Qiskit Metal) → `ads_quantum` PCells (ADS 2026).

## Qubit (`TransmonCrossFL` → `Q_TransmonCross`)

| Metal | ADS parameter | Value |
|---|---|---|
| `cross_width` | `CrossThickness` | 30 um |
| `cross_length` | `CrossArmLength` | 190 um |
| `cross_gap` | `CrossGap` | 50 um |
| readout claw `claw_length` | `ConnectorLengthTop` | 40 um |
| `claw_width` | `ConnectorThicknessTop` | 10 um |
| `claw_gap` | `ConnectorGapTop` | 6 um |
| `ground_spacing` | `GroundBufferTop` | 5 um |
| `connector_location='90'` | `DrawTopConnector=yes` | north claw |
| (no E/W pads) | `DrawLeft/RightConnector=no` | bare arms for NN coupling |
| `make_fl=True` | `DrawFluxLineConnector=yes` | |
| `fl_options.t_width` | `FluxLineLeadWidth` | 5 um |
| `fl_options.t_top` | `FluxLineWidth` / height | 15 um |
| `fl_options.t_gap` | `FluxLineGap` | 3 um |
| flux on junction arm | `FluxLineLocation=bottom` | |

## Array

| Metal | ADS |
|---|---|
| `qubit_pitch=0.45 mm` | `QUBIT_PITCH_MM` |
| `pos_x=(i-2)*pitch` | `qubit_x(i)` |
| chip 6×6 mm | boundary rectangle |

## Readout

| Metal | ADS |
|---|---|
| `CoupledLineTee` | `Q_CpwCouplerT` |
| `coupling_length=200 um` | `SecondParallelLength` |
| `coupling_space=4 um` | `GroundBuffer` |
| `RouteMeander` lengths | `Q_CpwMeander.L` = 4410…4570 um |
| `meander.spacing=50 um` | `Spacing` |
| `LaunchpadWirebond` | `Q_CpwLaunchpadWirebond` |
| `CapNInterdigital` | `Q_CapacitorNInterdigital` |

## Control

Metal `RouteFramed` turtle jogs → polyline → `Q_CpwLine` + `Q_CpwCurvedBend` (`CONTROL_ROUTES` in `config.py`).
