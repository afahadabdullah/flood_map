# Flood-Data Handoff — Bangladesh + NE India

**From:** Saiful Islam Apu (KU Geology) · **To:** Abdullah Al Fahad, Nadim, Noshin
**Re:** the analysis-ready flood cube — what is in it, how to rebuild it, and what to trust in it.
**Scope note:** this is our short-term PIML / event-validation data. It shares sources with Fahad's
CFM subseasonal framework (GloFAS, ERA5, MERIT, Tellman flood DB), so the cube below drops straight
into the `(batch, time, channels, lat, lon)` tensor convention.

---

## 1. Region & grid (common to all data)

| Property | Value |
|---|---|
| Domain | Bangladesh + NE India, box **[N 27.5, W 87.0, S 21.0, E 94.0]** |
| Why this box | includes Meghalaya/Assam — the upstream source of the NE Bangladesh floods |
| Grid | **0.05° × 0.05° (~5 km)**, GloFAS v4.0 |
| Grid size | **130 lat × 140 lon** cells |
| Time step | **daily** |
| Product | GloFAS-ERA5, `cems-glofas-historical`, `version_4_0`, `consolidated` |
| Source | Copernicus EWDS · Harrigan et al. (2020) ESSD · DOI 10.24381/cds.a4fdd6b9 |

---

## 2. Data types (variables)

Three dynamic variables, all daily on the grid above:

| Channel | GloFAS var | Units | Meaning | Role in ML |
|---|---|---|---|---|
| **discharge** | `dis24` | m³ s⁻¹ | 24-h mean river discharge through the channel | target / validation proxy |
| **runoff** | `rowe` | kg m⁻² (≡ **mm/day**) | 24-h total surface + sub-surface runoff leaving the cell | flux input; rainfall-comparable → mass-conservation check |
| **soil_wetness** | `swir` | dimensionless 0–1 | instantaneous root-zone wetness (0 dry → 1 saturated) | antecedent state / hydrological memory |

Note: runoff in `mm/day` is directly comparable to CHIRPS/IMERG rainfall, so `runoff ≤ rainfall`
gives a built-in conservation diagnostic.

---

## 3. Temporal timeline

### (a) What this repository holds today
One window, complete and analysis-ready:

| Window | Steps | Variables | Purpose |
|---|---|---|---|
| **2022-05-01 … 2022-08-31** | 123 daily | discharge + runoff + SWI, plus MODIS flood labels | the Sylhet/Sunamganj monsoon, driver **and** label on one grid |

The multi-year discharge pulls (2020–2025) sit in the earlier GEE/GloFAS exploration folder, not
here. This repo deliberately holds one window carried all the way through to a labelled cube.

### (b) Flood-event catalogue this data targets (2020–2025)
| Year | Window | Event |
|---|---|---|
| 2020 | late Jun – Aug | prolonged monsoon; Jamuna basin (longest since 1988) |
| 2021 | late Jun – Jul | localized NE flash floods |
| 2022 | mid-May; **14–25 Jun** | NE catastrophe — Sylhet & Sunamganj submerged |
| 2023 | May; **Aug** | mid-monsoon haor-basin deluge |
| 2024 | late May; Jun; **20–28 Aug** | Feni–Comilla–Noakhali flash flood |
| 2025 | **15–31 May** | early-monsoon crisis, NE & SE districts |

(Coastal-surge events — Amphan/Mocha/Remal — are out of scope for river discharge.)

---

## 4. ML-ready data structure

The pipeline (`01_download_process.ipynb`) turns a downloaded window into a standardized cube:

```
cube shape:  (time, channel, lat, lon)  =  (days, 3, 130, 140)
channels:    [discharge, runoff, soil_wetness]   # fixed order
normalized:  per-channel standardize (mean 0, std 1); stats saved to invert
```

Batch over samples/windows → **`(batch, time, channel, lat, lon)`** — matches Fahad's CFM/U-Net input.

Artifacts written per window (in `data/interim/glofas_ready/`):

| File | Contents |
|---|---|
| `*_norm.nc` | standardized cube |
| `*_raw.nc` | same cube in physical units (m³/s, mm/day, 0–1) |
| `*_stats.json` | per-channel mean & std (de-normalize predictions) |
| `*_manifest.json` | window, region, shape, channels, source, citation |

---

## 4b. The flood labels, and the one thing to know before trusting them

Labels come from **MODIS MCDWD_L3 v061** (daily, 250 m, sinusoidal). Tiles `h25v06` **and**
`h26v06` are both required — sinusoidal tiles are trapezoids that lean east with latitude, so
`h26v06` alone covers 15,597 of the 18,200 cells and `h25v06` supplies the rest. `h27v06` lies
entirely east of the box. Notebook 05 mosaics them, crops to the ROI, and aggregates the 250 m
classes onto the GloFAS grid.

Two conventions that change how the labels must be used:

- **`flood_fraction` counts classes 2 and 3** — inundation beyond permanent water. The river
  channel itself is class 1 and therefore reads as not-flooded **by design**. Do not validate the
  labels by correlating them against discharge cell by cell; it returns a spurious negative.
- **No-data is never dry.** Class 255 (cloud or no overpass) is excluded from the numerator and the
  denominator both, and `valid_fraction` records what was actually seen.

**The limitation, stated plainly: 58% of label day-cells are `NaN`.** Usable coverage by month is
May 76%, June 42%, July 24%, August 26% — worst exactly when the flooding is worst. Drivers and
labels agree seasonally (ρ ≈ +0.55 for discharge at a 26-day lag) but first-differencing collapses
everything to noise (+0.09 to +0.21). There is agreement at seasonal scale and **no event-scale
signal**: daily flooded area largely records whether MODIS could see the ground. Training a daily
model on `flood_fraction` as it stands would substantially fit cloud.

Three ways out, none of them yet chosen: multi-day composites, weighting the loss by
`valid_fraction`, or moving the label to **Sentinel-1 SAR**, which sees through cloud.

---

## 4c. The analysis-ready cube

`data/processed/flood_cube_bd_ne_india_2022-05-01_to_2022-08-31.nc` (18 MB) — GloFAS and MODIS on
one grid, written by notebook 06, which **asserts** grid and time equality rather than reindexing,
so a changed ROI fails loudly instead of silently interpolating.

```python
import xarray as xr, numpy as np
ds = xr.open_dataset(nc, engine="h5netcdf")          # netCDF4 will not import in this env
X  = np.stack([ds[v].values for v in ("discharge","runoff","soil_wetness")], axis=1)  # (123,3,130,140)
y  = ds.flood_fraction.values                                                          # (123,130,140)
```

Variables: `discharge` (m³/s), `runoff` (mm/day), `soil_wetness` (0–1), `flood_fraction`,
`flood_binary` (`-1` = no data), `valid_fraction`. **Physical units throughout** — `norm_mean` and
`norm_std` ride as per-variable attributes so standardization happens at training time.

---

## 5. How to reproduce

```bash
conda env create -f config/environment.yml     # pyhdf needs conda-forge hdf4
conda activate sia
cd code                                        # so `from paths import ...` resolves
jupyter lab
```

Run the notebooks in `code/` in numeric order — 01, 02, 05, 06, 07. (03 and 04 are superseded and
live in `archive/`.) Every path is defined once in `code/paths.py`; nothing else hard-codes a
directory.

| Notebook | Does |
|---|---|
| `01_download_process` | GloFAS window → QC → `data/interim/glofas_ready/` |
| `02_visualize` | sanity-check maps, time series, distributions |
| `05_flood_labels_to_grid` | MODIS tiles → mosaic → ROI → GloFAS grid → `data/interim/flood_labels/` |
| `06_analysis_ready_cube` | merge into one NetCDF in `data/processed/` |
| `07_describe_visualize_cube` | variable table, mean-state maps, peak day, label-vs-driver lag check |

MODIS tiles come from `code/download_mcdwd_curl.sh` (needs `LAADS_TOKEN`; `-n` is a token-free dry
run). GloFAS needs an EWDS account: register at `ewds.climate.copernicus.eu`, accept the
CEMS-FLOODS licence, put the token in `~/.cdsapirc`.

**`data/raw/` is git-ignored** — the 2.6 GB of MODIS HDFs and the GloFAS zips are re-fetchable, so
a clone arrives without them but *with* `data/interim/` and `data/processed/`, cube included.

---

## 6. Open items / to discuss
- **Grid:** keep native 0.05°, or regrid to Fahad's 1 km CFM target?
- **Label definition:** does class 1 (permanent water) belong in the flood label, or stay out?
- **Rainfall is still missing.** The cube has GloFAS *runoff*, which is a model output, not observed
  rain — and the project's own framing puts rainfall as the primary driver. Add CHIRPS or GPM?
- **Cloud:** composites, `valid_fraction`-weighted loss, or Sentinel-1 SAR — and who takes SAR?
- Add ERA5-Land soil moisture alongside GloFAS SWI, or is SWI enough as the antecedent state?
- Train/test split for the shared event catalogue (leave-one-event-out vs chronological).
