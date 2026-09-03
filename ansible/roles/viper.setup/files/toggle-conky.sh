#!/bin/bash
# Show or hide the ViPER system monitor.
#
#   toggle-conky.sh              docked panel, sized to the current screen
#   toggle-conky.sh --window     ordinary window, movable and resizable
#
# The panel is generated from the template rather than read straight from it. KasmVNC
# changes the X display resolution whenever the browser window is resized, so a config
# with baked in dimensions is correct only until someone drags the corner of their
# browser. Sizing at start time from the live geometry keeps the docked panel off the
# bottom edge; the windowed mode sidesteps the problem entirely by handing the geometry
# to the window manager.
#
# The old version read /config/.conkyrc directly, which exists only in the container,
# so this never worked on a VM.

set -uo pipefail

TEMPLATE=/usr/local/share/conky/conky.conf
RUNTIME="${HOME}/.conkyrc"
MODE="${1:-panel}"

export DISPLAY="${DISPLAY:-:1}"

notify() {
  command -v notify-send >/dev/null 2>&1 && \
    notify-send "ViPER System Monitor" "$1" -i utilities-system-monitor
  echo "$1"
}

if pgrep -x conky >/dev/null 2>&1; then
  pkill -x conky
  notify "Hidden"
  exit 0
fi

if [[ ! -r "${TEMPLATE}" ]]; then
  notify "Configuration missing at ${TEMPLATE}"
  exit 1
fi

# Height of the MATE panel at the bottom of the screen, so the sidebar stops above it
# rather than running underneath. Read from the panel's own setting where possible.
PANEL_HEIGHT=$(dconf read /org/mate/panel/toplevels/bottom/size 2>/dev/null)
[[ "${PANEL_HEIGHT}" =~ ^[0-9]+$ ]] || PANEL_HEIGHT=28

geometry=$(xdpyinfo 2>/dev/null | awk '/dimensions:/ {print $2; exit}')
screen_w=${geometry%x*}
screen_h=${geometry#*x}
[[ "${screen_w}" =~ ^[0-9]+$ ]] || screen_w=1024
[[ "${screen_h}" =~ ^[0-9]+$ ]] || screen_h=768

# Roughly a sixth of the width, clamped so it stays readable on a small screen and does
# not become a banner on a large one.
width=$(( screen_w / 6 ))
(( width < 200 )) && width=200
(( width > 300 )) && width=300

# The sidebar is full height, so there is normally room for the graphs. Only a very
# short display forces them out.
if (( screen_h < 500 )); then
  cpugraph=""
  netgraph=""
else
  graph_w=$(( (width - 6) / 2 ))
  cpugraph="\${cpugraph 32,${width} FFFFFF FFFFFF -t}"
  netgraph="\${downspeedgraph NETIF 28,${graph_w} FFFFFF FFFFFF -t} \${goto $(( graph_w + 6 ))}\${upspeedgraph NETIF 28,${graph_w} FFFFFF FFFFFF -t}"
fi

if [[ "${MODE}" == "--window" ]]; then
  window_hints=""          # decorated, so marco gives it a titlebar and resize grips
  alignment="top_left"
  gap_x=$(( screen_w / 3 ))
  gap_y=$(( screen_h / 6 ))
  height=0                 # size to content, the window manager owns the frame
  # Near opaque. A docked widget can afford to let the wallpaper through, but a window
  # the user drags over a terminal becomes unreadable if whatever is behind it shows.
  opacity=245
else
  window_hints="undecorated,below,sticky,skip_taskbar,skip_pager"
  alignment="top_right"
  gap_x=0
  gap_y=0
  # Full height down the right edge, less the MATE panel at the bottom. Conky cannot
  # follow a resolution change, so toggling off and on is what re-snaps it: this value
  # is recomputed every time the panel is switched back on.
  height=$(( screen_h - PANEL_HEIGHT ))
  (( height < 200 )) && height=200
  opacity=150
fi

# The interface has no reliable name across a container and a VM, so resolve it here.
net_if=$(ip -o -4 route show to default 2>/dev/null | awk '{print $5; exit}')
[[ -n "${net_if}" ]] || net_if=$(ls /sys/class/net 2>/dev/null | grep -v '^lo$' | head -1)
[[ -n "${net_if}" ]] || net_if=eth0

# The working volume differs: /config is the persistent mount in the container, and a
# plain home directory in the VM.
if [[ -d /config ]]; then workdir=/config; else workdir="${HOME}"; fi

cpugraph=${cpugraph//NETIF/${net_if}}
netgraph=${netgraph//NETIF/${net_if}}

sed -e "s|__ALIGNMENT__|${alignment}|g" \
    -e "s|__GAP_X__|${gap_x}|g" \
    -e "s|__GAP_Y__|${gap_y}|g" \
    -e "s|__WIDTH__|${width}|g" \
    -e "s|__HEIGHT__|${height}|g" \
    -e "s|__WINDOW_TYPE__|normal|g" \
    -e "s|__WINDOW_HINTS__|${window_hints}|g" \
    -e "s|__OPACITY__|${opacity}|g" \
    -e "s|__WORKDIR__|${workdir}|g" \
    -e "s|__CPUGRAPH__|${cpugraph}|g" \
    -e "s|__NETGRAPH__|${netgraph}|g" \
    -e "s|__NET_IF__|${net_if}|g" \
    "${TEMPLATE}" > "${RUNTIME}"

conky -c "${RUNTIME}" >/dev/null 2>&1 &

if [[ "${MODE}" == "--window" ]]; then
  notify "Shown as a window. Drag the titlebar to move, edges to resize."
else
  notify "Shown, full height for ${screen_w}x${screen_h}. Toggle off and on after resizing."
fi
