# About GloFAS — What the Data Is and How It Works

A plain-language reference for the GloFAS-ERA5 dataset used in this project.

---

## What is GloFAS?

**GloFAS** = the **Global Flood Awareness System**, run by ECMWF and the EU's Copernicus
Emergency Management Service. It is a global flood-monitoring and forecasting service.

The product we use is **GloFAS-ERA5**, its *historical reanalysis*: a physically-modeled estimate
of how much water is in every river on Earth, **every day from 1979 to near-present**. Think of it
as **"modeled gauge data, everywhere"** — including places with no real river gauges, like the
Sylhet basin in Bangladesh.

It is a **model product, not observations** — useful as physically-consistent context and as a
validation proxy, but not ground truth.

---

## How it works (three steps)

GloFAS turns weather into river flow in three stages: **replay the weather → soak the ground →
route the water downhill.**

```
 1. WEATHER              2. LAND SURFACE (the sponge)      3. RIVER ROUTING (the plumbing)
 ERA5 reanalysis   ──>   HTESSEL soil/snow model     ──>  LISFLOOD river network
 45+ years of real       how much rain soaks in,           where the overflow goes and
 daily weather           evaporates, or runs off           how long it takes to arrive
                                │                                   │
                                ▼                                   ▼
                         SOIL MOISTURE / SWI               RIVER DISCHARGE (dis24)
```

1. **Replay the weather.** ERA5 reconstructs the actual historical weather (rain, snow,
   temperature) for every ~30 km cell, every day, back to 1979. GloFAS inherits this rainfall — it
   doesn't invent it.

2. **The sponge (→ soil moisture).** Each grid cell has a layered soil column that acts like a
   sponge. Rain either evaporates, soaks in (filling the pore space), or — when the sponge is full
   or the rain too fast — **drains away as runoff**. The **Soil Wetness Index** is "how full is the
   sponge," from 0 (dry) to 1 (saturated). A saturated sponge converts almost all new rain to
   runoff — which is why antecedent wetness drives flash floods.

3. **The plumbing (→ discharge).** Runoff alone isn't a flood — it has to collect. LISFLOOD routes
   each cell's runoff downhill through a pre-mapped river network: small streams feed big ones,
   water takes hours to days to travel, groundwater drains slowly, and ~1,100 lakes/reservoirs
   store and release along the way. The result, **discharge**, is "how many cubic meters per second
   flow through this river cell today," summed over everything upstream. That's why the Brahmaputra
   reads ~90,000 m³/s while a small stream reads ~200.

**One sentence:** *GloFAS replays 45 years of real weather over a global soil model — what the soil
can't absorb becomes runoff — then routes that runoff downhill through the river network, giving a
daily estimate of soil wetness for every cell and discharge for every river on Earth.*

---

## The three variables we use

| Variable | Short name | Units | Meaning |
|---|---|---|---|
| River discharge (24-h) | `dis24` | m³ s⁻¹ | 24-h mean water flow through the river channel |
| Runoff water equivalent | `rowe` | kg m⁻² (≡ **mm/day**) | 24-h total water draining off the grid cell |
| Soil wetness index | `swir` | dimensionless 0–1 | root-zone wetness (0 dry → 1 saturated), instantaneous |

Note: runoff in `mm/day` is directly comparable to rainfall (CHIRPS/IMERG), so `runoff ≤ rainfall`
is a built-in mass-conservation check.

---

## Resolution & coverage

| Property | Value |
|---|---|
| Time step | **daily** |
| Grid | **0.05° × 0.05° (~5 km)** in v4.0 (0.1° / ~11 km in ≤ v3.1 and the 2020 paper) |
| Coverage | global 90°N–60°S (excludes Antarctica), **1979 → near-present** |
| Product streams | `consolidated` (final, ~monthly latency) · `intermediate` (2–5 days behind) |
| Formats | NetCDF-4 or GRIB2 |

---

## How good is it? (skill & caveats)

From Harrigan et al. (2020):

- Positive skill in **86%** of tested catchments (modified Kling–Gupta efficiency).
- **Skill scales with catchment size** — median KGE′ rises to 0.56 for catchments > 50,000 km².
  → Strong on the Brahmaputra/Meghna; weak on small catchments (e.g. Guadalupe at Hunt ~750 km²).
- **Low-biased** in ~64% of catchments (median bias ratio 0.84) → trust *timing* and *relative
  anomalies* more than absolute magnitudes unless bias-corrected.
- Simplified reservoir rules; occasional ERA5 rainfall artifacts; discontinuities that complicate
  long-term trend analysis.

---

## Access

- Portal: Copernicus **Early Warning Data Store** — dataset `cems-glofas-historical`.
- Free, via the Python `cdsapi` client (register, accept the CEMS-FLOODS licence, add token to
  `~/.cdsapirc`). See `README.md` for setup.
- **DOI:** 10.24381/cds.a4fdd6b9
- **Paper:** Harrigan, S., et al. (2020). *GloFAS-ERA5 operational global river discharge
  reanalysis 1979–present.* Earth System Science Data, 12(3), 2043–2060.
  doi:10.5194/essd-12-2043-2020

---

## Why we use it in this project

1. **Gauge proxy** — a model-based discharge/stage series where Bangladesh lacks accessible gauges
   (the way USGS gauges validated the Texas case study).
2. **MC-LSTM input channel** — discharge + runoff + soil wetness encode the basin's hydrological
   memory and flux state.
3. **Shared currency** — the same GloFAS fields feed Fahad's CFM subseasonal framework, keeping the
   team's workstreams (Fahad / Nadim / Noshin) interoperable.
