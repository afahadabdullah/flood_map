# GloFAS Data Handoff — Bangladesh + NE India

**From:** Saiful Islam Apu (KU Geology) · **To:** Abdullah Al Fahad, Nadim, Noshin
**Re:** GloFAS-ERA5 data assembled for the flood-ML work — timeline, structure, and variable types.
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

### (a) Data coverage downloaded
| Set | Window | Variables | Purpose |
|---|---|---|---|
| Monsoon seasons | **2020–2025**, May–Oct each year | discharge | multi-year event survey |
| 2022 deep dive | **Apr–Aug 2022**, daily | discharge + runoff + SWI | Sylhet event, 3-channel cube |
| Aux bundles | Jun 2022, Aug 2024 | runoff + SWI | flash-flood anatomy |

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

Artifacts written per window (in `data_ready/`):

| File | Contents |
|---|---|
| `*_norm.nc` | standardized cube — **the ML input** |
| `*_raw.nc` | same cube in physical units (m³/s, mm/day, 0–1) |
| `*_stats.json` | per-channel mean & std (de-normalize predictions) |
| `*_manifest.json` | window, region, shape, channels, source, citation |

---

## 5. How to reproduce

Code bundle (this folder):
- `01_download_process.ipynb` — download → QC → ML-ready cube (edit Cell 1 for window/region)
- `02_visualize.ipynb` — sanity-check maps (incl. per-month grid), time series, distributions
- `glofas_exploration.ipynb`, `glofas_events_2020_2025.ipynb`, `glofas_2022_event_3vars.ipynb` — analysis
- `README.md` — setup

Access: register at `ewds.climate.copernicus.eu`, accept the CEMS-FLOODS licence, put token in
`~/.cdsapirc`, then Run All. Data folders are git-ignored — regenerate by running notebook 01.

---

## 6. Open items / to discuss
- Common grid: keep native 0.05° or regrid to Fahad's 1 km CFM target?
- Add ERA5-Land soil moisture alongside GloFAS SWI, or is SWI sufficient as the antecedent state?
- Train/test split for the shared event catalogue (leave-one-event-out vs chronological 2020–2024 / 2025).
- Task split across the team (Fahad / Nadim / Noshin) — who owns modeling, validation, data extension.
