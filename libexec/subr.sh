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

USAGE_PROG_PREFIX="usage: "
_format_usage()
{
__FORMAT_USAGE_USAGE="[-p prefix] prog str"
	local o="" prog="" str="" usage_body=""
	local prog_prefix="${USAGE_PROG_PREFIX}"
	while getopts "p:" o; do
		case "${o}" in
		p)	prog_prefix="${OPTARG}" ;;
		?)	_subr_usage _format_usage ;;
		esac
	done
	eval "${SHIFT_OPTS_EVAL}"
	prog="${1}"
	shift
	str="${@}"
	test -n "${str}" || _subr_usage _format_usage
	usage_body=$(echo "${str}" |sed -e "s/^/${prog} /" \
	    -e "2,\$s/^/$(repeat " " $(len "${prog_prefix}"))/")
	echo "${prog_prefix}${usage_body}"
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
	# No need for a trailing space after USAGE_PROG_PREFIX, because it's
	# also included in this variable.
	warnx "$(_format_usage -p "${_SUBR_PROGNAME}: ${USAGE_PROG_PREFIX}" \
	    "${func_name}" "${func_usage_str}")"
	exit 2
}

# Creates a usage() that can be used afterwards.
define_usage()
{
_DEFINE_USAGE_USAGE="usage_str ..."
	test ${#} -ne 0 || _subr_usage define_usage
	_USAGE="${@}"
usage()
{
	warnx "$(_format_usage "${progname}" "${_USAGE}")"
	exit 2
}
}

# Checks if arg is a shell function.
has_func()
{
_CHECK_FUNC_USAGE="arg"
	test ${#} -eq 1 || _subr_usage has_func
	local arg="${1}"
	test -n "${arg}" || return 1
	type "${arg}" 2>/dev/null |grep -q "function"
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
	printf "${1}" |wc -c
}

# Get number of lines.
lines()
{
_LINES_USAGE="str"
	test ${#} -eq 1 || _subr_usage lines
	echo "${1}" |wc -l |sed "s/ //g"
}

# Add value in the end of the variable named var.
# -s	Separator (\n by default).
pushto()
{
_PUSHTO_USAGE="[-s separator] var val"
	local SEPARATOR_DEFAULT="\n"
	local separator="${SEPARATOR_DEFAULT}"
	local o=""
	while getopts "s:" o; do
		case "${o}" in
		s)	separator="${OPTARG}" ;;
		?)	_subr_usage pushto ;;
		esac
	done
	eval "${SHIFT_OPTS_EVAL}"
	test ${#} -eq 2 || _subr_usage pushto
	local var="${1}"
	local val="${2}"
	local var_val=$(eval echo \"\$${var}\")
	if [ -z "${var_val}" ]; then
		eval "${var}=\${val}"
	else
		eval "${var}=\$(printf '${var_val}${separator}${val}')"
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
_SPLIT_USAGE="-s str list"
	local o="" str=""
	while getopts "s:" o; do
		case "${o}" in
		s)	str="${OPTARG}" ;;
		?)	_subr_usage split ;;
		esac
	done
	eval "${SHIFT_OPTS_EVAL}"
	test -n "${str}" && test ${#} -gt 0 || _subr_usage split
	sub -g "${@}" "\n" "${str}" |sed "s/${str}$//"
}

# Concatenate lists (lines) and make them flat (single-line, separated with
# space).
flat()
{
_FLAT_USAGE="list ..."
	test ${#} -gt 0 || _subr_usage flat
	split -s ", " "${@}"
}

FLAG_CLEAR="0"
FLAG_SET="1"
# Checks if arg is a set flag.
check_flag()
{
	test "${1}" = "${FLAG_SET}"
}

decode_abbrev()
{
_DECODE_ABBREV_USAGE="[-s] abbrev variant ..."
	local o="" strict="" abbrev="" variants="" matches=""
	while getopts "s" o; do
		case "${o}" in
		s)	strict=1 ;;
		?)	_subr_usage decode_abbrev ;;
		esac
	done
	eval "${SHIFT_OPTS_EVAL}"
	test ${#} -ge 2 || _subr_usage decode_abbrev
	abbrev="${1}"
	shift
	variants=$(sub -g "${@}" " " "\n")
	matches=$(echo "${variants}" |grep -E "^${abbrev}")
	if [ "${strict}" = "1" ] && [ $(lines "${matches}") -ne 1 ]; then
		return 1
	fi
	echo "${matches}"
}

_ensure_handle_opts()
{
	has_func handle_opts || _subr_err "handle_opts() is not defined"
}

_ensure_opts_var()
{
	test -n "${OPTS}" || _subr_err "OPTS is not defined"
}

_handle_opts()
{
	local o=""
	_ensure_opts_var
	_ensure_handle_opts
	while getopts "${OPTS}" o; do
		handle_opts "${o}"
	done
}

SHIFT_OPTS_EVAL='shift $((OPTIND - 1))'
HANDLE_OPTS_EVAL="_handle_opts ${@}; eval ${SHIFT_OPTS_EVAL}"

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
_SUB_USAGE="[-g] where what with"
	local o="" where="" what="" with="" g_flag="" flags=""
	while getopts "g" o; do
		case "${o}" in
		g)	g_flag=1 ;;
		?)	_subr_usage sub ;;
		esac
	done
	eval "${SHIFT_OPTS_EVAL}"
	test ${#} -eq 3 || _subr_usage sub
	where="${1}"
	what=$(esc "${2}" "/")
	with=$(esc "${3}" "/")
	check_flag "${g_flag}" && flags="g"
	echo "${where}" |perl -0pe "s/${what}/${with}/${flags}"
}

# Repeat string str times times.
repeat()
{
_REPEAT_USAGE="str times"
	local str="${1}"
	local times="${2}"
	test ${#} -eq 2 || _subr_usage repeat
	local spaces=$(printf "%${times}s\n")
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

ensure()
{
_ENSURE_USAGE="-e err_prefix -f func [-o] arg ..."
	local o="" func="" or="" err_prefix="" falses="" found=""
	while getopts "e:f:o" o; do
		case "${o}" in
		e)	err_prefix="${OPTARG}" ;;
		f)	func="${OPTARG}" ;;
		o)	or=1 ;;
		?)	_subr_usage ensure ;;
		esac
	done
	eval "${SHIFT_OPTS_EVAL}"
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
_CHECK_DIR_USAGE="arg"
	test ${#} -eq 1 || _subr_usage check_dir
	test -d "${1}"
}

# Terminate the script if at least one of the paths is not a directory.
# -o	Terminate the script only if all the paths are not a directory.
ensure_dir()
{
_ENSURE_DIR_USAGE="[-o] path ..."
	local o="" or="" ensure_opts=""
	while getopts "o" o; do
		case "${o}" in
		o)	or=1 ;;
		?)	_subr_usage ensure_dir
		esac
	done
	eval "${SHIFT_OPTS_EVAL}"
	test ${#} -ne 0 || _subr_usage ensure_dir
	test "${or}" = "1" && appendto ensure_opts "-o"
	ensure -f check_dir -e "Directories not found" ${ensure_opts} ${@}
}

check_file()
{
_CHECK_FILE_USAGE="arg"
	test ${#} -eq 1 || _subr_usage check_file
	test -f "${1}"
}

ensure_file()
{
_ENSURE_FILE_USAGE="[-o] path ...]"
	local o="" or="" ensure_opts=""
	while getopts "o" o; do
		case "${o}" in
		o)	or=1 ;;
		?)	_subr_usage ensure_file
		esac
	done
	eval "${SHIFT_OPTS_EVAL}"
	test ${#} -ne 0 || _subr_usage ensure_file
	test "${or}" = "1" && appendto ensure_opts "-o"
	ensure -f check_file -e "Files not found" ${ensure_opts} ${@}
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
	while getopts "e:" o; do
		case "${o}" in
		e)	err_prefix="${OPTARG}" ;;
		?)	_subr_usage ensure_prog ;;
		esac
	done
	eval "${SHIFT_OPTS_EVAL}"
	test ${#} -gt 0 || _subr_usage ensure_prog
	local missing=""
	for prog in $(echo "${@}" |sort -u); do
		check_prog "${prog}" || pushto missing "${prog}"
	done
	test -z "${missing}" || err "${err_prefix}: $(flat "${missing}")"
}

match_first()
{
_MATCH_FIRST_USAGE="-f func arg ..."
	local o="" func=""
	while getopts "f:" o; do
		case "${o}" in
		f)	func="${OPTARG}" ;;
		?)	_subr_usage ;;
		esac
	done
	eval "${SHIFT_OPTS_EVAL}"
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
