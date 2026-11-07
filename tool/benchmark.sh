#!/usr/bin/env bash
# Runs the profile-mode feed benchmark on a connected Android device for each
# preload radius.
#
#   tool/benchmark.sh <device-id> [radius ...]     (default radii: 0 1 2)
#
# Memory is sampled for the app and for the codec processes, because Android
# decodes video in media.codec (hardware) and audio in media.swcodec, so the
# app's own PSS would miss part of what an extra player costs. The app itself
# reports bytes received during the swipes (Android TrafficStats).
#
# Output in benchmark_output/:
#   radius<N>_<time>.json   start-up, init and network numbers from the app
#   radius<N>_mem.txt       PSS in KB every 2 s
#
# Summarise with: dart run tool/summarize_benchmarks.dart benchmark_output
set -uo pipefail

device="${1:?usage: tool/benchmark.sh <device-id> [radius ...]}"
shift
radii=("$@")
[[ ${#radii[@]} -eq 0 ]] && radii=(0 1 2)
pkg="com.raghavverma.short_video_feed"
mkdir -p benchmark_output

pss_of() { # <pid> -> TOTAL PSS in KB
  adb -s "$device" shell dumpsys meminfo "$1" 2>/dev/null | awk '/TOTAL PSS:/ {print $3; exit}'
}

for radius in "${radii[@]}"; do
  echo "== preload radius $radius"
  mem_log="benchmark_output/radius${radius}_mem.txt"
  echo "time app_kb app_graphics_kb media_codec_kb media_swcodec_kb" > "$mem_log"
  (
    codec=$(adb -s "$device" shell pidof media.codec | tr -d '\r')
    swcodec=$(adb -s "$device" shell pidof media.swcodec | tr -d '\r')
    while true; do
      app=$(adb -s "$device" shell dumpsys meminfo "$pkg" 2>/dev/null \
        | awk '/TOTAL PSS:/ {t=$3} /^ +Graphics:/ {g=$2} END {if (t) print t, g}')
      if [[ -n "$app" ]]; then
        echo "$(date +%s) $app $(pss_of "$codec") $(pss_of "$swcodec")" >> "$mem_log"
      fi
      sleep 2
    done
  ) &
  sampler=$!
  flutter drive --profile \
    --driver=test_driver/integration_test.dart \
    --target=integration_test/feed_benchmark_test.dart \
    --dart-define=PRELOAD_RADIUS="$radius" \
    -d "$device"
  kill "$sampler" 2>/dev/null
  wait "$sampler" 2>/dev/null
  awk 'NR > 1 {
         if ($2 > a) a = $2; if ($3 > g) g = $3; if ($4 > c) c = $4; if ($5 > s) s = $5
         if ($2 + $4 + $5 > t) t = $2 + $4 + $5
       }
       END {printf "max PSS MB: app %.0f (graphics %.0f), media.codec %.0f, media.swcodec %.0f, app+codecs %.0f\n",
            a/1024, g/1024, c/1024, s/1024, t/1024}' "$mem_log"
done
