#!/usr/bin/env bash
# Runs the profile-mode feed benchmark on a connected Android device for each
# preload radius, sampling the app's PSS with dumpsys while it runs.
#
#   tool/benchmark.sh <device-id> [radius ...]     (default radii: 0 1 2)
#
# Output: benchmark_output/*.json from the app, plus *_pss.txt from dumpsys.
set -euo pipefail

device="${1:?usage: tool/benchmark.sh <device-id> [radius ...]}"
shift || true
radii=("${@:-0 1 2}")
pkg="com.raghavverma.short_video_feed"
mkdir -p benchmark_output

for radius in ${radii[@]}; do
  echo "== preload radius $radius"
  pss_log="benchmark_output/radius${radius}_pss.txt"
  : > "$pss_log"
  (
    while true; do
      # TOTAL PSS in KB, plus the Graphics row (texture and codec buffers).
      line=$(adb -s "$device" shell dumpsys meminfo "$pkg" 2>/dev/null \
        | awk '/TOTAL PSS:/ {print "total_kb=" $3} /^ +Graphics:/ {print "graphics_kb=" $2}' \
        | paste -sd' ' -)
      [[ -n "$line" ]] && echo "$(date +%s) $line" >> "$pss_log"
      sleep 2
    done
  ) &
  sampler=$!
  flutter drive --profile \
    --driver=test_driver/integration_test.dart \
    --target=integration_test/feed_benchmark_test.dart \
    --dart-define=PRELOAD_RADIUS="$radius" \
    -d "$device" || true
  kill "$sampler" 2>/dev/null || true
  echo "max PSS: $(awk -F'total_kb=' 'NF>1 {split($2,a," "); if (a[1]>m) m=a[1]} END {printf "%.0f MB\n", m/1024}' "$pss_log")"
done
