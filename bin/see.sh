#!/bin/sh

#
# see -- watch a movie (with subtitles, if possible).
#

. "$(dirname $(readlink -f "${0}"))/../libexec/subr.sh"

PLAYER="mpv"
PLAYER_SUB_FILE_OPT="--sub-file"
SUB_EXT="srt"
SUB_SUFFIX=".${SUB_EXT}"

define_usage "file"
test ${#} -eq 1 || usage
file="${1}"
ensure_file "${file}"
sub_file="$(dirname "${file}")/$(get_filename "${file}")${SUB_SUFFIX}"
check_file "${sub_file}" && pushto player_opts "${PLAYER_SUB_FILE_OPT}=${sub_file}"
ensure_prog "${PLAYER}"
"${PLAYER}" ${player_opts} "${file}"
