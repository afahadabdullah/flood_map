"""
Single source of truth for every path in this project.

No notebook hard-codes a directory. ROOT comes from this file's own location,
so the whole tree can be moved or renamed without editing anything.

    from paths import MODIS_HDF, GLOFAS_RAW, GLOFAS_READY, FLOOD_LABELS, PROCESSED

Open the notebooks from inside `code/` so this import resolves.
"""

from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent

CODE   = ROOT / "code"
CONFIG = ROOT / "config"
DOCS   = ROOT / "docs"
DATA   = ROOT / "data"

RAW       = DATA / "raw"        # as downloaded, never edited (git-ignored)
INTERIM   = DATA / "interim"    # regridded, still one product per source
PROCESSED = DATA / "processed"  # the analysis-ready cube

MODIS_HDF     = RAW / "modis_hdf"          # MCDWD_L3 250 m tiles, <year>/ inside
GLOFAS_RAW    = RAW / "glofas_raw"         # EWDS zips
GLOFAS_READY  = INTERIM / "glofas_ready"   # _raw.nc, _norm.nc, _stats.json, _manifest.json
FLOOD_LABELS  = INTERIM / "flood_labels"   # MODIS classes on the GloFAS grid

for _d in (GLOFAS_RAW, GLOFAS_READY, FLOOD_LABELS, PROCESSED):
    _d.mkdir(parents=True, exist_ok=True)

if __name__ == "__main__":
    print(f"ROOT  {ROOT}")
    for name in ("MODIS_HDF", "GLOFAS_RAW", "GLOFAS_READY", "FLOOD_LABELS", "PROCESSED"):
        p = globals()[name]
        n = len(list(p.rglob("*"))) if p.exists() else 0
        print(f"  {name:<13} {p.relative_to(ROOT)}  ({n} files)")
