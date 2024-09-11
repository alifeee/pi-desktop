#!/bin/bash
# get upcoming programs for a BBC TV channel
# https://gist.github.com/alifeee/acf55f9141f534e90eabbb7fceffaf44
# i.e., from the links
#  https://www.bbc.co.uk/iplayer/guide/bbcone
#  https://www.bbc.co.uk/iplayer/guide/bbctwo
#  https://www.bbc.co.uk/iplayer/guide/bbcthree
#  https://www.bbc.co.uk/iplayer/guide/bbcfour
# requires:
#  pcregrep, jq
#  sudo apt install pcregrep jq
# examples:
#  ./guide.sh
#  ./guide.sh bbctwo
# debug commands
# get current program as json
#  cat guide.json | jq '.schedule.items[] | select(.type=="LIVE")'
# get next program as json
#  cat guide.json | jq '.schedule.items | (map(.type) | index("LIVE")) as $i | .[$i + 1]'

bar () {
    # $1 $2 $3 are progress total total_segments
    # shows progress/total using total_segments characters
    if [ $1 == "0" ] && [ $2 == "0" ]; then
        awk -v TOTSEG=$3 'BEGIN {
            for (s = 0; s < TOTSEG; s++) {
                printf "%s", "░";
            }
        }'
    else
        awk -v prog=$1 -v TOTAL=$2 -v TOTSEG=$3 'BEGIN {
            frac = prog / TOTAL;
            segs = frac * TOTSEG;
            segs_int = int(sprintf("%.0f", segs));
            for (s=0; s<segs_int; s++) {
                printf "%s", "█";
            }
            for (s=0; s<(TOTSEG - segs_int); s++) {
                printf "%s", "░";
            }
        }'
    fi
}

if [ -z "$1" ]; then
  echo "no channel set, defaulting to BBC ONE..."
  channel="bbcone"
else
  channel=$1
fi

if [ $channel == "bbcone" ]; then
  title="BBC ONE"
  url="https://www.bbc.co.uk/iplayer/guide/bbcone"
elif [ $channel == "bbctwo" ]; then
  title="BBC TWO"
  url="https://www.bbc.co.uk/iplayer/guide/bbctwo"
elif [ $channel == "bbcthree" ]; then
  title="BBC THREE"
  url="https://www.bbc.co.uk/iplayer/guide/bbcthree"
elif [ $channel == "bbcfour" ]; then
  title="BBC FOUR"
  url="https://www.bbc.co.uk/iplayer/guide/bbcfour"
else
  echo "no guide programmed for ${channel}"
  exit 1
fi

echo "getting guide..."

guide_page=$(curl -s "${url}")

if [ -z "$guide_page" ]; then
  echo "no guide found"
  exit 1
fi

echo "finding json..."
guide_json_raw=$(echo "${guide_page}" | pcregrep --buffer-size=100000 -o1 '<script[^>]*id="tvip-script-app-store"[^>]*>.*?({.*?});<\/script>')

if [ -z "$guide_json_raw" ]; then
  echo "no json found in page"
  exit 1
fi

echo "parsing json..."
guide_json=$(echo "${guide_json_raw}" | jq)
if [ -z "$guide_json" ]; then
  echo "error parsing json"
  exit 1
fi

echo "saving guide to guide.json..."
echo "${guide_json}" > guide.json

info() {
  # $1 is schedule info as json
  # $2 is padding
  title=$(echo "$1" | jq -r '.props.title')
  subtitle=$(echo "$1" | jq -r '.props.subtitle')
  synopsis=$(echo "$1" | jq -r '.props.synopsis')
  progress=$(echo "$1" | jq -r '.props.progressPercent // empty')
  start_time=$(echo "$1" | jq -r '.meta.scheduledStart')
  end_time=$(echo "$1" | jq -r '.meta.scheduledEnd')
  if [ -z "$2" ]; then
    p="  "
  else
    p="$2"
  fi
  printf "%s%s - %s\n" "$p" "$(date -d "${start_time}" "+%H:%M")" "$(date -d "${end_time}" "+%H:%M")"
  printf "%s%s\n" "$p" "$title"
  printf "%s%s\n" "$p" "$subtitle"
  printf "%s%s\n" "$p" "$synopsis"
  if [ ! -z "$progress" ]; then
    printf "%s%s %s%%\n" "$p" "$(bar $progress 100 40)" "$progress"
  else
    printf "%s%s %s%%\n" "$p" "$(bar 0 100 40)" "0"
  fi
}

echo "${title}"

echo "  LIVE:"
live_json=$(echo "${guide_json}" | jq '.schedule.items[] | select(.type=="LIVE")')
info "${live_json}" "    "

echo "  NEXT:"
next_json=$(echo "${guide_json}" | jq '.schedule.items | (map(.type) | index("LIVE")) as $i | .[$i + 1]')
info "${next_json}" "    "

echo "  OVERNEXT:"
overnext_json=$(echo "${guide_json}" | jq '.schedule.items | (map(.type) | index("LIVE")) as $i | .[$i + 2]')
info "${overnext_json}" "    "
