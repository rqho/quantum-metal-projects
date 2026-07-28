"""Geometry constants mirrored from 5QubitChip.ipynb (Qiskit Metal).

Chip coordinates in this module are always **millimeters** (same as Metal).
`place.mm_to_uu()` converts them to the layout database user unit at place time
(Quantum Single-Layer technology typically uses **microns**, so 0.45 mm → 450 UU).

Component length parameters use micron strings for ads_quantum PCells (e.g. ``"30 um"``).
"""

from __future__ import annotations

import os
from pathlib import Path

PACKAGE_DIR = Path(__file__).resolve().parent
TECH_TEMPLATE_DIR = PACKAGE_DIR / "tech_template"

# Default ADS install (override with ADS_HPEESOF_DIR if needed)
DEFAULT_ADS_DIR = Path(r"C:\Program Files\Keysight\ADS2026_Update2")
ADS_DIR = Path(os.environ.get("ADS_HPEESOF_DIR", DEFAULT_ADS_DIR))

# Workspace location (override with ADS_WORKSPACE_DIR)
DEFAULT_WORKSPACE_PARENT = PACKAGE_DIR.parent / "ads_workspaces"
WORKSPACE_PARENT = Path(os.environ.get("ADS_WORKSPACE_DIR", DEFAULT_WORKSPACE_PARENT))

WORKSPACE_NAME = "5QubitChip_wrk"
LIBRARY_NAME = "5QubitChip_lib"
CELL_NAME = "Chip_5Q"

QUANTUM_LIBRARY = "ads_quantum"
LAYOUT_VIEW = "layout"

# ---------------------------------------------------------------------------
# Chip / CPW
# ---------------------------------------------------------------------------
CHIP_SIZE_MM = 6.0
CPW_W_UM = 10.0
CPW_GAP_UM = 6.0
FILLET_UM = 20.0
CONTROL_FILLET_UM = 20.0

# ---------------------------------------------------------------------------
# Qubits (TransmonCrossFL → Q_TransmonCross)
# ---------------------------------------------------------------------------
N_QUBITS = 5
QUBIT_PITCH_MM = 0.45
QUBIT_Y_MM = 0.0

CROSS_THICKNESS_UM = 30.0
CROSS_ARM_LENGTH_UM = 190.0
CROSS_GAP_UM = 50.0

# North readout claw
CLAW_LENGTH_UM = 40.0
CLAW_WIDTH_UM = 10.0
CLAW_GAP_UM = 6.0
CLAW_GROUND_SPACING_UM = 5.0

# Flux line (bottom)
FLUX_LINE_WIDTH_UM = 15.0
FLUX_LINE_LEAD_WIDTH_UM = 5.0
FLUX_LINE_HEIGHT_UM = 15.0
FLUX_LINE_GAP_UM = 3.0
FLUX_LINE_GROUND_BUFFER_UM = 3.0

# XY OpenToGround south of each qubit
XY_OFFSET_X_MM = -0.1
XY_Y_MM = -0.18
XY_WIDTH_UM = 10.0
XY_GAP_UM = 6.0
XY_END_GAP_UM = 6.0
XY_LENGTH_UM = 50.0

# ---------------------------------------------------------------------------
# Readout
# ---------------------------------------------------------------------------
CLT_Y_MM = 1.5
COUPLING_LENGTH_UM = 200.0
COUPLING_SPACE_UM = 4.0

RESONATOR_LENGTHS_UM = [4410.0, 4450.0, 4490.0, 4530.0, 4570.0]
RESONATOR_SPACING_UM = 50.0
RESONATOR_LEAD_UM = 150.0

CAP_IN_POS = (-2.4, 1.5)  # mm
CAP_OUT_POS = (-1.0, 2.15)  # mm — on the path up to LP_N1

# ---------------------------------------------------------------------------
# Launchpads (mm): name → (x, y, angle_deg)
# orientation: 0 = CPW exits +x (west pads), 180 = −x (east),
#              90 = +y (south pads), 270 = −y (north pads)
# ---------------------------------------------------------------------------
LAUNCHPADS = {
    "LP_W1": (-2.8, -1.5, 0.0),
    "LP_W2": (-2.8, 0.0, 0.0),
    "LP_W3": (-2.8, 1.5, 0.0),
    "LP_E1": (2.8, -1.5, 180.0),
    "LP_E2": (2.8, 0.0, 180.0),
    "LP_E3": (2.8, 1.5, 180.0),
    "LP_S1": (-1.5, -2.8, 90.0),
    "LP_S2": (0.0, -2.8, 90.0),
    "LP_S3": (1.5, -2.8, 90.0),
    "LP_N1": (-1.5, 2.8, 270.0),
    "LP_N2": (0.0, 2.8, 270.0),
    "LP_N3": (1.5, 2.8, 270.0),
}

# Inset from pad origin to the CPW port facing the chip interior (mm)
LAUNCHPAD_PORT_INSET_MM = 0.22


def qubit_x(i: int) -> float:
    """X position (mm) of qubit i in the linear array."""
    return (i - 2) * QUBIT_PITCH_MM


def um(value: float) -> str:
    """Format a micron length for ads_quantum parameters."""
    return f"{value} um"


def yes_no(flag: bool) -> str:
    return "yes" if flag else "no"


def launchpad_port(name: str) -> tuple[float, float]:
    """CPW attachment point on the interior side of a launchpad."""
    x, y, angle = LAUNCHPADS[name]
    d = LAUNCHPAD_PORT_INSET_MM
    if abs(angle - 0.0) < 1.0:
        return (x + d, y)
    if abs(angle - 180.0) < 1.0:
        return (x - d, y)
    if abs(angle - 90.0) < 1.0:
        return (x, y + d)
    if abs(angle - 270.0) < 1.0:
        return (x, y - d)
    return (x, y)


def xy_start(i: int) -> tuple[float, float]:
    return (qubit_x(i) + XY_OFFSET_X_MM, XY_Y_MM)


def z_start(i: int) -> tuple[float, float]:
    return (
        qubit_x(i),
        QUBIT_Y_MM - (CROSS_ARM_LENGTH_UM + FLUX_LINE_HEIGHT_UM) / 1000.0,
    )


# Explicit clean control routes: (name, waypoint list in mm)
# Connectivity matches 5QubitChip.ipynb launchpad assignments.
def control_paths() -> list[tuple[str, list[tuple[float, float]]]]:
    paths: list[tuple[str, list[tuple[float, float]]]] = []

    # Q0 XY → LP_W2 (west, y=0)
    s = xy_start(0)
    paths.append(
        (
            "XY_Line_0",
            [s, (s[0], 0.0), launchpad_port("LP_W2")],
        )
    )
    # Q0 Z → LP_W1 (west, y=-1.5)
    s = z_start(0)
    paths.append(
        (
            "Z_Line_0",
            [s, (s[0], -1.5), launchpad_port("LP_W1")],
        )
    )
    # Q1 XY → LP_S1
    s = xy_start(1)
    paths.append(
        (
            "XY_Line_1",
            [s, (s[0], -2.35), launchpad_port("LP_S1")],
        )
    )
    # Q1 Z → LP_S2
    s = z_start(1)
    paths.append(
        (
            "Z_Line_1",
            [s, (s[0], -2.45), launchpad_port("LP_S2")],
        )
    )
    # Q2 XY → LP_S3
    s = xy_start(2)
    paths.append(
        (
            "XY_Line_2",
            [s, (s[0], -2.55), launchpad_port("LP_S3")],
        )
    )
    # Q2 Z → LP_E1
    s = z_start(2)
    paths.append(
        (
            "Z_Line_2",
            [s, (s[0], -2.0), (2.35, -2.0), (2.35, -1.5), launchpad_port("LP_E1")],
        )
    )
    # Q3 XY → LP_E2
    s = xy_start(3)
    paths.append(
        (
            "XY_Line_3",
            [s, (s[0], -1.85), (2.45, -1.85), (2.45, 0.0), launchpad_port("LP_E2")],
        )
    )
    # Q3 Z → LP_E3
    s = z_start(3)
    paths.append(
        (
            "Z_Line_3",
            [s, (s[0], -1.70), (2.55, -1.70), (2.55, 1.5), launchpad_port("LP_E3")],
        )
    )
    # Q4 XY → LP_N3
    s = xy_start(4)
    paths.append(
        (
            "XY_Line_4",
            [
                s,
                (s[0], -1.55),
                (2.65, -1.55),
                (2.65, 2.35),
                (1.5, 2.35),
                launchpad_port("LP_N3"),
            ],
        )
    )
    # Q4 Z → LP_N2
    s = z_start(4)
    paths.append(
        (
            "Z_Line_4",
            [
                s,
                (s[0], -1.40),
                (2.20, -1.40),
                (2.20, 2.45),
                (0.0, 2.45),
                launchpad_port("LP_N2"),
            ],
        )
    )
    return paths


def feed_path() -> list[tuple[float, float]]:
    """Multiplexed readout bus: LP_W3 → caps/CLTs → LP_N1."""
    x0 = qubit_x(0)
    x4 = qubit_x(4)
    return [
        launchpad_port("LP_W3"),
        CAP_IN_POS,
        (x0 - 0.20, CLT_Y_MM),
        (x4 + 0.30, CLT_Y_MM),
        (x4 + 0.30, CAP_OUT_POS[1]),
        (launchpad_port("LP_N1")[0], CAP_OUT_POS[1]),
        launchpad_port("LP_N1"),
    ]
