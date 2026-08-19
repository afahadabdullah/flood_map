#!/bin/bash
# ==============================================================================
# download_mcdwd_tiles.sh
#
# Downloads MCDWD_L3 HDF tiles from NASA LAADS DAAC for a given year, set of
# tiles, and output directory.
#
# USAGE:
#   ./download_mcdwd_tiles.sh -t TOKEN -y YEAR -d OUTPUT_DIR [-T "tile1 tile2 ..."]
#
# OPTIONS:
#   -t TOKEN        LAADS bearer token (or set LAADS_TOKEN env var instead)
#   -y YEAR         Year to download (e.g., 2004)
#   -d OUTPUT_DIR   Directory to save downloaded .hdf files into
#   -T "TILES"      Space-separated list of tiles in quotes (default: "h26v06 h27v06")
#   -s START_DAY    First day-of-year to download (default: 1)
#   -e END_DAY      Last day-of-year to download (default: last day of year)
#   -h              Show this help message
#
# EXAMPLES:
#   ./download_mcdwd_tiles.sh -t "$LAADS_TOKEN" -y 2004 \
#       -d /home/cluster/Projects/Flood_Forecasting/Inundation_maps/images
#
#   ./download_mcdwd_tiles.sh -y 2004 -d ./images -T "h26v06 h27v06 h25v06"
#       (uses LAADS_TOKEN from environment since -t was not given)
#
# NOTE:
#   Token resolution order: -t flag > LAADS_TOKEN environment variable.
# ==============================================================================

set -uo pipefail

# --- DEFAULTS ---
TOKEN="${LAADS_TOKEN:-}"
YEAR=""
OUTDIR=""
TILES_STR="h26v06 h27v06"
START_DAY=1
END_DAY=""
BASE_URL="https://ladsweb.modaps.eosdis.nasa.gov/archive/allData/61/MCDWD_L3"

usage() {
    grep '^#' "$0" | sed -e 's/^#//' -e '1,2d'
    exit 1
}

# --- PARSE ARGUMENTS ---
while getopts ":t:y:d:T:s:e:h" opt; do
    case "$opt" in
        t) TOKEN="$OPTARG" ;;
        y) YEAR="$OPTARG" ;;
        d) OUTDIR="$OPTARG" ;;
        T) TILES_STR="$OPTARG" ;;
        s) START_DAY="$OPTARG" ;;
        e) END_DAY="$OPTARG" ;;
        h) usage ;;
        \?) echo "Error: Invalid option -$OPTARG" >&2; usage ;;
        :) echo "Error: Option -$OPTARG requires an argument." >&2; usage ;;
    esac
done

# --- VALIDATION ---
if [ -z "$TOKEN" ]; then
    echo "Error: No token provided. Use -t TOKEN or set the LAADS_TOKEN environment variable." >&2
    exit 1
fi

if [ -z "$YEAR" ]; then
    echo "Error: Year is required. Use -y YEAR." >&2
    exit 1
fi

if [ -z "$OUTDIR" ]; then
    echo "Error: Output directory is required. Use -d OUTPUT_DIR." >&2
    exit 1
fi

# Build the TILES array from the space-separated string
read -ra TILES <<< "$TILES_STR"

if [ "${#TILES[@]}" -eq 0 ]; then
    echo "Error: No tiles specified." >&2
    exit 1
fi

# Create a year-named subdirectory inside the given output directory
# e.g. -d /path/to/images -y 2004 -> /path/to/images/2004
OUTDIR="${OUTDIR%/}/${YEAR}"
mkdir -p "$OUTDIR" || { echo "Error: Could not create directory $OUTDIR" >&2; exit 1; }

# Determine last day of the year (365 or 366 for leap year) if not specified
if [ -z "$END_DAY" ]; then
    if [ $((YEAR % 400)) -eq 0 ] || ([ $((YEAR % 4)) -eq 0 ] && [ $((YEAR % 100)) -ne 0 ]); then
        END_DAY=366
    else
        END_DAY=365
    fi
fi

echo "=============================================="
echo "LAADS MCDWD_L3 Tile Downloader"
echo "Year:        ${YEAR}"
echo "Day range:   ${START_DAY} - ${END_DAY}"
echo "Tiles:       ${TILES[*]}"
echo "Output dir:  ${OUTDIR}"
echo "=============================================="

# --- SCRIPT LOGIC ---
pushd "$OUTDIR" > /dev/null || exit 1

for day in $(seq "$START_DAY" "$END_DAY"); do
    day_padded=$(printf "%03d" "$day")
    for tile in "${TILES[@]}"; do
        echo "Checking day ${day_padded}, tile ${tile}..."

        wget \
          --header "Authorization: Bearer ${TOKEN}" \
          --spider \
          --force-html \
          -r \
          -l1 \
          -A "MCDWD_L3.A${YEAR}${day_padded}.${tile}.061.*.hdf" \
          "${BASE_URL}/${YEAR}/${day_padded}/" 2>&1 | \
          grep -o 'https://[^[:space:]]*\.hdf' | \
          sort -u | \
          while read -r hdf_url; do
            filename=$(basename "$hdf_url")
            if [ ! -f "$filename" ]; then
                echo "Downloading: $filename"
                wget \
                  --header "Authorization: Bearer ${TOKEN}" \
                  -O "$filename" \
                  "$hdf_url"
            else
                echo "Skipping (already exists): $filename"
            fi
          done
    done
done

popd > /dev/null
echo "Done."
