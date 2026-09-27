#!/usr/bin/env bash
# Profile the installed Float Frame flatpak: startup latency (launch → KWin shows
# the window), then CPU% / RSS / threads sampled while playing and while paused
# (paused via MPRIS). Usage: scripts/perf.sh <app-id> <video> [mpris-name]
# Only the given app id is launched and killed; nothing else is touched.
set -u
APP=${1:?app id}; VIDEO=${2:?video}; MPRIS=${3:-floatframe}
if flatpak ps --columns=application 2>/dev/null | grep -q "$APP"; then
    echo "$APP is already running; refusing (cleanup would close that window too)" >&2
    exit 3
fi
JS=$(mktemp /tmp/ff-perf-XXXX.js)
cat > "$JS" <<'JSEOF'
const w = workspace.windowList().filter(w => /perf-720p/.test(w.caption));
console.error("FF-PERF windows=" + w.length + (w.length ? " frame=" + w[0].frameGeometry.width + "x" + w[0].frameGeometry.height : ""));
JSEOF
win_visible() {
    local id; id=$(busctl --user call org.kde.KWin /Scripting org.kde.kwin.Scripting loadScript s "$JS" | awk '{print $2}')
    busctl --user call org.kde.KWin "/Scripting/Script$id" org.kde.kwin.Script run >/dev/null
    sleep 0.05
    local out; out=$(journalctl --user -b --since '3s ago' -o cat | grep 'FF-PERF' | tail -1)
    busctl --user call org.kde.KWin /Scripting org.kde.kwin.Scripting unloadScript s "$JS" >/dev/null
    [[ "$out" == *"windows=1"* ]]
}
sample() { # pid seconds label
    python3 - "$1" "$2" "$3" <<'PY'
import sys, time, os
pid, secs, label = int(sys.argv[1]), int(sys.argv[2]), sys.argv[3]
tick = os.sysconf('SC_CLK_TCK')
def cpu():
    f = open(f'/proc/{pid}/stat').read().rsplit(')', 1)[1].split()
    return (int(f[11]) + int(f[12])) / tick
def rss():
    for l in open(f'/proc/{pid}/status'):
        if l.startswith('VmRSS'): return int(l.split()[1]) // 1024
        if l.startswith('Threads'): th = int(l.split()[1])
    return -1
def threads():
    for l in open(f'/proc/{pid}/status'):
        if l.startswith('Threads'): return int(l.split()[1])
vals = []
c0, t0 = cpu(), time.time()
for i in range(secs):
    time.sleep(1)
    c1, t1 = cpu(), time.time()
    vals.append(100 * (c1 - c0) / (t1 - t0)); c0, t0 = c1, t1
vals.sort()
print(f"{label}: cpu avg {sum(vals)/len(vals):.1f}%  median {vals[len(vals)//2]:.1f}%  max {vals[-1]:.1f}%  rss {rss()} MB  threads {threads()}")
PY
}
T0=$(date +%s.%N)
flatpak run "$APP" "$VIDEO" >/dev/null 2>&1 &
for i in $(seq 1 100); do sleep 0.2; win_visible && break; done
T1=$(date +%s.%N)
printf "startup (launch → window on screen): %.1f s\n" "$(echo "$T1 - $T0" | bc)"
sleep 2
PID=$(pgrep -f '^haruna ' | head -1); [ -z "$PID" ] && PID=$(pgrep -x haruna | head -1)
echo "pid $PID  cmd: $(tr '\0' ' ' < /proc/$PID/cmdline | cut -c1-60)"
sample "$PID" 8 "playing 720p"
busctl --user call org.mpris.MediaPlayer2.$MPRIS /org/mpris/MediaPlayer2 org.mpris.MediaPlayer2.Player Pause 2>/dev/null && sleep 2 && sample "$PID" 6 "paused"
flatpak kill "$APP"; sleep 1; rm -f "$JS"
flatpak ps --columns=application | grep -q "$APP" && echo "WARNING still running" || echo "closed"
