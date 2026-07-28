"""Create / open an ADS workspace with Quantum Single-Layer technology."""

from __future__ import annotations

import shutil
from pathlib import Path
from typing import Any

from . import config as cfg

# keysight.ads.de is only available inside ADS / ADS Python.
try:
    import keysight.ads.de as de
    from keysight.ads.de import db_uu
except ImportError:  # pragma: no cover - imported only inside ADS
    de = None  # type: ignore
    db_uu = None  # type: ignore


def _require_ads() -> None:
    if de is None or db_uu is None:
        raise RuntimeError(
            "keysight.ads.de is not importable. Run this script from the ADS "
            "Python console (ADS 2026 Update2) with QuantumPro installed."
        )


def _copy_tech_template(lib_path: Path) -> None:
    """Install Quantum Single-Layer tech files into a new library directory."""
    src = cfg.TECH_TEMPLATE_DIR
    required = [
        "library.tech",
        "display.tech",
        "tech.db",
        "tech.subst",
        "materials.matdb",
    ]
    missing = [name for name in required if not (src / name).exists()]
    if missing:
        raise FileNotFoundError(
            f"Quantum tech template incomplete in {src}. Missing: {missing}"
        )
    for name in required:
        shutil.copy2(src / name, lib_path / name)

    cfg_path = lib_path / "eesof_lib.cfg"
    if not cfg_path.exists():
        cfg_path.write_text(
            f"DEFAULT_SUBSTRATE={cfg.LIBRARY_NAME}:tech\nDEFAULTS_DESIGNS=\n",
            encoding="utf-8",
        )


def ensure_workspace(
    workspace_parent: Path | None = None,
    *,
    recreate: bool = False,
) -> tuple[Any, Any, Any]:
    """Create or open the 5-qubit ADS workspace and library.

    Returns
    -------
    (workspace, library, layout_design)
        layout_design is a fresh/empty Chip_5Q layout cell ready for placement.
    """
    _require_ads()
    assert de is not None and db_uu is not None

    parent = Path(workspace_parent or cfg.WORKSPACE_PARENT)
    parent.mkdir(parents=True, exist_ok=True)
    wrk_path = parent / cfg.WORKSPACE_NAME
    lib_path = wrk_path / cfg.LIBRARY_NAME

    if recreate and wrk_path.exists():
        # Close if open, then delete
        try:
            if de.directory_is_workspace(str(wrk_path)):
                try:
                    de.close_workspace()
                except Exception:
                    pass
        except Exception:
            pass
        shutil.rmtree(wrk_path)

    if not wrk_path.exists():
        de.create_workspace(str(wrk_path))
        wrk = de.open_workspace(str(wrk_path))
        library = de.create_new_library(cfg.LIBRARY_NAME, str(lib_path))
        wrk.add_library(cfg.LIBRARY_NAME, str(lib_path), mode=de.LibraryMode.SHARED)
        try:
            library.setup_schematic_tech()
        except Exception as exc:
            print(f"Note: setup_schematic_tech: {exc}")
        _copy_tech_template(lib_path)
        # Prefer copying layout tech from the official Quantum example library
        try:
            _apply_tech_via_donor(library)
        except Exception as exc:
            print(f"Note: donor tech copy skipped ({exc}); using bundled tech_template.")
        # Re-open so tech.db / substrate are loaded
        try:
            de.close_workspace()
        except Exception:
            pass
        wrk = de.open_workspace(str(wrk_path))
        library = de.get_open_library(cfg.LIBRARY_NAME)
        if library is None:
            raise RuntimeError(
                f"Created workspace at {wrk_path} but could not open "
                f"{cfg.LIBRARY_NAME}. Open it manually in ADS and re-run."
            )
    else:
        wrk = de.open_workspace(str(wrk_path))
        library = de.get_open_library(cfg.LIBRARY_NAME)
        if library is None:
            raise RuntimeError(
                f"Workspace exists at {wrk_path} but library "
                f"{cfg.LIBRARY_NAME} is not open. Open the workspace in ADS first."
            )
        # Ensure tech files present (upgrade older workspaces)
        if not (lib_path / "library.tech").exists():
            _copy_tech_template(lib_path)

    layout = _get_or_create_layout(library)
    return wrk, library, layout


def _apply_tech_via_donor(library: Any) -> None:
    """Optional: copy layout tech from the extracted Single_Qubit example."""
    assert de is not None
    example_7z = (
        cfg.ADS_DIR / "examples" / "Quantum" / "Single_Qubit_Chip_wrk.7zads"
    )
    donor_root = cfg.WORKSPACE_PARENT / "_quantum_tech_donor"
    donor_lib_name = "Single_Qubit_Chip_lib"
    donor_lib_path = donor_root / "Single_Qubit_Chip_wrk" / donor_lib_name

    if not donor_lib_path.exists() and example_7z.exists():
        donor_root.mkdir(parents=True, exist_ok=True)
        seven = cfg.ADS_DIR / "bin" / "7za.exe"
        if seven.exists():
            import subprocess

            subprocess.run(
                [str(seven), "x", f"-o{donor_root}", str(example_7z), "-y"],
                check=False,
                capture_output=True,
            )

    if donor_lib_path.exists():
        try:
            donor = de.get_open_library(donor_lib_name)
            if donor is None:
                # Open donor via workspace add if possible
                wrk = de.active_workspace()
                wrk.add_library(
                    donor_lib_name, str(donor_lib_path), mode=de.LibraryMode.SHARED
                )
                donor = de.get_open_library(donor_lib_name)
            if donor is not None:
                library.create_layout_tech_from_library(donor, copy_tech=True)
                return
        except Exception as exc:
            print(f"Warning: could not copy tech from donor library: {exc}")

    # Last resort: standard ADS layers (Quantum PCells may warn)
    try:
        library.create_layout_tech_std_ads("millimeter", 10000, False)
        print(
            "Warning: fell back to standard ADS layout tech. "
            "Prefer Quantum Single-Layer Technology for QuantumPro PCells."
        )
    except Exception as exc:
        raise RuntimeError(
            "Unable to install Quantum Single-Layer technology. "
            "Create a workspace via File→New Workspace, choose "
            "'Quantum Technology Library' → 'Single-Layer Technology', "
            f"then re-run with recreate=False. Details: {exc}"
        ) from exc


def _get_or_create_layout(library: Any) -> Any:
    """Return a writable Chip_5Q layout, clearing any previous content."""
    assert de is not None and db_uu is not None
    lcv = f"{library.name}:{cfg.CELL_NAME}:{cfg.LAYOUT_VIEW}"

    if de.design_exists(lcv):
        try:
            from keysight.ads.de import db as ads_db

            mode = ads_db.DesignMode.APPEND
        except Exception:
            mode = "append"
        layout = db_uu.open_design(lcv, mode=mode)
        try:
            objs = list(layout.instances)
            if objs:
                layout.delete(objs)
        except Exception as exc:
            print(f"Note: could not clear existing instances ({exc}); continuing.")
        return layout

    return db_uu.create_layout(lcv)


def open_existing_layout(
    workspace_parent: Path | None = None,
) -> Any:
    """Open an existing Chip_5Q layout without recreating the workspace."""
    _require_ads()
    assert de is not None and db_uu is not None

    parent = Path(workspace_parent or cfg.WORKSPACE_PARENT)
    wrk_path = parent / cfg.WORKSPACE_NAME
    if not wrk_path.exists():
        raise FileNotFoundError(f"Workspace not found: {wrk_path}")

    de.open_workspace(str(wrk_path))
    lcv = f"{cfg.LIBRARY_NAME}:{cfg.CELL_NAME}:{cfg.LAYOUT_VIEW}"
    if not de.design_exists(lcv):
        raise FileNotFoundError(f"Layout not found: {lcv}")
    try:
        from keysight.ads.de import db as ads_db

        mode = ads_db.DesignMode.APPEND
    except Exception:
        mode = "append"
    return db_uu.open_design(lcv, mode=mode)
