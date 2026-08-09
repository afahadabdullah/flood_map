#!/bin/bash
# ==============================================================================
# download_mcdwd_curl.sh
#
# Downloads MCDWD_L3 HDF tiles from NASA LAADS DAAC. Same flags as
# download_mcdwd_tiles.sh, but uses curl (macOS has no wget) and refuses to
# keep a file that is not a real HDF.
#
# USAGE:
#   ./download_mcdwd_curl.sh -t TOKEN -y YEAR -d OUTPUT_DIR [-T "tile1 tile2"] [-s DOY] [-e DOY]
#
# OPTIONS:
#   -t TOKEN        LAADS bearer token (or set LAADS_TOKEN env var instead)
#   -y YEAR         Year to download (e.g. 2022)
#   -d OUTPUT_DIR   Files land in OUTPUT_DIR/YEAR/
#   -T "TILES"      Space-separated tiles in quotes (default: "h26v06")
#   -s START_DAY    First day-of-year (default: 1)
#   -e END_DAY      Last day-of-year (default: last day of year)
#   -n              Dry run: list what would be downloaded, fetch nothing
#   -h              Show this help
#
# EXAMPLE — 2022 May 1 (DOY 121) through Aug 31 (DOY 243):
#   export LAADS_TOKEN='paste_token_here'
#   ./download_mcdwd_curl.sh -y 2022 -d update/modis_hdf -T "h25v06 h26v06" -s 121 -e 243
#
# NOTES:
#   The directory listing is public, so -n needs no token; only the file
#   download does. A day that yields no file is reported at the end and makes
#   the script exit non-zero -- silence is never treated as success.
# ==============================================================================

set -uo pipefail

TOKEN="${LAADS_TOKEN:-}"
YEAR=""
OUTDIR=""
TILES_STR="h26v06"
START_DAY=1
END_DAY=""
DRY_RUN=0
BASE_URL="https://ladsweb.modaps.eosdis.nasa.gov/archive/allData/61/MCDWD_L3"
MIN_BYTES=100000          # anything smaller is an error page, not a tile

usage() { grep '^#' "$0" | sed -e 's/^# \{0,1\}//' -e '1,2d'; exit 1; }

while getopts ":t:y:d:T:s:e:nh" opt; do
    case "$opt" in
        t) TOKEN="$OPTARG" ;;
        y) YEAR="$OPTARG" ;;
        d) OUTDIR="$OPTARG" ;;
        T) TILES_STR="$OPTARG" ;;
        s) START_DAY="$OPTARG" ;;
        e) END_DAY="$OPTARG" ;;
        n) DRY_RUN=1 ;;
        h) usage ;;
        \?) echo "Error: invalid option -$OPTARG" >&2; usage ;;
        :)  echo "Error: option -$OPTARG requires an argument." >&2; usage ;;
    esac
done

[ -n "$YEAR" ]   || { echo "Error: year is required (-y)." >&2; exit 1; }
[ -n "$OUTDIR" ] || { echo "Error: output directory is required (-d)." >&2; exit 1; }
if [ -z "$TOKEN" ] && [ "$DRY_RUN" -eq 0 ]; then
    echo "Error: no token. Use -t TOKEN, or export LAADS_TOKEN, or re-run with -n for a dry run." >&2
    exit 1
fi

read -ra TILES <<< "$TILES_STR"
[ "${#TILES[@]}" -gt 0 ] || { echo "Error: no tiles specified." >&2; exit 1; }

if [ -z "$END_DAY" ]; then
    if [ $((YEAR % 400)) -eq 0 ] || { [ $((YEAR % 4)) -eq 0 ] && [ $((YEAR % 100)) -ne 0 ]; }; then
        END_DAY=366
    else
        END_DAY=365
    fi
fi

OUTDIR="${OUTDIR%/}/${YEAR}"
mkdir -p "$OUTDIR" || { echo "Error: could not create $OUTDIR" >&2; exit 1; }

# A real HDF4 file starts with 0e 03 13 01. An HTML error page does not.
is_hdf4() {
    [ -f "$1" ] || return 1
    [ "$(wc -c < "$1")" -ge "$MIN_BYTES" ] || return 1
    [ "$(od -An -N4 -tx1 "$1" | tr -d ' \n')" = "0e031301" ]
}

echo "=============================================="
echo "LAADS MCDWD_L3 downloader (curl)"
echo "Year:       ${YEAR}"
echo "Day range:  ${START_DAY} - ${END_DAY}"
echo "Tiles:      ${TILES[*]}"
echo "Output dir: ${OUTDIR}"
[ "$DRY_RUN" -eq 1 ] && echo "MODE:       dry run (no downloads)"
echo "=============================================="

n_ok=0; n_cached=0; n_fail=0; failed=()

for day in $(seq "$START_DAY" "$END_DAY"); do
    doy=$(printf "%03d" "$day")
    listing=$(curl -sSL --max-time 120 "${BASE_URL}/${YEAR}/${doy}/" 2>/dev/null)
    if [ -z "$listing" ]; then
        echo "[${doy}] FAIL  could not read directory listing"
        n_fail=$((n_fail+1)); failed+=("${doy}:listing")
        continue
    fi

    for tile in "${TILES[@]}"; do
        fname=$(printf '%s' "$listing" \
                | grep -oE "MCDWD_L3\.A${YEAR}${doy}\.${tile}\.061\.[0-9]+\.hdf" \
                | sort -u | head -1)
        if [ -z "$fname" ]; then
            echo "[${doy} ${tile}] FAIL  not listed in the archive for this day"
            n_fail=$((n_fail+1)); failed+=("${doy}:${tile}:missing")
            continue
        fi

        dest="${OUTDIR}/${fname}"
        if is_hdf4 "$dest"; then
            echo "[${doy} ${tile}] cached  ${fname}"
            n_cached=$((n_cached+1))
            continue
        fi
        if [ "$DRY_RUN" -eq 1 ]; then
            echo "[${doy} ${tile}] would download  ${fname}"
            n_ok=$((n_ok+1))
            continue
        fi

        # Download to a temp name; only a validated HDF is moved into place, so a
        # failed attempt can never poison the cache for later runs.
        tmp="${dest}.part"
        code=$(curl -sSL --max-time 900 -w '%{http_code}' \
                    -H "Authorization: Bearer ${TOKEN}" \
                    -o "$tmp" "${BASE_URL}/${YEAR}/${doy}/${fname}" 2>/dev/null)
        if [ "$code" = "200" ] && is_hdf4 "$tmp"; then
            mv "$tmp" "$dest"
            echo "[${doy} ${tile}] ok      ${fname} ($(( $(wc -c < "$dest") / 1000000 )) MB)"
            n_ok=$((n_ok+1))
        else
            size=$( [ -f "$tmp" ] && wc -c < "$tmp" || echo 0 )
            rm -f "$tmp"
            echo "[${doy} ${tile}] FAIL    http=${code} bytes=${size} (not an HDF -- check the token)"
            n_fail=$((n_fail+1)); failed+=("${doy}:${tile}:http${code}")
        fi
    done
done

echo "=============================================="
echo "downloaded ${n_ok}   already had ${n_cached}   failed ${n_fail}"
if [ "$n_fail" -gt 0 ]; then
    echo "failed: ${failed[*]}"
    exit 1
fi
echo "Done."
