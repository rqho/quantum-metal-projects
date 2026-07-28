"""Place multiplexed readout: CLTs, launchpads, caps, feed, meander resonators."""

from __future__ import annotations

from typing import Any

from . import config as cfg
from .place import place_pcell, place_polyline_cpw


def place_launchpads(layout: Any) -> dict[str, Any]:
    placed: dict[str, Any] = {}
    for name, (x, y, angle) in cfg.LAUNCHPADS.items():
        inst = place_pcell(
            layout,
            "Q_CpwLaunchpadWirebond",
            (x, y),
            name=name,
            angle=angle,
            params={
                "TraceWidth": cfg.um(cfg.CPW_W_UM),
                "TraceGap": cfg.um(cfg.CPW_GAP_UM),
            },
        )
        placed[name] = inst
    return placed


def place_couplers(layout: Any) -> dict[str, Any]:
    placed: dict[str, Any] = {}
    for i in range(cfg.N_QUBITS):
        x = cfg.qubit_x(i)
        inst = place_pcell(
            layout,
            "Q_CpwCouplerT",
            (x, cfg.CLT_Y_MM),
            name=f"CLT{i}",
            angle=0.0,
            params={
                "PrimeWidth": cfg.um(cfg.CPW_W_UM),
                "PrimeGap": cfg.um(cfg.CPW_GAP_UM),
                "SecondWidth": cfg.um(cfg.CPW_W_UM),
                "SecondGap": cfg.um(cfg.CPW_GAP_UM),
                "SecondParallelLength": cfg.um(cfg.COUPLING_LENGTH_UM),
                "SecondLeadLength": cfg.um(100.0),
                "GroundBuffer": cfg.um(cfg.COUPLING_SPACE_UM),
                "Fillet": cfg.um(cfg.FILLET_UM),
                "SecondOpenTermination": cfg.yes_no(True),
            },
        )
        placed[f"CLT{i}"] = inst
    return placed


def place_caps(layout: Any) -> dict[str, Any]:
    """Interdigital DC-block / Purcell caps on the feedline."""
    placed: dict[str, Any] = {}
    placed["Cap_input"] = place_pcell(
        layout,
        "Q_CapacitorNInterdigital",
        cfg.CAP_IN_POS,
        name="Cap_input",
        angle=0.0,
    )
    placed["Cap_output"] = place_pcell(
        layout,
        "Q_CapacitorNInterdigital",
        cfg.CAP_OUT_POS,
        name="Cap_output",
        angle=90.0,
    )
    return placed


def place_feedline(layout: Any) -> list[Any]:
    """One continuous multiplexed readout bus from LP_W3 to LP_N1."""
    return place_polyline_cpw(
        layout,
        cfg.feed_path(),
        name_prefix="Feed",
        draw_bridges=False,
    )


def place_resonators(layout: Any) -> dict[str, Any]:
    """Meander resonators from each qubit north claw up to its CLT."""
    placed: dict[str, Any] = {}
    for i in range(cfg.N_QUBITS):
        x = cfg.qubit_x(i)
        y0 = cfg.QUBIT_Y_MM + (
            cfg.CROSS_ARM_LENGTH_UM + cfg.CLAW_LENGTH_UM + 20.0
        ) / 1000.0
        # Leave a short gap under the CLT for a stub into the coupler secondary
        y1 = cfg.CLT_Y_MM - 0.18
        span_um = max((y1 - y0) * 1000.0, 400.0)
        y_jog_um = 60.0 if (i % 2 == 0) else -60.0

        inst = place_pcell(
            layout,
            "Q_CpwMeander",
            (x, y0),
            name=f"ReadoutRes{i}",
            angle=90.0,
            params={
                "W": cfg.um(cfg.CPW_W_UM),
                "Gap": cfg.um(cfg.CPW_GAP_UM),
                "L": cfg.um(cfg.RESONATOR_LENGTHS_UM[i]),
                "Spacing": cfg.um(cfg.RESONATOR_SPACING_UM),
                "Radius": cfg.um(cfg.FILLET_UM),
                "LeadLength": cfg.um(cfg.RESONATOR_LEAD_UM),
                "Pin1Orientation": "horizontal",
                "Pin2Orientation": "horizontal",
                "XOffset": cfg.um(span_um),
                "YOffset": cfg.um(y_jog_um),
                "VerticalShift": cfg.um(0.0),
                "DrawBridges": cfg.yes_no(False),
            },
        )
        placed[f"ReadoutRes{i}"] = inst

        # Stub: meander top → CLT secondary (continuous path, no extra pins)
        # After 90° rotation, pin2 ≈ (x - jog, y0 + span)
        jog_mm = y_jog_um / 1000.0
        meander_top = (x - jog_mm, y0 + span_um / 1000.0)
        clt_port = (x, cfg.CLT_Y_MM - 0.08)
        place_polyline_cpw(
            layout,
            [meander_top, (x, meander_top[1]), clt_port],
            name_prefix=f"ResStub{i}",
            draw_bridges=False,
        )
    return placed


def place_readout(layout: Any) -> dict[str, Any]:
    """Place full multiplexed readout subsystem."""
    placed: dict[str, Any] = {}
    placed.update(place_launchpads(layout))
    placed.update(place_couplers(layout))
    placed.update(place_caps(layout))
    placed["_feed"] = place_feedline(layout)
    placed.update(place_resonators(layout))
    print("Placed launchpads, CLTs, caps, feedline, and meander resonators.")
    return placed
