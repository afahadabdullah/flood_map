# GloFAS Flood-Data Pipeline — Bangladesh + NE India

A small, reproducible pipeline for **GloFAS-ERA5** flood data over Bangladesh and NE India,
built for the PIML flood-prediction project (Saiful Islam Apu, University of Kansas — Geology).
It downloads a short window of river-discharge / runoff / soil-wetness data, cleans it, and
writes a machine-learning-ready cube — plus notebooks to visualize and explore multi-year
flood events.

**Collaborators:** Abdullah Al Fahad, Nadim, Noshin.

---

## What's here

### Pipeline notebooks (run in order)
1. **`01_download_process.ipynb`** — download a window → quality-control → write an ML-ready
   `(time, channel, lat, lon)` cube to `data_ready/`. Edit **Cell 1** to set the window
   (1 week – several months) or region, then Run All.
2. **`02_visualize.ipynb`** — load the cube and sanity-check it: mean-state maps, a **per-month
   map grid**, domain-mean time series, and raw-vs-standardized histograms.

### Docs
- `COLLABORATOR_HANDOFF.md` — data timeline, structure, and variable types (shareable summary).

---

## Setup

```bash
pip install "cdsapi>=0.7.7" xarray netcdf4 h5netcdf numpy pandas matplotlib
```

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

### ML-ready outputs (per window, in `data_ready/`)
| File | Contents |
|---|---|
| `*_norm.nc` | standardized `(time, channel, lat, lon)` cube — the ML input |
| `*_raw.nc` | same cube in physical units |
| `*_stats.json` | per-channel mean & std (to invert predictions) |
| `*_manifest.json` | window, region, shape, channels, source, citation |

---

## Notes
- **Cache-first:** downloads are reused, never re-requested — safe to re-run.
- Data folders (`data_raw/`, `data_ready/`) and credentials are **git-ignored** — regenerate by
  running `01_download_process.ipynb`.
- Train/test split and the model live in a later notebook (not yet included).
