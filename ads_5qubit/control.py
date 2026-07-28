"""XY / Z control-line routing via continuous CPW paths."""

from __future__ import annotations

from typing import Any

from . import config as cfg
from .place import place_polyline_cpw


def place_control(layout: Any) -> dict[str, Any]:
    """Route all XY and Z control lines to their launchpads."""
    placed: dict[str, Any] = {}
    for name, waypoints in cfg.control_paths():
        placed[name] = place_polyline_cpw(
            layout,
            waypoints,
            name_prefix=name,
            draw_bridges=False,
        )
    print(f"Routed {len(placed)} XY/Z control lines (continuous CPW paths).")
    return placed
