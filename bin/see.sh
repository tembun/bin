#!/bin/sh

#
# see -- watch a movie (with subtitles, if possible).
#

. "$(dirname $(readlink -f "${0}"))/../libexec/subr.sh"

PLAYER="mpv"
PLAYER_SUB_FILE_OPT="--sub-file"
SUB_EXT="srt"
SUB_SUFFIX=".${SUB_EXT}"
MOVIE_DIRS_DEFAULT="${HOME}/flm ${HOME}/tmp"
: ${MOVIE_DIRS:="${MOVIE_DIRS_DEFAULT}"}
_MOVIE_EXTS="mp4 mkv avi mov"	# Lowercase versions of such
MOVIE_EXTS="${_MOVIE_EXTS} $(upper "${_MOVIE_EXTS}")"

# search_in_reserved_dirs candidate_files
search_in_reserved_dirs()
{
	# Options that will be passed to find(1) to perform a search
	local find_opts=$(printf "${@}" |sed "s/.*/\\( -name & \\) -or/")
	# Remove trailing '-or' operator
	find_opts=$(join "${find_opts}" |sed "s/-or$//")
	find ${MOVIE_DIRS} -type f ${find_opts} |head -n 1
}

define_usage "file"
test ${#} -eq 1 || usage
file="${1}"
# If specified file is not found, then we try to make our 'smart' search.
if ! check_file "${file}"; then
	# If specified file already has a 'movie' extension, than we obviously
	# don't have it in the cwd, because the check_file() above said so.
	# The only thing we can do in this case - is search this file in the
	# reserved 'movie' directories (see below).
	if contains $(get_ext "${file}") "${MOVIE_EXTS}"; then
		candidate_files="${file}"
	# If we've specified a file without 'movie' extension, then we can first
	# try to guess its extension and search in in the cwd.
	else
		# A list of possible filenames with their 'movie'-extensions
		candidate_files=$(try_ext -l "${file}" "${MOVIE_EXTS}")
		# Check if we have one of these files in the cwd
		found_file=$(check_file -op "${candidate_files}" |head -n 1)
		# If we have one, then pick that file
		if [ -n "${found_file}" ]; then
			file="${found_file}"
			found_local=1
		fi
	fi

	# If we don't have any of these files in cwd, then try to search in
	# the reserved 'movie' directories (MOVIE_DIRS).
	if [ "${found_local}" != "1" ]; then
		found_file=$(search_in_reserved_dirs "${candidate_files}")
		# If we don't even have such file in reserved directories, then
		# we're done.
		test -n "${found_file}" || err_file_not_found "${file}"
		file="${found_file}"
	fi
fi
sub_file="$(dirname "${file}")/$(get_filename "${file}")${SUB_SUFFIX}"
check_file "${sub_file}" && pushto player_opts "${PLAYER_SUB_FILE_OPT}=${sub_file}"
ensure_prog "${PLAYER}"
"${PLAYER}" ${player_opts} "${file}"
