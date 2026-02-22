#!/bin/sh

#
# src -- find source code for FreeBSD components.
#
# The corresponding source code file is sent to $EDITOR.
# This script can be invoked as src, ksrc or csrc.
#
# src locates source code for base system program named 'file'. If 'file' is a
# binary executable, the information about the source file will be extracted
# from the debug-file located under /usr/lib/debug. If file is an ASCII text
# executable, the source file is the file itself.
#
# ksrc locates source code for kernel components. By default, 'argument' is
# treated as a system call name. A particular symbol can be searched instead
# with -s option. The information is extracted from the kernel debug-file
# /usr/lib/debug/boot/kernel/kernel.debug.
#
# csrc locates source code for the C library functions (libc.so).
#
# Options:
#	-d		Just display the source code directory.
#	-n		Just display the source code filename.
#	-s symbol	Look for a symbol.
#       		If invoked as src, option names a symbol to find in the
#       		source of a program 'file'.
#       		If invoked as ksrc, option doesn't take argument and
#       		means that argument 'argument' should be treated not as
#       		a syscall name, but as a symbol.
#       		This options is not supported if invoked as csrc.
#

progname=$(basename "${0}" .sh)
DBG_DIR="/usr/lib/debug"
DBG_EXT="debug"
DWARFDUMP="llvm-dwarfdump19"
LIBC_MODE_PREFIX="c"
LIBC_PATH="/lib/libc.so.7"
KERN_MODE_PREFIX="k"
KERN_PATH="/boot/kernel/kernel"
KERN_SYSCALL_PREFIX="sys_"

usage()
{
	_reg_name=$(echo "${progname}" |sed "s/^${KERN_MODE_PREFIX}//")
	cat 1>&2 <<__EOF__
usage: ${_reg_name} [-d] [-n] [-s symbol] file ...
       ${KERN_MODE_PREFIX}${_reg_name} [-d] [-n] [-s] argument ...
       ${LIBC_MODE_PREFIX}${_reg_name} [-d] [-n] function ...
__EOF__
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

# get_line line_number list
get_line()
{
	_num="${1}"
	shift
	echo "${@}" |sed -n "${_num}p"
}

ensure_prog()
{
	_path=$(which "${1}" 2>/dev/null)
	test -n "${_path}" && test -x "${_path}" || err "You need ${1} to run this"
}

check_libc_mode()
{
	test $(echo "${progname}" |head -c 1) = "${LIBC_MODE_PREFIX}"
}

check_kern_mode()
{
	test $(echo "${progname}" |head -c 1) = "${KERN_MODE_PREFIX}"
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
#	Sets source filepath in __src and source line number in __src_line.
#	The caller should test these variables for sanity.
locate_src_file()
{
	# Get matches in the following order:
	#     - DW_AT_decl_line
	#     - DW-AT_decl_file
	#     ... then in 1-6 lines we hopefully get DW_TAG_*.
	_src_info=$(echo "${1}" \
	    |tail -r \
	    |grep -B 1 -A 6 "DW_AT_decl_file" \
	    |sed -e 's/.*("//' -e 's/")//')
	test -z "${_src_info}" && return
	_offset=0;
	# Try to find a C source file, but don't count DW_TAG_label.
	while true; do
		unset _src_c_info
		# Search for the first match of .c file that is not related to
		# DW_TAG_label.  If we found a .c file, but it is related to
		# DW_TAG_label, then remember the line number of a match
		# (_offset) and start the next search from that line.  I.e.
		# incrementally search for the first satisfying match in the
		# list.
		_src_c_info=$(echo "${_src_info}" |tail -n "+${_offset}" \
		    |grep -B 1 -A 6 -m 1 -n ".*\.c")
		test -z "${_src_c_info}" && break
		_line_num=$(echo "${_src_c_info}" |grep -Eo '^[0-9]+:' |sed 's/://')
		# Remove line number from the match
		_src_c_info=$(echo "${_src_c_info}" |cut -d : -f 2-)
		# That's the match that we need.  Quit the loop.
		echo "${_src_c_info}" |grep -q "DW_TAG_subprogram" && break
		_offset=$((_offset + _line_num + 4))
		echo "${_offset}"
	done
	# If we found a C source file, pick it, otherwise get the latest source
	# file matched.
	if [ -n "${_src_c_info}" ]; then
		_src_res_info="${_src_c_info}"
		__src=$(get_line 2 "${_src_c_info}")
	else
		_src_res_info=$(echo "${_src_info}" |head -n 2)
		__src=$(get_line 2 "${_src_info}")
	fi
	__src_line=$(echo "${_src_res_info}" \
	    |grep "DW_AT_decl_line" \
	    |sed -e 's/.*(//' -e 's/)//')
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
	# __src_line has been set earlier in locate_src_file
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
	_filetype=$(file -Lb "${_filepath}")
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

# locate_src arg1 arg2?
#	In regular mode arg1 is a program name, and arg2 is an optional symbol,
#	in kernel mode arg1 holds a syscall name or a symbol,
#	in libc mode arg1 holds a C library function name or a symbol.
locate_src()
{
	_arg1="${1}"
	_arg2="${2}"
	if check_kern_mode; then
		_filepath="${KERN_PATH}"
		test -f "${_filepath}" || err "Debug file for kernel not found: ${_filepath}"
		_sym="${_arg1}"
		test -z "${sym}" && _sym="${KERN_SYSCALL_PREFIX}${_sym}"
	elif check_libc_mode; then
		_filepath="${LIBC_PATH}"
		test -f "${_filepath}" || err "Debug file for libc not found: ${_filepath}"
		_sym="${_arg1}"
	else
		_file="${_arg1}"
		_filepath=$(which "${_file}" 2>/dev/null)
		if [ ${?} -ne 0 ]; then
			warn "Can't locate path for ${_arg1}"
			return 1
		fi
		_sym="${_arg2}"
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

# print_dir_name filename
print_dir_name()
{
	dirname "${1}"
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
	if [ "${print_dir_only}" = "1" ]; then
		print_dir_name "${_src_file}"
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
	if check_kern_mode; then
		_optstr="dns"
	elif check_libc_mode; then
		_optstr="dn"
	else
		_optstr="dns:"
	fi
	while getopts "${_optstr}" _o; do
		case "${_o}" in
		d)	print_dir_only=1 ;;
		n)	print_name_only=1 ;;
		s)	sym="${OPTARG:-"1"}" ;;
		?)	usage ;;
		esac
	done
}

validate_opts()
{
	test "${print_dir_only}" = "1" && test "${print_name_only}" = "1" &&
	    err "-d and -n options are mutually exclusive"
	if [ ${#} -gt 1 ]; then
		test "${print_dir_only}" != "1" && print_name_only=1
		!check_libc_mode && ! check_kern_mode && test -n "${sym}" &&
		    err "-s is only supported for single argument"
	fi
}

handle_opts ${@}
shift $((OPTIND - 1))
validate_opts ${@}
test ${#} -lt 1 && usage
ensure_prog "${DWARFDUMP}"
for file in "${@}"; do
	locate_src "${file}" "${sym}"
	test ${?} -eq 0 && serve_results "${__src}" "${__src_line}"
done
