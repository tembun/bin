#!/bin/sh

#
# src -- find source code for FreeBSD base system executable.
#
# The corresponding source code file is sent to $EDITOR.
# If file is a binary executable, the information about the source file will be
# extracted from the debug-file located under /usr/lib/debug.
# If file is an ASCII text executable, the source file is the file itself.
# Options:
#	-n		Just display the source code filename.
#	-s symbol	Look for a symbol (defaults to 'main' for binaries).
#

progname=$(basename "${0}" .sh)
DBG_DIR="/usr/lib/debug"
DBG_EXT="debug"
DWARFDUMP="llvm-dwarfdump19"

usage()
{
	echo "usage: ${progname} [-n] [-s symbol] file ..." 1>&2
	exit 2
}

warn()
{
	echo "${progname}: ${@}" 1>&2
}

err()
{
	warn "${@}"
	exit 1
}

ensure_prog()
{
	_path=$(which "${1}" 2>/dev/null)
	test -n "${_path}" && test -x "${_path}" || err "You need ${1} to run this"
}

# locate_src_ascii file
locate_src_ascii()
{
	__src="${1}"
	__src_line="1"
}

accumulate_no_debug_warns()
{
	__no_debug_warns="${__no_debug_warns}
$(warn "${1}" 2>&1)"
}

flush_no_debug_warns()
{
	_warns=$(echo "${__no_debug_warns}" |sed '/^$/d')
	test -n "${_warns}" && warn "${_warns}"
}

# locate_dbg_bin file
locate_dbg_bin()
{
	_file="${1}"
	__src_dbg="${DBG_DIR}${_file}.${DBG_EXT}"
	if [ ! -f "${__src_dbg}" ]; then
		accumulate_no_debug_warns "Debug file for ${_file} not found: ${__src_dbg}"
		return 1
	fi
	return 0
}

# get_dbg_info dbg_file symbol
get_dbg_info()
{
	__dbg_info=$(${DWARFDUMP} -n "${2}" "${1}" 2>/dev/null)
}

# locate_src_file dbg_info
locate_src_file()
{
	__src=$(echo "${1}" \
	    |grep "DW_AT_decl_file" \
	    |sed -e 's/.*("//' -e 's/")//')
}

# locate_src_by_call_site dbg_file symbol dbg_info
locate_src_file_by_call_site()
{
	_dbg_file="${1}"
	_sym="${2}"
	_dbg_info="${3}"
	if echo "${_dbg_info}" |grep -q "DW_AT_GNU_all_call_sites"; then
		__dbg_info=$(${DWARFDUMP} -cn "${_sym}" "${_dbg_file}" 2>/dev/null \
		    |awk 'BEGIN {p=0}; {if($2=="DW_TAG_GNU_call_site") {p=1}; if (p==1) {print $0}}')
		test -z "${__dbg_info}" && return 1
		_call_site_sym=$(echo "${__dbg_info}" \
		    |grep "DW_AT_abstract_origin" \
		    |sed -e 's/.* "//' -e 's/")//')
		get_dbg_info "${_dbg_file}" "${_call_site_sym}"
		test -z "${__dbg_info}" && return 1
		locate_src_file "${__dbg_info}"
		return 0
	fi
	return 1
}

# locate_src_bin file symbol
locate_src_bin()
{
	_file="${1}"
	_sym="${2}"
	locate_dbg_bin "${_file}"
	test ${?} -ne 0 && return 1
	get_dbg_info "${__src_dbg}" "${_sym}"
	if [ -z "${__dbg_info}" ]; then
		warn "No debug information for symbol ${_sym} in ${__src_dbg}"
		return 1
	fi
	locate_src_file "${__dbg_info}"
	if [ -z "${__src}" ]; then
		locate_src_file_by_call_site "${__src_dbg}" "${_sym}" "${__dbg_info}"
		if [ ${?} -ne 0 ] || [ -z "${__src}" ]; then
			warn "No source file for symbol ${_sym} in ${__src_dbg}"
			return 1
		fi
	fi
	if [ ! -f "${__src}" ]; then
		warn "Source file for ${sym} was found, but it doesn't exist: ${__src}"
	fi
	__src_line=$(echo "${__dbg_info}" \
	    |grep "DW_AT_decl_line" \
	    |sed -e 's/.*(//' -e 's/)//')
	if [ -z "${__src_line}" ]; then
		warn "No source file line found for symbol ${_sym} in ${__src_dbg}"
		return 1
	fi
}

# try_locate_src file symbol?
try_locate_src()
{
	_filepath="${1}"
	_sym="${2}"
	_filetype=$(file -b "${_filepath}")
	case "${_filetype}" in
	*ASCII*)
		locate_src_ascii "${_filepath}"
		return 0
		;;
	ELF*)
		test -z "${_sym}" && _sym="main"
		locate_src_bin "${_filepath}" "${_sym}"
		return ${?}
		;;
	?)
		warn "Unsupported file type for ${_filepath}: ${_filetype}"
		return 1
		;;
	esac
}

# try_locate_src file symbol?
locate_src()
{
	_file="${1}"
	_sym="${2}"
	_filepath=$(which "${_file}" 2>/dev/null)
	if [ ${?} -ne 0 ]; then
		warn "Can't locate path for ${_file}"
		return 1
	fi
	_candidates=$(find $(dirname "${_filepath}") -samefile "${_filepath}")
	for _candidate in ${_candidates}; do
		try_locate_src "${_candidate}" "${_sym}"
		test ${?} -eq 0 && return 0
	done
	flush_no_debug_warns
	return 1
}

# print_file_name filename line_number
print_filename()
{
	echo "${1}:${2}"
}

# serve_results src_file src_line
serve_results()
{
	_src_file="${1}"
	_src_line="${2}"
	if [ "${print_name_only}" = "1" ]; then
		print_filename "${_src_file}" "${_src_line}"
		return
	fi
	if [ -n "${EDITOR}" ]; then
		${EDITOR} +"${_src_line}" "${_src_file}"
	else
		print_filename "${_src_file}" "${_src_line}"
		return
	fi
}

handle_opts()
{
	while getopts "ns:" _o; do
		case "${_o}" in
		n)	print_name_only=1 ;;
		s)	sym="${OPTARG}" ;;
		?)	usage ;;
		esac
	done
}

handle_opts ${@}
shift $((OPTIND - 1))
test ${#} -lt 1 && usage
if [ ${#} -gt 1 ]; then
	print_name_only=1
	test -n "${sym}" && err "-s is only supported for single file argument"
fi
ensure_prog "${DWARFDUMP}"
for file in "${@}"; do
	locate_src "${file}" "${sym}"
	test ${?} -eq 0 && serve_results "${__src}" "${__src_line}"
done
