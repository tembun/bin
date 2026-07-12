#
# subr.sh -- commonly used shell script subroutines.
#
# To include this file in the shell script:
# . "$(dirname $(readlink -f "${0}"))/../libexec/subr.sh"
#

set -e

progname=$(basename -- "${0}" ".sh")
_SUBR_PROGNAME="subr.sh"

PREFIX="/usr/local"
ETC_DIRNAME="etc"
LOCAL_ETC="${PREFIX}/${ETC_DIRNAME}"
TMP_DIRNAME="tmp"
TMP_SYS="/${TMP_DIRNAME}"
: ${TMPDIR:="${TMP_SYS}"}

# warnx arg ...
warnx()
{
	echo "${@}" 1>&2
}

# warn arg ...
warn()
{
	warnx "${progname}: ${@}"
}

_subr_warn()
{
	warnx "${_SUBR_PROGNAME}: ${@}"
}

# errx arg ...
errx()
{
	warnx "${@}"
	exit 1
}

# err arg ...
err()
{
	warn "${@}"
	exit 1
}

_subr_err()
{
	errx "${_SUBR_PROGNAME}: ${@}"
}

# prompt arg ...
prompt()
{
	warnx "${@}: "
}

USAGE_PREFIX="usage: "
_format_usage()
{
__FORMAT_USAGE_USAGE="[-p prefix] prog str"
	local o=""
	local usage_prefix="${USAGE_PREFIX}"
	eval "${BEFORE_OPTS_EVAL}"
	while getopts "p:" o; do
		case "${o}" in
		p)	usage_prefix="${OPTARG}" ;;
		?)	_subr_usage _format_usage ;;
		esac
	done
	eval "${AFTER_OPTS_EVAL}"
	test "${#}" -ge 2 || _subr_usage _format_usage
	local prog="${1}"
	shift
	local str="${@}"
	local usage_body=$(echo "${str}" |sed -e "s/^/${prog} /" \
	    -e "2,\$s/^/$(repeat " " $(len "${usage_prefix}"))/")
	echo "${usage_prefix}${usage_body}"
}

_subr_usage()
{
_USAGE_USAGE="subr_func_name"
	local func_name="${1}"
	local func_usage_var="" func_usage_str=""
	# Don't dare to make a mistake here...
	test -n "${func_name}" || _subr_usage usage
	func_usage_var="_$(upper "${func_name}")_USAGE"
	func_usage_str=$(eval echo "\"\${${func_usage_var}}\"")
	test -n "${func_usage_str}" ||
	    _subr_err "_subr_usage: ${func_usage_var} is not defined"
	# No need for a trailing space after USAGE_PREFIX, because it's
	# also included in this variable.
	warnx "$(_format_usage -p "${_SUBR_PROGNAME}: ${USAGE_PREFIX}" \
	    "${func_name}" "${func_usage_str}")"
	exit 2
}

MODE_ALL="__all"
_RESERVED_MODES="${MODE_ALL}"
_MODE_DEFAULT="${MODE_ALL}"
_MODE="${_MODE_DEFAULT}"
_CUSTOM_MODES=""
get_all_modes()
{
_GET_ALL_MODES_USAGE=""
	test "${#}" -eq 0 || _subr_usage get_all_modes
	split "${_CUSTOM_MODES}"
}
# get_all_modes() (user defined modes) + _RESERVED_MODES
_get_all_modes()
{
__GET_ALL_MODES_USAGE=""
	test "${#}" -eq 0 || _subr_usage _get_all_modes
	split "${_RESERVED_MODES} $(get_all_modes)"
}
_populate_mode_usage_all()
{
__POPULATE_MODE_USAGE_ALL_USAGE="mode usage_str ..."
	test "${#}" -ge 2 || _subr_usage _populate_mode_usage_all
	local mode="${1}"
	shift
	local usage_body=$(echo "${@}" |sed "s/^/$(_quote_mode "${mode}") /")
	pushto "${__USAGE_VAR}_$(upper "${MODE_ALL}")" "${usage_body}"
}
_quote_mode()
{
__QUOTE_MODE_USAGE="mode"
	test "${#}" -eq 1 || _subr_usage _quote_mode
	local mode="${1}"
	local MODE_QUOTE_CHAR="'"
	echo "${MODE_QUOTE_CHAR}${mode}${MODE_QUOTE_CHAR}"
}
_has_modes()
{
__HAS_MODES_USAGE=""
	test "${#}" -eq 0 || _subr_usage _has_modes
	test -n "$(get_all_modes)"
}
validate_mode() {
_VALIDATE_MODE_USAGE="mode"
	test "${#}" -eq 1 || _subr_usage validate_mode
	local mode="${1}"
	contains "${mode}" $(_get_all_modes)
}
check_mode()
{
_CHECK_MODE_USAGE="mode"
	test "${#}" -eq 1 || _subr_usage check_mode
	local mode="${1}"
	test $(get_mode) = "${mode}"
}
set_mode()
{
_SET_MODE_USAGE="mode"
	test "${#}" -ne 0 || _subr_usage set_mode
	local mode="${1}"
	_has_modes || _subr_err "set_mode(): Allowed only after define_usage() with -m"
	validate_mode "${mode}" || _subr_err "set_mode(): Undefined mode: ${mode}"
	_MODE="${mode}"
}
get_mode()
{
_GET_MODE_USAGE=""
	test "${#}" -eq 0 || _subr_usage get_mode
	echo "${_MODE}"
}
complete_mode_abbrev()
{
_COMPLETE_MODE_ABBREV_USAGE="abbrev"
	test "${#}" -eq 1 || _subr_usage complete_mode_abbrev
	local abbrev="${1}"
	complete_abbrev -s "${abbrev}" $(get_all_modes)
}
_get_handle_mode_func()
{
__GET_HANDLE_MODE_FUNC_USAGE="mode"
	test "${#}" -eq 1 || _subr_usage _get_handle_mode_func
	local FUNC_PREFIX="handle_mode_"
	local mode="${1}"
	echo "${FUNC_PREFIX}${mode}"
}
# -O	Don't try to handle opts.
handle_mode_abbrev()
{
_HANDLE_MODE_ABBREV_USAGE="[-O] abbrev [arg ...]"
	local o="" no_opts=""
	eval "${BEFORE_OPTS_EVAL}"
	while getopts "O" o; do
		case "${o}" in
		O)	no_opts=1 ;;
		?)	_subr_usage handle_mode_abbrev ;;
		esac
	done
	eval "${AFTER_OPTS_EVAL}"
	test "${#}" -ge 1 || _subr_usage handle_mode_abbrev
	local abbrev="${1}"
	shift
	local mode=$(complete_mode_abbrev "${abbrev}")
	test -n "${mode}" || usage
	local func=$(_get_handle_mode_func "${mode}")
	has_func "${func}" || _subr_err "handle_mode_abbrev(): ${func}() is not defined"
	set_mode "${mode}"
	check_flag "${no_opts}" || eval "${_HANDLE_OPTS_SAFE_EVAL}"
	"${func}" "${@}"
}

usage()
{
	_subr_err "usage() is not defined by define_usage()"
}

__USAGE_VAR="_USAGE"
_DEFINED_USAGE_TYPE_MODELESS="MODELESS"
_DEFINED_USAGE_TYPE_MODEFUL="MODEFUL"
_FIRST_DEFINED_USAGE_TYPE=""

# Creates a usage() that can be used afterwards.
# -m	Define a usage for a mode.
define_usage()
{
_DEFINE_USAGE_USAGE="[-m mode] usage_str"
	local o="" mode=""
	eval "${BEFORE_OPTS_EVAL}"
	while getopts "m:" o; do
		case "${o}" in
		m)	mode="${OPTARG}" ;;
		?)	_subr_usage define_usage ;;
		esac
	done
	eval "${AFTER_OPTS_EVAL}"
	test "${#}" -eq 1 || _subr_usage define_usage
	local usage_str="${1}"
	case "${_FIRST_DEFINED_USAGE_TYPE}" in
	"${_DEFINED_USAGE_TYPE_MODELESS}")
		_subr_err "define_usage(): Can be called only once when first called without -m"
		;;
	"${_DEFINED_USAGE_TYPE_MODEFUL}")
		test -n "${mode}" ||
		    _subr_err "define_usage(): All define_usage()s should be called with -m"
		;;
	esac
	if [ -z "${mode}" ]; then
		set_var "${__USAGE_VAR}" "${usage_str}"
usage()
{
	warnx "$(_format_usage "${progname}" "$(get_var "${__USAGE_VAR}")")"
	exit 2
}
		_FIRST_DEFINED_USAGE_TYPE="${_DEFINED_USAGE_TYPE_MODELESS}"
	else
		# If mode is valid, it means that we already defined a usage for
		# it before.
		! validate_mode "${mode}" ||
		    _subr_err "define_usage(): Usage was already defined for mode: ${mode}"
		pushto _CUSTOM_MODES "${mode}"
		# TODO: Don't copy-paste upper when setting a usage variable
		set_var "${__USAGE_VAR}_$(upper "${mode}")" "${usage_str}"
		_populate_mode_usage_all "${mode}" "${usage_str}"
		# Don't define usage() if already defined with -m earlier
		has_func usage || return 0
usage()
{
	local usage_var="${__USAGE_VAR}_$(upper $(get_mode))"
	check_var "${usage_var}" || _subr_err "usage(): Usage is not defined for a mode: $(get_mode)"
	local usage_progname="${progname}"
	! check_mode "${MODE_ALL}" && pushto -s " " usage_progname $(_quote_mode $(get_mode))
	warnx "$(_format_usage "${usage_progname}" "$(get_var "${usage_var}")")"
	exit 2
}
		_FIRST_DEFINED_USAGE_TYPE="${_DEFINED_USAGE_TYPE_MODEFUL}"
	fi
}

# Get value of the variable named var.
get_var()
{
_GET_VAR_USAGE="var"
	test "${#}" -eq 1 || _subr_usage get_var
	local var="${1}"
	eval echo "\"\$${var}\""
}

# Set value of the variable named var.
# TODO: make use of it in subr.sh functions.
set_var()
{
_SET_VAR_USAGE="var value"
	test "${#}" -eq 2 || _subr_usage set_var
	local var="${1}"
	local value="${2}"
	eval "${var}=\"${value}\""
}

# Check if variable var is set to a non-empty value.
check_var()
{
_CHECK_VAR_USAGE="var"
	test "${#}" -eq 1 || _subr_usage check_var
	local var="${1}"
	test -n "$(get_var "${var}")"
}

# Checks if arg is a shell function.
# -o	Instead of returning an exit code, echo the boolean flag (FLAG_*).
has_func()
{
_HAS_FUNC_USAGE="[-o] arg"
	local o="" output=""
	eval "${BEFORE_OPTS_EVAL}"
	while getopts "o" o; do
		case "${o}" in
		o)	output=1 ;;
		?)	_subr_usage has_func ;;
		esac
	done
	eval "${AFTER_OPTS_EVAL}"
	test "${#}" -eq 1 || _subr_usage has_func
	local arg="${1}"
	local ret=""
	if [ -z "${arg}" ]; then
		ret="1"
	else
		type "${arg}" 2>/dev/null |grep -q "function"
		ret="${?}"
	fi
	if [ "${output}" = "1" ]; then
		local res="${FLAG_CLEAR}"
		# TODO: Add a func for converting exit code to a flag.
		test "${ret}" -eq "0" && res="${FLAG_SET}"
		echo "${res}"
	else
		return "${ret}"
	fi
}

# Lowercase the arguments.
lower()
{
_LOWER_USAGE="arg ..."
	test ${#} -ne 0 || _subr_usage lower
	echo "${@}" |tr "[:upper:]" "[:lower:]"
}

# Uppercase the arguments.
upper()
{
_UPPER_USAGE="arg ..."
	test ${#} -ne 0 || _subr_usage upper
	echo "${@}" |tr "[:lower:]" "[:upper:]"
}

# Check if list contains a value.
contains()
{
_CONTAINS_USAGE="value list"
	test ${#} -ge 2 || _subr_usage contains
	local val="${1}"
	shift
	split "${@}" |grep -q "^${val}$"
}

# Get string length in bytes.
len()
{
_LEN_USAGE="str"
	test ${#} -eq 1 || _subr_usage len
	local str="${1}"
	printf -- "${str}" |wc -c
}

# Get number of lines.
lines()
{
_LINES_USAGE="str"
	test ${#} -eq 1 || _subr_usage lines
	local str="${1}"
	if [ -n "${str}" ]; then
		echo "${1}" |wc -l |sed "s/ //g"
	else
		echo "0"
	fi
}

# Add value in the end of the variable named var.
# -s	Separator (\n by default).
pushto()
{
_PUSHTO_USAGE="[-s separator] var val"
	local SEPARATOR_DEFAULT="\n"
	local separator="${SEPARATOR_DEFAULT}"
	local o=""
	eval "${BEFORE_OPTS_EVAL}"
	while getopts "s:" o; do
		case "${o}" in
		s)	separator="${OPTARG}" ;;
		?)	_subr_usage pushto ;;
		esac
	done
	eval "${AFTER_OPTS_EVAL}"
	test ${#} -eq 2 || _subr_usage pushto
	local var="${1}"
	local val="${2}"
	local var_val=$(eval echo \"\$${var}\")
	if [ -z "${var_val}" ]; then
		set_var "${var}" "${val}"
	else
		set_var "${var}" "$(printf -- "${var_val}${separator}${val}")"
	fi
}

appendto()
{
_APPENDTO_USAGE="var val"
	test ${#} -eq 2 || _subr_usage appendto
	pushto -s " " ${@}
}

split()
{
_SPLIT_USAGE="[-s separator] str"
	local SEP_DEFAULT=" "
	local o="" sep="${SEP_DEFAULT}"
	eval "${BEFORE_OPTS_EVAL}"
	while getopts "s:" o; do
		case "${o}" in
		s)	sep="${OPTARG}" ;;
		?)	_subr_usage split ;;
		esac
	done
	eval "${AFTER_OPTS_EVAL}"
	test ${#} -ne 0 || _subr_usage split
	local args="${@}"
	sub -g "${args}" "${sep}" "\n"
}

join()
{
_JOIN_USAGE="[-s separator] list"
	SEP_DEFAULT=" "
	local o="" sep="${SEP_DEFAULT}"
	eval "${BEFORE_OPTS_EVAL}"
	while getopts "s:" o; do
		case "${o}" in
		s)	sep="${OPTARG}" ;;
		?)	_subr_usage join ;;
		esac
	done
	eval "${AFTER_OPTS_EVAL}"
	test ${#} -ne 0 || _subr_usage join
	sub -gn "${@}" "\n" "${sep}"
}

# Concatenate lists (lines) and make them flat (single-line, separated with
# space).
flat()
{
_FLAT_USAGE="list ..."
	test ${#} -gt 0 || _subr_usage flat
	join -s ", " "${@}"
}

# Get a character at index in value.
char()
{
_CHAR_USAGE="index value"
	test "${#}" -eq 2 || _subr_usage char
	local idx="${1}"
	local val="${2}"
	test "${idx}" -ge 0 && test "${idx}" -lt $(len "${val}") ||
	    _subr_err "char(): Index overflow (${idx}) for value: ${val}"
	printf -- "${val}" |cut -c $((idx + 1))
}

FLAG_CLEAR="0"
FLAG_SET="1"
# Checks if arg is a set flag.
check_flag()
{
_CHECK_FLAG_USAGE="flag"
	test "${#}" -eq 1 || _subr_usage check_flag
	local flag="${1}"
	test "${flag}" = "${FLAG_SET}"
}

# Print possible abbreviation completions from variants.
# -s	Print a result only if there's a single match, oterwise return 1.
complete_abbrev()
{
_COMPLETE_ABBREV_USAGE="[-s] abbrev variant ..."
	local o="" strict=""
	eval "${BEFORE_OPTS_EVAL}"
	while getopts "s" o; do
		case "${o}" in
		s)	strict=1 ;;
		?)	_subr_usage complete_abbrev ;;
		esac
	done
	eval "${AFTER_OPTS_EVAL}"
	test "${#}" -ge 2 || _subr_usage complete_abbrev
	local abbrev="${1}"
	shift
	local variants=$(split "${@}")
	local matches=$(echo "${variants}" |grep -E "^${abbrev}")
	if [ "${strict}" = "1" ] && [ $(lines "${matches}") -ne 1 ]; then
		return 1
	fi
	echo "${matches}"
}

_HANDLE_OPTS_FUNC="handle_opts"
_get_mode_handle_opts_func()
{
__GET_MODE_HANDLE_OPTS_FUNC_USAGE="mode"
	test "${#}" -eq 1 || _subr_usage _get_mode_handle_opts_func
	local func="${_HANDLE_OPTS_FUNC}"
	if [ -n "${mode}" ] && ! check_mode "${MODE_ALL}"; then
		pushto -s "_" func "${mode}"
	fi
	echo "${func}"
}

_OPTS_VAR="OPTS"
_get_mode_opts_var_name()
{
__GET_MODE_OPTS_VAR_NAME_USAGE="mode"
	test "${#}" -eq 1 || _subr_usage _get_mode_opts_var_name
	local var_name="${_OPTS_VAR}"
	if [ -n "${mode}" ] && ! check_mode "${MODE_ALL}"; then
		pushto -s "_" var_name $(upper "${mode}")
	fi
	echo "${var_name}"
}

# _handle_opts is_safe arg ...
_handle_opts()
{
	local is_safe="${1}"
	shift
	local o=""
	local opts_var_name=$(_get_mode_opts_var_name $(get_mode))
	local opts_var_val=$(get_var "${opts_var_name}")
	test -n "${opts_var_val}" || _subr_err "${opts_var_name} is not defined"
	local handle_opts_func=$(_get_mode_handle_opts_func $(get_mode))
	if ! has_func "${handle_opts_func}"; then
		check_flag "${is_safe}" || _subr_err "${handle_opts_func}() is not defined"
		return 0
	fi
	eval "${BEFORE_OPTS_EVAL}"
	while getopts "${opts_var_val}" o; do
		"${handle_opts_func}" "${o}"
	done
}

# It's very important to restore OPTIND back to 1 when we're going to getopts(),
# because shell wouldn't do that.  And we do need to do that, because getopts()
# in many shell implementations will not parse options correctly if OPTIND is
# not at 1.  In other words, if we call the same function (that makes use of
# getopts()) multiple times, it will work on the first invocation, but won't
# on the second one, because OPTIND is shifted from 1 after first call.  The
# same will happen in we call just two different functions with getopts() in a
# row.  So we need to restore OPTIND before every getopts().
# The entire thing is understandable, because usually getopts() is called only
# once for the entire script, and not for the separate function (so it doesn't
# make much sense to restore OPTIND by default).
#
# Regarding _OLD_OPTIND: this is not that necessary, but it would be just a
# good practice to remember the current OPTIND and restore it after we're done
# with getopts() in this function, because potentially we're able to call
# another subroutine that makes use of getopts() while we're already in
# getopts().  But it will work only 1-level-deep, otherwise we have to make
# sort custom call stack, and that is obviously doesn't worth it.  As a rule of
# thumb, just don't make use of external functions while in getopts().  In
# fact, that would not be hard, I've never had a need for that, usually we just
# set binary flags in getopts().
BEFORE_OPTS_EVAL='_OLD_OPTIND=${OPTIND}; OPTIND=1'
AFTER_OPTS_EVAL='shift $((OPTIND - 1)); OPTIND="${_OLD_OPTIND}"'
HANDLE_OPTS_EVAL='_handle_opts 0 ${@}; eval ${AFTER_OPTS_EVAL}'
_HANDLE_OPTS_SAFE_EVAL='_handle_opts 1 ${@}; eval ${AFTER_OPTS_EVAL}'

# Escape character what in where.
# TODO: make usage: '-c char ... where' and make '/' a default character to escape.
# TODO: make unesc().
esc()
{
_ESC_USAGE="where what"
	local where="${1}"
	local what="${2}"
	test ${#} -eq 2 || _subr_usage esc
	echo "${where}" |sed "s#${what}#\\&#g"
}

# Substitute pattern what with with in string where.
# -g	Perform a global substitution.
sub()
{
_SUB_USAGE="[-gn] where what with"
	local o="" g_flag="" no_newline="" flags=""
	eval "${BEFORE_OPTS_EVAL}"
	while getopts "gn" o; do
		case "${o}" in
		g)	g_flag=1 ;;
		n)	no_newline=1 ;;
		?)	_subr_usage sub ;;
		esac
	done
	eval "${AFTER_OPTS_EVAL}"
	test ${#} -eq 3 || _subr_usage sub
	local where="${1}"
	local what=$(esc "${2}" "/")
	local with=$(esc "${3}" "/")
	check_flag "${g_flag}" && flags="g"
	local print_func=""
	if [ "${no_newline}" = "1" ]; then
		print_func="printf"
		local print_func_opts="--"
	else
		print_func="echo"
	fi
	"${print_func}" ${print_func_opts} "${where}" |perl -0pe "s/${what}/${with}/${flags}"
}

# Repeat string str times times.
repeat()
{
_REPEAT_USAGE="str times"
	local str="${1}"
	local times="${2}"
	test ${#} -eq 2 || _subr_usage repeat
	local spaces=$(printf -- "%${times}s\n")
	if [ "${str}" = " " ]; then
		echo "${spaces}"
	else
		sub -g "${spaces}" " " "${str}"
	fi
}

# Get filename (basename without extension).
get_filename()
{
_GET_FILENAME_USAGE="file ..."
	test ${#} -ne 0 || _subr_usage get_filename
	local file=""
	for file in ${@}; do
		echo $(basename "${file}") |sed "s/\.[^\.]*//"
	done
}

# Get last file extension.
get_ext()
{
_GET_EXT_USAGE="file ..."
	test ${#} -ne 0 || _subr_usage get_ext
	local file=""
	for file in ${@}; do
		echo $(basename "${file}") |sed "s/.*\.//"
	done
}

# Try to find an existing extension for a cut filepath (that lacks extension).
# Returns a full path to the file.
# -a	Return all existing path combinations.
# -l	Just return all possible path combination (even unexisting ones).
try_ext()
{
_TRY_EXT_USAGE="[-al] filepath ext ..."
	local o="" all="" list=""
	eval "${BEFORE_OPTS_EVAL}"
	while getopts "al" o; do
		case "${o}" in
		a)	all=1 ;;
		l)	list=1 ;;
		?)	_subr_usage try_ext ;;
		esac
	done
	eval "${AFTER_OPTS_EVAL}"
	test ${#} -ge 2 || _subr_usage try_ext
	local filepath="${1}"
	shift
	local ext="" file=""
	for ext in ${@}; do
		file="${filepath}.${ext}"
		if [ "${list}" = "1" ]; then
			echo "${file}"
			continue
		fi
		check_file "${file}" || continue
		echo "${file}"
		test "${all}" = "1" || return 0
	done
}

# Get the current date in the strftime(3) format fmt (or %s (Epoch) by default).
now()
{
_NOW_USAGE="[fmt]"
	test "${#}" -le 1 || _subr_usage now
	local FMT_DEFAULT="%s"
	local fmt="${1:-"${FMT_DEFAULT}"}"
	date "+${fmt}"
}

# Convert date from fmt_from to fmt_to.
# fmt_{from,to} are strftime(3) formats.
date2()
{
_DATE2_USAGE="date fmt_from fmt_to"
	test "${#}" -eq 3 || _subr_usage date2
	local date="${1}"
	local fmt_from="${2}"
	local fmt_to="${3}"
	date -jf "${fmt_from}" "${date}" "+${fmt_to}"
}

# Convert date in the strftime(3) format fmt into Epoch time.
date2epoch()
{
_DATE2EPOCH_USAGE="date fmt"
	test "${#}" -eq 2 || _subr_usage date2epoch
	local date="${1}"
	local fmt="${2}"
	date2 "${date}" "${fmt}" "%s"
}

ensure()
{
_ENSURE_USAGE="-e err_prefix -f func [-o] arg ..."
	local o="" func="" or="" err_prefix="" falses="" found=""
	eval "${BEFORE_OPTS_EVAL}"
	while getopts "e:f:o" o; do
		case "${o}" in
		e)	err_prefix="${OPTARG}" ;;
		f)	func="${OPTARG}" ;;
		o)	or=1 ;;
		?)	_subr_usage ensure ;;
		esac
	done
	eval "${AFTER_OPTS_EVAL}"
	has_func "${func}" && test -n "${err_prefix}" && test ${#} -ne 0 ||
	    _subr_usage ensure
	local arg=""
	for arg in ${@}; do
		if ! ${func} ${arg}; then
			pushto falses "${arg}"
			continue
		fi
		found=1
	done
	test "${found}" = "1" && (test -z "${falses}" || test "${or}" = "1") ||
	    err "${err_prefix}: $(flat "${falses}")"
}

check_dir()
{
_CHECK_DIR_USAGE="[-op] arg ..."
	local o="" or="" print=""
	eval "${BEFORE_OPTS_EVAL}"
	while getopts "op" o; do
		case "${o}" in
		o)	or=1 ;;
		p)	print=1 ;;
		?)	_subr_usage check_dir ;;
		esac
	done
	eval "${AFTER_OPTS_EVAL}"
	test ${#} -ne 0 || _subr_usage check_dir
	local dir="" found=0
	for dir in ${@}; do
		if [ ! -d "${dir}" ]; then
			test "${or}" = "1" || return 1
			continue
		fi
		found=1
		test "${or}" = "1" && test "${print}" = "1" && echo "${dir}"
	done
	if [ "${print}" = "1" ]; then
		return 0
	else
		test "${found}" = "1"
	fi
}

# Terminate the script if at least one of the paths is not a directory.
# -o	Terminate the script only if all the paths are not a directory.
ensure_dir()
{
_ENSURE_DIR_USAGE="[-o] path ..."
	local o="" or="" ensure_opts=""
	eval "${BEFORE_OPTS_EVAL}"
	while getopts "o" o; do
		case "${o}" in
		o)	or=1 ;;
		?)	_subr_usage ensure_dir
		esac
	done
	eval "${AFTER_OPTS_EVAL}"
	test ${#} -ne 0 || _subr_usage ensure_dir
	test "${or}" = "1" && appendto ensure_opts "-o"
	ensure -f check_dir -e "Directories not found" ${ensure_opts} ${@}
}

check_file()
{
_CHECK_FILE_USAGE="[-op] arg ..."
	local o="" or="" print=""
	eval "${BEFORE_OPTS_EVAL}"
	while getopts "op" o; do
		case "${o}" in
		o)	or=1 ;;
		p)	print=1 ;;
		?)	_subr_usage check_file ;;
		esac
	done
	eval "${AFTER_OPTS_EVAL}"
	test ${#} -ne 0 || _subr_usage check_file
	local file="" found=0
	for file in ${@}; do
		if [ ! -f "${file}" ]; then
			test "${or}" = "1" || return 1
			continue
		fi
		found=1
		test "${or}" = "1" && test "${print}" = "1" && echo "${file}"
	done
	if [ "${print}" = "1" ]; then
		return 0
	else
		test "${found}" = "1"
	fi
}

ERR_FILE_NOT_FOUND_PREFIX="Files not found"
err_file_not_found()
{
	err "${ERR_FILE_NOT_FOUND_PREFIX}: $(flat ${@})"
}
ensure_file()
{
_ENSURE_FILE_USAGE="[-o] path ...]"
	local o="" or="" ensure_opts=""
	eval "${BEFORE_OPTS_EVAL}"
	while getopts "o" o; do
		case "${o}" in
		o)	or=1 ;;
		?)	_subr_usage ensure_file
		esac
	done
	eval "${AFTER_OPTS_EVAL}"
	test ${#} -ne 0 || _subr_usage ensure_file
	test "${or}" = "1" && appendto ensure_opts "-o"
	ensure -f check_file -e "${ERR_FILE_NOT_FOUND_PREFIX}" ${ensure_opts} ${@}
}

check_prog()
{
_CHECK_PROG_USAGE="prog"
	local prog="${1}"
	test -n "${prog}" || _subr_usage check_prog
	local path=$(which "${prog}" 2>/dev/null)
	test -n "${path}" && test -x "${path}"
}

ensure_prog()
{
_ENSURE_PROG_USAGE="[-e err_prefix] prog ..."
	local ERR_PREFIX_DEFAULT="Missing programs"
	local err_prefix="${ERR_PREFIX_DEFAULT}"
	local o=""
	eval "${BEFORE_OPTS_EVAL}"
	while getopts "e:" o; do
		case "${o}" in
		e)	err_prefix="${OPTARG}" ;;
		?)	_subr_usage ensure_prog ;;
		esac
	done
	eval "${AFTER_OPTS_EVAL}"
	test ${#} -gt 0 || _subr_usage ensure_prog
	local missing=""
	for prog in $(echo "${@}" |sort -u); do
		check_prog "${prog}" || pushto missing "${prog}"
	done
	test -z "${missing}" || err "${err_prefix}: $(flat "${missing}")"
}

# TODO: Maybe should transform it into more general check() interface?
match_first()
{
_MATCH_FIRST_USAGE="-f func arg ..."
	local o="" func=""
	eval "${BEFORE_OPTS_EVAL}"
	while getopts "f:" o; do
		case "${o}" in
		f)	func="${OPTARG}" ;;
		?)	_subr_usage ;;
		esac
	done
	eval "${AFTER_OPTS_EVAL}"
	has_func "${func}" && test ${#} -ne 0 || _subr_usage match_first
	local arg=""
	for arg in ${@}; do
		if ${func} ${arg}; then
			found=1
			echo "${arg}"
			break
		fi
	done
	test "${found}" = "1"
}

DO_ROOT_MDO="mdo"
DO_ROOT_DOAS="doas"
DO_ROOT_SUDO="sudo"
DO_ROOT_PROGS="${DO_ROOT_MDO} ${DO_ROOT_DOAS} ${DO_ROOT_SUDO}"
_do_root_present=$(match_first -f check_prog ${DO_ROOT_PROGS})
DO_ROOT_FALLBACK="${DO_ROOT_SUDO}"
DO_ROOT_DEFAULT=${_do_root_present:-"${DO_ROOT_FALLBACK}"}
: ${DO_ROOT:="${DO_ROOT_DEFAULT}"}
do_root()
{
_DO_ROOT_USAGE="arg ..."
	test ${#} -gt 0 || _subr_usage do_root
	${DO_ROOT} ${@}
}

check_kld()
{
_CHECK_KLD_USAGE="arg ..."
	test ${#} -ne 0 || _subr_usage check_kld
	kldstat -qm ${@}
}
