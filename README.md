# GloFAS Flood-Data Pipeline — Bangladesh + NE India

A small, reproducible pipeline for **GloFAS-ERA5** flood data over Bangladesh and NE India,
built for the PIML flood-prediction project (Saiful Islam Apu, University of Kansas — Geology).
It downloads a short window of river-discharge / runoff / soil-wetness data, cleans it, and
writes a machine-learning-ready cube — plus notebooks to visualize and explore multi-year
flood events.

**Collaborators:** Abdullah Al Fahad, Nadim, Noshin.

---

## Layout

```
code/       the pipeline — five notebooks, the downloader, and paths.py
config/     environment.yml
data/raw/         as downloaded, never edited (git-ignored)
    interim/      one regridded product per source
    processed/    the analysis-ready cube
docs/       ABOUT_GLOFAS.md, COLLABORATOR_HANDOFF.md
archive/    superseded notebooks and scripts, kept for the record
```

**Every path lives in `code/paths.py`** — no notebook hard-codes a directory, so the tree can be
moved or renamed without editing anything. Open the notebooks from inside `code/` so
`from paths import ...` resolves.

## What's here

### Pipeline notebooks (run in order)
1. **`01_download_process.ipynb`** — download a GloFAS window → quality-control → write an ML-ready
   `(time, channel, lat, lon)` cube to `data/interim/glofas_ready/`. Edit **Cell 1** to set the window
   (1 week – several months) or region, then Run All.
2. **`02_visualize.ipynb`** — load that cube and sanity-check it: mean-state maps, a **per-month
   map grid**, domain-mean time series, and raw-vs-standardized histograms.
3. **`05_flood_labels_to_grid.ipynb`** — MODIS MCDWD flood tiles → mosaic `h25v06`+`h26v06` → crop
   to the ROI → aggregate the 250 m classes onto the **GloFAS grid** → `data/interim/flood_labels/`.
4. **`06_analysis_ready_cube.ipynb`** — merge GloFAS + labels into **one** NetCDF in
   `data/processed/`. Asserts the grids match; never silently reindexes.
5. **`07_describe_visualize_cube.ipynb`** — what the file contains (variable table), mean-state
   maps, domain-mean time series, the peak-flood day, and the label-vs-driver lag check.

The numbering skips 03 and 04: those were the earlier single-tile MODIS explorations, neither of
which writes a dataset, and notebook 05 supersedes both. They now live in `archive/` — see
`archive/README.md` for why each file is there.

### Downloader
- **`code/download_mcdwd_curl.sh`** — fetches MCDWD tiles from LAADS. Validates every file (HDF4 magic
  bytes + size) before keeping it, so a failed download cannot poison the cache, and reports failed
  days instead of exiting silently. Needs `LAADS_TOKEN`; `-n` gives a token-free dry run.
  ```bash
  export LAADS_TOKEN='...'
  cd code
  ./download_mcdwd_curl.sh -y 2022 -d ../data/raw/modis_hdf -T "h25v06 h26v06" -s 121 -e 243
  ```
  `archive/download_mcdwd_tiles.sh` is the collaborator's original; it needs `wget`, which macOS
  lacks.

### Docs
- `docs/COLLABORATOR_HANDOFF.md` — what the cube is, how to open it, and what to trust in it.
- `docs/ABOUT_GLOFAS.md` — background on the GloFAS product itself.

---

## Setup

```bash
conda env create -f config/environment.yml
conda activate sia
```

`pyhdf` needs the conda-forge `hdf4` library, which a base anaconda install does not carry, so the
environment file is the supported route rather than a bare `pip install`.

**Credentials** (only needed to download new data):
1. Register at <https://ewds.climate.copernicus.eu> and copy your Personal Access Token.
2. Accept the *CEMS-FLOODS licence* once on the
   [dataset page](https://ewds.climate.copernicus.eu/datasets/cems-glofas-historical?tab=download).
3. Create `~/.cdsapirc`:
   ```
   url: https://ewds.climate.copernicus.eu/api
   key: <your-token>
   ```

> Note: this project's environment reads/writes NetCDF via the **`h5netcdf`** engine (the `netCDF4`
> build can clash with NumPy 2.x). The notebooks handle this automatically.

---

## Data

**GloFAS-ERA5 v4.0** — daily, **0.05° (~5 km)**, box **[N 27.5, W 87.0, S 21.0, E 94.0]**
(Bangladesh + NE India, incl. Meghalaya/Assam). Three variables:

| Channel | Units | Meaning |
|---|---|---|
| river discharge (`dis24`) | m³/s | 24-h mean channel flow |
| runoff water equivalent (`rowe`) | kg/m² (≡ mm/day) | 24-h total runoff leaving the cell |
| soil wetness index (`swir`) | 0–1 | root-zone wetness (antecedent state) |

Source: Copernicus EWDS, `cems-glofas-historical`. Harrigan et al. (2020), *ESSD*;
DOI 10.24381/cds.a4fdd6b9.

### GloFAS outputs (per window, in `data/interim/glofas_ready/`)
| File | Contents |
|---|---|
| `*_norm.nc` | standardized `(time, channel, lat, lon)` cube |
| `*_raw.nc` | same cube in physical units |
| `*_stats.json` | per-channel mean & std (to invert predictions) |
| `*_manifest.json` | window, region, shape, channels, source, citation |

**MODIS MCDWD_L3 v061** — daily flood classification, 250 m, sinusoidal tiles. Tiles `h25v06` +
`h26v06` are both required: sinusoidal tiles are trapezoids that lean east with latitude, so
`h26v06` alone leaves the north-west of the box uncovered (it reaches 15,597 of 18,200 cells;
`h25v06` supplies the other 2,603). `h27v06` lies entirely east of the ROI. Source classes are
`0` no water, `1` reference (permanent) water, `2` recurring flood, `3` flood, `255` no observation.

---

## The analysis-ready NetCDF

**`data/processed/flood_cube_bd_ne_india_<start>_to_<end>.nc`** — everything on one grid,
written by notebook 06. This is the file to hand to a model or a collaborator.

```
dims        time: 123 · latitude: 130 · longitude: 140
grid        0.05°, lat 27.475 → 21.025 (descending), lon 87.025 → 93.975
time        daily, 2022-05-01 … 2022-08-31
```

| Variable | Units | dtype | Source | Meaning |
|---|---|---|---|---|
| `discharge` | m³ s⁻¹ | float32 | GloFAS v4.0 | 24-h mean channel flow |
| `runoff` | mm day⁻¹ | float32 | GloFAS v4.0 | 24-h runoff leaving the cell |
| `soil_wetness` | – | float32 | GloFAS v4.0 | root-zone wetness, 0–1 |
| `flood_fraction` | – | float32 | MODIS MCDWD | share of the cell's **valid** 250 m pixels classed as flood; `NaN` where too few pixels were observed |
| `flood_binary` | flag | int8 | MODIS MCDWD | `1` flooded, `0` not, **`-1` no data** |
| `valid_fraction` | – | float32 | MODIS MCDWD | share of the cell's pixels that carried a valid observation |

**Conventions worth knowing before you use it:**

- **Physical units throughout.** Standardization is a modelling choice, so each GloFAS variable
  carries `norm_mean` / `norm_std` as attributes — apply them at training time rather than baking
  them into the file.
- **No-data is never dry.** MCDWD `255` (cloud / no overpass) is excluded from both the numerator
  and the denominator of `flood_fraction`. Folding it into `0` would teach a model that cloud means
  no flood, which in a monsoon is exactly backwards.
- **`flood_fraction` counts classes 2 and 3**, i.e. inundation *beyond* permanent water. The river
  channel itself is class 1 and reads as not-flooded by design — so do not validate the labels by
  correlating them against discharge cell by cell (see notebook 07).
- **Read it with the `h5netcdf` engine.**
  ```python
  ds = xr.open_dataset(nc, engine="h5netcdf")
  X  = np.stack([ds[v].values for v in ("discharge","runoff","soil_wetness")], axis=1)  # (T,3,H,W)
  y  = ds.flood_fraction.values                                                          # (T,H,W)
  ```

**Known limitation — label coverage.** 58% of label day-cells are `NaN`, and coverage swings between
0 and 0.8 from one day to the next as monsoon cloud comes and goes. Drivers and labels agree at
seasonal scale (ρ ≈ +0.5 at a lag of a few weeks) but show no event-scale relationship once that
shared trend is differenced out. Day-scale training on `flood_fraction` as-is would largely fit
cloud. Mitigations: multi-day composites, weight the loss by `valid_fraction`, or move the label to
Sentinel-1 SAR.

---

## Notes
- **Cache-first:** downloads are reused, never re-requested — safe to re-run.
- `data/raw/` and credentials are **git-ignored**. The MODIS HDFs (2.6 GB) come back from
  `code/download_mcdwd_curl.sh`, the GloFAS zips from notebook 01. `data/interim/` and
  `data/processed/` are small enough to track, so a clone arrives with the cube already in it.
- Train/test split and the model live in a later notebook (not yet included).
