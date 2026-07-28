# 5-Qubit Chip → ADS QuantumPro

Python package that rebuilds the planar layout from [`5QubitChip.ipynb`](../5QubitChip.ipynb) as **parametric** Keysight ADS QuantumPro (`ads_quantum`) components so you can edit geometry in ADS and run EM / quantum parameter extraction.

## Requirements

- Keysight ADS **2026 Update2** (or later) with **QuantumPro**
- Library `ads_quantum` available (ships with ADS at `oalibs/rf/ads_quantum`)
- Scripts must run in the **ADS Python console** (not plain system Python)

Default ADS path assumed:

`C:\Program Files\Keysight\ADS2026_Update2`

Override with env vars if needed:

| Variable | Purpose |
|---|---|
| `ADS_HPEESOF_DIR` | ADS install root |
| `ADS_WORKSPACE_DIR` | Parent folder for `5QubitChip_wrk` (default: `ads_workspaces/` in this repo) |

## Quick start

1. Start ADS 2026.
2. Open **Tools → Python Console** (or the Design Environment Python console).
3. Run (use `recreate=True` after pulling fixes so the workspace is rebuilt):

```python
import sys
sys.path.insert(0, r"C:\Users\Richard Ho\Documents\Projects\quantum-metal-projects")

from ads_5qubit.build_chip import build_chip
layout = build_chip(recreate=True)
```

You should see a log line like `Layout user unit ≈ µm ...` — that conversion is required so qubit pitch (0.45 mm) becomes 450 layout units instead of 0.45.

If traces looked like a rat's nest with pins everywhere: interconnects are now
**continuous CPW paths** (`add_path` on cond/keepout) instead of chained
`Q_CpwLine`/`Q_CpwCurvedBend` PCells. Control and feed routes are explicit
waypoint lists in `config.py` (`control_paths()`, `feed_path()`).

4. In the ADS workspace browser, open:

`5QubitChip_lib` → `Chip_5Q` → **layout**

Workspace is created under:

`quantum-metal-projects/ads_workspaces/5QubitChip_wrk`

(unless `ADS_WORKSPACE_DIR` is set).

## What gets placed

| Metal (notebook) | ADS cell | Notes |
|---|---|---|
| `TransmonCrossFL` ×5 | `Q_TransmonCross` | Cross 30/190/50 µm; north claw; flux on bottom |
| `OpenToGround` XY | `Q_CpwLineOpen` | South of each qubit |
| `CoupledLineTee` | `Q_CpwCouplerT` | `y = 1.5 mm` |
| `RouteMeander` | `Q_CpwMeander` | Lengths 4.41–4.57 mm |
| Feed / control routes | `Q_CpwLine` + `Q_CpwCurvedBend` | Manhattan paths from notebook turtles |
| `LaunchpadWirebond` | `Q_CpwLaunchpadWirebond` | All 12 edge pads |
| `CapNInterdigital` | `Q_CapacitorNInterdigital` | Feed input/output |

Geometry constants live in [`config.py`](config.py) (edit there to retune pitch, claw, resonator lengths, etc., then re-run `build_chip(recreate=True)`).

## Customize in ADS

After the layout is built:

1. Select any instance (e.g. `Q0`).
2. Edit PCell parameters (`CrossArmLength`, `ConnectorLengthTop`, `L` on resonators, …).
3. The artwork regenerates automatically.

To rebuild from the Python config after notebook-style changes:

```python
from ads_5qubit.build_chip import build_chip
build_chip(recreate=True)
```

EM-only core (skip long XY/Z routes):

```python
build_chip(recreate=True, include_control=False)
```

## QuantumPro EM (next steps)

1. Open `Chip_5Q` layout.
2. Confirm substrate is the Quantum Single-Layer stack (`tech.subst` — SiliconLowTemp / Al-style conductor layers from the template).
3. Place EM ports on the readout launchpads (`LP_W3`, `LP_N1`) and any control pads you need.
4. Run **QuantumPro** frequency-domain or eigenmode analysis.
5. Use built-in quantum parameter extraction (quasi-static / black-box / EPR) as available in your ADS build.

## Technology bootstrap

The package ships a **Quantum Single-Layer** tech snapshot under [`tech_template/`](tech_template/) (copied from ADS `examples/Quantum/Single_Qubit_Chip_wrk`). Those files are installed into `5QubitChip_lib` when the workspace is created.

If PCells complain about missing quantum layers:

1. **File → New Workspace**
2. Choose **Quantum Technology Library → Single-Layer Technology**
3. Point `ADS_WORKSPACE_DIR` at that workspace’s parent, set `LIBRARY_NAME` / paths in `config.py` if needed, and call `build_chip(recreate=False)` after adapting `workspace.py` — or recreate with the bundled template after fixing ADS paths.

## Package layout

```
ads_5qubit/
  build_chip.py   # entry point
  config.py       # Metal → ADS geometry constants
  workspace.py    # create/open ADS workspace + tech
  place.py        # PCell + CPW helpers
  qubits.py
  readout.py
  control.py
  tech_template/  # Quantum Single-Layer library.tech / tech.db / …
  README.md
```
