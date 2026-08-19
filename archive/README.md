# Archive

Nothing in this folder is part of the pipeline. It is kept because it explains
how the working version got here, not because it runs.

| File | Why it is here |
|---|---|
| `03_Flood_Data_Processing_Visualization.ipynb` | Single-tile MODIS inspection. Writes no dataset. Superseded by `code/05_flood_labels_to_grid.ipynb`, which mosaics h25+h26 and puts the labels on the GloFAS grid. |
| `04_Flood_Interpolation_1km_grid.ipynb` | 250 m to 1 km mode coarsening, h26 only. Superseded by the same notebook, which aggregates straight onto the 0.05 deg grid. |
| `download_mcdwd_tiles.sh` | The original downloader. Needs `wget`, which macOS does not ship, and `wget -O` will happily save an HTML error page as `.hdf` and then skip it forever. Replaced by `code/download_mcdwd_curl.sh`. |
| `MCDWD_L3.A2004213.h26v06.061.2025270185011.hdf` | A stray tile from day 213 of **2004** — outside the study window, left over from an early download test. Safe to delete. |

The two notebooks still refer to the old `update/...` paths, on purpose: they are
a record of what was run at the time, not something to re-run.
