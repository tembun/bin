#!/bin/sh

#
# scratchmux -- invoke temporary scratch tmux(1) session.
#

. "$(dirname $(readlink -f "${0}"))/../libexec/subr.sh"

TMUX="tmux"
XTERM="xterm"

ensure_prog "${TMUX}" "${XTERM}"
sess="scratch-${$}"
"${TMUX}" new-session -d -s "${sess}"
# When a window is closed by a window manager, a nested `sh -c` will receive a
# HUP signal, so technically, I believe I need to trap only this one, but trap
# the rest just in case.XS
exec "${XTERM}" -e sh -c \
    "trap '${TMUX} kill-session -t ${sess}' INT HUP TERM EXIT
    ${TMUX} attach -t ${sess}"
