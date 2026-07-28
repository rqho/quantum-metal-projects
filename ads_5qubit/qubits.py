"""Place Q0–Q4 Xmons and XY drive pads."""

from __future__ import annotations

from typing import Any

from . import config as cfg
from .place import place_pcell


def qubit_params() -> dict[str, str]:
    """ads_quantum Q_TransmonCross parameters matching Metal TransmonCrossFL."""
    return {
        "CrossThickness": cfg.um(cfg.CROSS_THICKNESS_UM),
        "CrossArmLength": cfg.um(cfg.CROSS_ARM_LENGTH_UM),
        "CrossGap": cfg.um(cfg.CROSS_GAP_UM),
        # North readout claw only; bare E/W arms for capacitive NN coupling
        "DrawTopConnector": cfg.yes_no(True),
        "DrawLeftConnector": cfg.yes_no(False),
        "DrawRightConnector": cfg.yes_no(False),
        "DrawBottomConnector": cfg.yes_no(False),
        "DrawAsClawTop": cfg.yes_no(True),
        "ConnectorLengthTop": cfg.um(cfg.CLAW_LENGTH_UM),
        "GroundBufferTop": cfg.um(cfg.CLAW_GROUND_SPACING_UM),
        "ConnectorThicknessTop": cfg.um(cfg.CLAW_WIDTH_UM),
        "ConnectorMainThicknessTop": cfg.um(cfg.CLAW_WIDTH_UM),
        "ConnectorGapTop": cfg.um(cfg.CLAW_GAP_UM),
        # Flux / Z line on bottom (junction arm)
        "DrawFluxLineConnector": cfg.yes_no(True),
        "DrawFluxLineConnectorAsL": cfg.yes_no(True),
        "FluxLineLocation": "bottom",
        "FluxLineWidth": cfg.um(cfg.FLUX_LINE_WIDTH_UM),
        "FluxLineLeadWidth": cfg.um(cfg.FLUX_LINE_LEAD_WIDTH_UM),
        "FluxLineHeight": cfg.um(cfg.FLUX_LINE_HEIGHT_UM),
        "FluxLineGap": cfg.um(cfg.FLUX_LINE_GAP_UM),
        "FluxLineGroundBuffer": cfg.um(cfg.FLUX_LINE_GROUND_BUFFER_UM),
    }


def place_qubits(layout: Any) -> dict[str, Any]:
    """Place five Q_TransmonCross instances and five XY Q_CpwLineOpen pads.

    Returns a dict of named instances for later routing helpers.
    """
    placed: dict[str, Any] = {}
    params = qubit_params()

    for i in range(cfg.N_QUBITS):
        x = cfg.qubit_x(i)
        q = place_pcell(
            layout,
            "Q_TransmonCross",
            (x, cfg.QUBIT_Y_MM),
            name=f"Q{i}",
            angle=0.0,
            params=params,
        )
        placed[f"Q{i}"] = q

        xy = place_pcell(
            layout,
            "Q_CpwLineOpen",
            (x + cfg.XY_OFFSET_X_MM, cfg.XY_Y_MM),
            name=f"XY_pad_{i}",
            angle=90.0,  # Metal OpenToGround orientation=90
            params={
                "W": cfg.um(cfg.XY_WIDTH_UM),
                "Gap": cfg.um(cfg.XY_GAP_UM),
                "EndGap": cfg.um(cfg.XY_END_GAP_UM),
                "L": cfg.um(cfg.XY_LENGTH_UM),
                "DrawBridges": cfg.yes_no(False),
                "EndPin": "yes",
            },
        )
        placed[f"XY_pad_{i}"] = xy

    print(f"Placed qubits Q0–Q{cfg.N_QUBITS - 1} and XY pads.")
    return placed
