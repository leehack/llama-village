#!/bin/zsh
# usage: tool/run_selftest.sh <capture_dir> [max_seconds] [ENV=VAL ...]
# Runs the release app with the autoplay script and capture on, waits for
# it to quit by itself, and prints the self-test log lines.
A=${0:a:h:h}
APP=$A/build/macos/Build/Products/Release/LlamaVillage.app
out=${1:?capture dir}; secs=${2:-400}; shift 2
mkdir -p $out
LOG=$out/selftest.log
env VILLAGE_CAPTURE=1 VILLAGE_AUTOPLAY=1 VILLAGE_EXIT=1 VILLAGE_CAPTURE_DIR=$out VILLAGE_MS_PER_MINUTE=200 "$@" \
  $APP/Contents/MacOS/LlamaVillage > $LOG 2>&1 &
PID=$!
for i in $(seq 1 $secs); do
  kill -0 $PID 2>/dev/null || break
  /bin/sleep 1
done
if kill -0 $PID 2>/dev/null; then echo "still running after ${secs}s, killing"; kill $PID; fi
wait $PID; echo "exit code=$?"
grep -E "VILLAGE (MODELS|PLANS|AUTOPLAY|SHOT|FPS|SIM|CALLS|LINES|DASH|SHUTDOWN|EXIT|AUDIO (ready|played))|FAILED|rror" $LOG | head -60
