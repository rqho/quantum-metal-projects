"""Helpers for placing ads_quantum PCells and CPW route segments."""

from __future__ import annotations

import math
from typing import Any, Mapping, Sequence

from . import config as cfg

try:
    from keysight.ads.de import db as ads_db
except ImportError:  # pragma: no cover
    ads_db = None  # type: ignore


Point = tuple[float, float]

_logged_uu_scale = False


def cellview(cell: str, view: str = "layout") -> str:
    return f"{cfg.QUANTUM_LIBRARY}:{cell}:{view}"


def mm_per_uu(layout: Any) -> float:
    """Millimeters per layout user-unit (Quantum Single-Layer is typically microns)."""
    # meter_to_uu_factor: 1e6 → µm UU, 1e3 → mm UU
    return 1000.0 / float(layout.meter_to_uu_factor)


def mm_to_uu(layout: Any, x_mm: float, y_mm: float) -> Point:
    """Convert chip coordinates in mm to layout user units."""
    global _logged_uu_scale
    scale = 1.0 / mm_per_uu(layout)  # UU per mm
    if not _logged_uu_scale:
        m2u = float(layout.meter_to_uu_factor)
        unit = "µm" if m2u > 5e5 else ("mm" if m2u > 500 else f"m2uu={m2u:g}")
        print(
            f"Layout user unit ≈ {unit} "
            f"(meter_to_uu_factor={m2u:g}); placing in mm then converting."
        )
        _logged_uu_scale = True
    return (x_mm * scale, y_mm * scale)


DROPDOWN_PARAMS = {
    "DrawTopConnector",
    "DrawLeftConnector",
    "DrawRightConnector",
    "DrawBottomConnector",
    "DrawAsClawTop",
    "DrawAsClawLeft",
    "DrawAsClawRight",
    "DrawAsClawBottom",
    "DrawFluxLineConnector",
    "DrawFluxLineConnectorAsL",
    "FluxLineLocation",
    "DrawBridges",
    "DrawBridge",
    "SecondOpenTermination",
    "EndPin",
    "Pin1Orientation",
    "Pin2Orientation",
}


def _param_aliases(key: str, value: Any) -> list[Any]:
    """Candidate values for ADS dropdown / yes-no / location forms."""
    candidates: list[Any] = [value]
    if isinstance(value, bool):
        candidates.extend(
            ["yes" if value else "no", "quantum_yes" if value else "quantum_no"]
        )
    elif value in ("yes", "no"):
        candidates.append(f"quantum_{value}")
    elif value in ("top", "left", "right", "bottom"):
        candidates.append(f"quantum_location_{value}")
    elif value in ("upwards", "downwards", "horizontal"):
        candidates.append(f"quantum_pin_{value}")

    if ads_db is not None and key in DROPDOWN_PARAMS:
        for form_name in list(candidates):
            if isinstance(form_name, str):
                try:
                    candidates.append(ads_db.const_param(form_name))
                except Exception:
                    pass
    return candidates


def set_params(inst: Any, params: Mapping[str, Any] | None) -> None:
    """Assign PCell parameters; values are typically strings like '30 um' or 'yes'."""
    if not params:
        return
    for key, value in params.items():
        last_exc: Exception | None = None
        param = inst.parameters[key]
        for candidate in _param_aliases(key, value):
            try:
                # Only ConstForm / dropdown params may use form_name. Length
                # strings like "30 um" must go through .value — assigning them
                # to form_name silently "succeeds" and leaves the length unset.
                if key in DROPDOWN_PARAMS and isinstance(candidate, str) and hasattr(
                    param, "form_name"
                ):
                    try:
                        param.form_name = candidate
                        last_exc = None
                        break
                    except Exception:
                        pass
                param.value = candidate
                last_exc = None
                break
            except Exception as exc:
                last_exc = exc
        if last_exc is not None:
            raise RuntimeError(
                f"Failed to set parameter {key}={value!r} on "
                f"{getattr(inst, 'name', inst)}: {last_exc}"
            ) from last_exc
    try:
        if hasattr(inst, "update_item_annotation"):
            inst.update_item_annotation()
    except Exception:
        pass


def refresh_pcell(layout: Any, inst: Any) -> None:
    """Force PCell artwork to regenerate after parameter changes."""
    if ads_db is None:
        return
    try:
        ctx = ads_db.ExpressionContext(layout)
        try:
            ctx.setup_hierarchy_for_layout_only(layout)
        except Exception:
            ctx.setup_hierarchy_for_design(layout)
        ctx.update_pcell_params(inst)
    except Exception as exc:
        # Non-fatal: saved params may still apply on next open in ADS
        print(f"Note: update_pcell_params skipped for {getattr(inst, 'name', inst)}: {exc}")


def place_pcell(
    layout: Any,
    cell: str,
    origin_mm: Point,
    *,
    name: str = "",
    angle: float = 0.0,
    params: Mapping[str, Any] | None = None,
    mirror: str | None = None,
) -> Any:
    """Place an ads_quantum layout PCell at a chip position given in millimeters."""
    kwargs: dict[str, Any] = {"angle": float(angle)}
    if name:
        kwargs["name"] = name
    if mirror:
        kwargs["mirror"] = mirror
    origin_uu = mm_to_uu(layout, origin_mm[0], origin_mm[1])
    inst = layout.add_instance(cellview(cell), origin_uu, **kwargs)
    set_params(inst, params)
    refresh_pcell(layout, inst)
    return inst


def place_cpw_line(
    layout: Any,
    p0_mm: Point,
    p1_mm: Point,
    *,
    name: str,
    w_um: float = cfg.CPW_W_UM,
    gap_um: float = cfg.CPW_GAP_UM,
    draw_bridges: bool = False,
) -> Any | None:
    """Place a Q_CpwLine between two points (mm). Returns None if length ~ 0."""
    dx = p1_mm[0] - p0_mm[0]
    dy = p1_mm[1] - p0_mm[1]
    length_mm = math.hypot(dx, dy)
    if length_mm < 1e-6:
        return None
    angle = math.degrees(math.atan2(dy, dx))
    return place_pcell(
        layout,
        "Q_CpwLine",
        p0_mm,
        name=name,
        angle=angle,
        params={
            "W": cfg.um(w_um),
            "Gap": cfg.um(gap_um),
            "L": cfg.um(length_mm * 1000.0),
            "DrawBridges": cfg.yes_no(draw_bridges),
        },
    )


def place_cpw_bend(
    layout: Any,
    origin_mm: Point,
    *,
    name: str,
    angle: float,
    radius_um: float = cfg.FILLET_UM,
    w_um: float = cfg.CPW_W_UM,
    gap_um: float = cfg.CPW_GAP_UM,
    draw_bridge: bool = False,
) -> Any:
    """Place a Q_CpwCurvedBend at a corner (mm origin, degrees)."""
    return place_pcell(
        layout,
        "Q_CpwCurvedBend",
        origin_mm,
        name=name,
        angle=angle,
        params={
            "W": cfg.um(w_um),
            "Gap": cfg.um(gap_um),
            "Radius": cfg.um(radius_um),
            "DrawBridge": cfg.yes_no(draw_bridge),
        },
    )


def _turn_heading(heading: float, turn: str) -> float:
    """Apply a turtle L/R turn to a heading in degrees (CCW positive, 0 = +x)."""
    if turn.upper() == "L":
        return (heading + 90.0) % 360.0
    if turn.upper() == "R":
        return (heading - 90.0) % 360.0
    raise ValueError(f"Unknown turtle turn {turn!r}")


def turtle_polyline(
    start: Point,
    heading_deg: float,
    start_straight_um: float,
    steps: Sequence[tuple[str, float]],
) -> list[Point]:
    """Build a Manhattan polyline from Metal-style turtle jogs.

    Parameters
    ----------
    start : (x, y) mm
    heading_deg : initial direction (0 = +x, 90 = +y)
    start_straight_um : initial lead before turtle turns
    steps : sequence of (turn, length_um)
    """
    pts: list[Point] = [start]
    x, y = start
    heading = heading_deg % 360.0

    def advance(dist_um: float) -> None:
        nonlocal x, y
        dist_mm = dist_um / 1000.0
        rad = math.radians(heading)
        x += dist_mm * math.cos(rad)
        y += dist_mm * math.sin(rad)
        pts.append((x, y))

    if start_straight_um > 0:
        advance(start_straight_um)

    for turn, length_um in steps:
        heading = _turn_heading(heading, turn)
        if length_um > 0:
            advance(length_um)

    return pts


def place_polyline_cpw(
    layout: Any,
    points: Sequence[Point],
    *,
    name_prefix: str = "",
    end: Point | None = None,
    w_um: float = cfg.CPW_W_UM,
    gap_um: float = cfg.CPW_GAP_UM,
    fillet_um: float = cfg.CONTROL_FILLET_UM,
    draw_bridges: bool = False,
) -> list[Any]:
    """Draw a continuous CPW along a polyline (mm).

    Uses ``add_path`` on cond/keepout so the route is one connected trace
    without a pin at every segment (unlike chained Q_CpwLine PCells).
    """
    del fillet_um, draw_bridges  # reserved / unused for path drawing
    pts = list(points)
    if end is not None:
        pts.extend(_manhattan_to(pts[-1], end))

    cleaned: list[Point] = [pts[0]]
    for p in pts[1:]:
        if math.hypot(p[0] - cleaned[-1][0], p[1] - cleaned[-1][1]) > 1e-6:
            cleaned.append(p)

    if len(cleaned) < 2:
        return []

    try:
        return list(draw_cpw_polyline(layout, cleaned, w_um=w_um, gap_um=gap_um))
    except Exception as exc:
        print(f"Note: path draw failed for {name_prefix} ({exc}); falling back to Q_CpwLine.")
        placed: list[Any] = []
        for i in range(len(cleaned) - 1):
            inst = place_cpw_line(
                layout,
                cleaned[i],
                cleaned[i + 1],
                name=f"{name_prefix}_L{i}" if name_prefix else f"seg_{i}",
                w_um=w_um,
                gap_um=gap_um,
                draw_bridges=False,
            )
            if inst is not None:
                placed.append(inst)
        return placed


def um_to_uu(layout: Any, length_um: float) -> float:
    """Convert microns to layout user units."""
    return float(length_um) * 1e-6 * float(layout.meter_to_uu_factor)


def _library_for(layout: Any) -> Any:
    lib = getattr(layout, "library", None)
    if lib is not None:
        return lib
    import keysight.ads.de as de

    return de.get_open_library(cfg.LIBRARY_NAME)


def get_drawing_layer(layout: Any, layer_name: str) -> Any:
    from keysight.ads.de.db import LayerId

    lib = _library_for(layout)
    return LayerId.create_layer_id_from_library(lib, layer_name, "drawing")


def draw_cpw_polyline(
    layout: Any,
    points_mm: Sequence[Point],
    *,
    w_um: float = cfg.CPW_W_UM,
    gap_um: float = cfg.CPW_GAP_UM,
) -> tuple[Any, Any]:
    """Draw a continuous CPW center+gap along points (mm) with no intermediate pins."""
    cleaned: list[Point] = []
    for p in points_mm:
        if not cleaned or math.hypot(p[0] - cleaned[-1][0], p[1] - cleaned[-1][1]) > 1e-9:
            cleaned.append((float(p[0]), float(p[1])))
    if len(cleaned) < 2:
        raise ValueError("CPW polyline needs at least two distinct points")

    pts_uu = [mm_to_uu(layout, x, y) for x, y in cleaned]
    w_uu = um_to_uu(layout, w_um)
    keep_uu = um_to_uu(layout, w_um + 2.0 * gap_um)

    cond = get_drawing_layer(layout, "cond")
    keepout = get_drawing_layer(layout, "keepout")
    center = layout.add_path(cond, pts_uu, w_uu)
    gap = layout.add_path(keepout, pts_uu, keep_uu)
    return center, gap


def _manhattan_to(start: Point, end: Point) -> list[Point]:
    """Simple L-shaped Manhattan path from start to end (prefer horizontal first)."""
    if abs(start[0] - end[0]) < 1e-9 or abs(start[1] - end[1]) < 1e-9:
        return [end]
    mid = (end[0], start[1])
    return [mid, end]


def place_boundary(layout: Any, size_mm: float = cfg.CHIP_SIZE_MM) -> Any | None:
    """Optional chip boundary rectangle on the boundary layer."""
    try:
        from keysight.ads.de.db import LayerId
    except Exception:
        try:
            from keysight.ads.de.db_uu import LayerId  # type: ignore
        except Exception:
            return None

    half = size_mm / 2.0
    ll = mm_to_uu(layout, -half, -half)
    ur = mm_to_uu(layout, half, half)
    try:
        # Resolve library from layout
        lib = layout.library if hasattr(layout, "library") else None
        if lib is None:
            import keysight.ads.de as de

            lib = de.get_open_library(cfg.LIBRARY_NAME)
        layer = LayerId.create_layer_id_from_library(lib, "boundary", "drawing")
        return layout.add_rectangle(layer, ll, ur)
    except Exception as exc:
        print(f"Note: could not draw chip boundary ({exc})")
        return None
