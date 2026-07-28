"""Entry point: build the full 5-qubit ADS QuantumPro layout.

Run inside the ADS 2026 Python console:

    import sys
    sys.path.insert(0, r"C:\\Users\\Richard Ho\\Documents\\Projects\\quantum-metal-projects")
    from ads_5qubit.build_chip import build_chip
    build_chip(recreate=True)
"""

from __future__ import annotations

from pathlib import Path
from typing import Any

from . import config as cfg
from . import place as place_mod
from .control import place_control
from .place import place_boundary
from .qubits import place_qubits
from .readout import place_readout
from .workspace import ensure_workspace


def build_chip(
    workspace_parent: Path | str | None = None,
    *,
    recreate: bool = False,
    include_control: bool = True,
    include_boundary: bool = True,
) -> Any:
    """Create the ADS workspace (if needed) and populate Chip_5Q layout.

    Parameters
    ----------
    workspace_parent :
        Directory that will contain ``5QubitChip_wrk``. Defaults to
        ``ads_workspaces/`` next to this package, or ``ADS_WORKSPACE_DIR``.
    recreate :
        If True, delete and recreate the workspace from scratch.
    include_control :
        Place XY/Z control routes (full chip). Set False for a faster EM core.
    include_boundary :
        Draw a 6×6 mm boundary rectangle when the layer is available.
    """
    place_mod._logged_uu_scale = False
    parent = Path(workspace_parent) if workspace_parent else None
    wrk, library, layout = ensure_workspace(parent, recreate=recreate)

    if include_boundary:
        place_boundary(layout, cfg.CHIP_SIZE_MM)

    place_qubits(layout)
    place_readout(layout)
    if include_control:
        place_control(layout)

    layout.save_design()
    lcv = f"{library.name}:{cfg.CELL_NAME}:{cfg.LAYOUT_VIEW}"
    print(f"Saved layout: {lcv}")
    print(f"Workspace: {cfg.WORKSPACE_PARENT / cfg.WORKSPACE_NAME}")
    print(
        "Next: open the layout in ADS, assign ports on launchpads, "
        "and run QuantumPro EM / quantum parameter extraction."
    )
    return layout


if __name__ == "__main__":
    build_chip(recreate=True)
