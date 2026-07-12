#!/bin/sh

#
# dac -- date calculator.
#

. "$(dirname $(readlink -f "${0}"))/../libexec/subr.sh"

MODE_DIFF="diff"
MODE_SHIFT="shift"
define_usage -m "${MODE_DIFF}" "[-S] [-f fmt] [-u output_units] [date_1] [-f fmt] date_2"
define_usage -m "${MODE_SHIFT}" "[-i input_fmt] [-o output_fmt] [-s start_date] [-u shift_units] [+-]shift"

SHIFT_UNITS_DEFAULT="days"
OUT_UNITS_DEFAULT="days"
INPUT_FMT_DEFAULT="%m-%d"
OUT_FMT_DEFAULT="%Y-%m-%d"

OPTS_DIFF="Sf:u:"
handle_opts_diff()
{
	case "${1}" in
	S)	No_diff_sign=1 ;;
	f)	Fmt="${OPTARG}" ;;
	u)	Out_units="${OPTARG}" ;;
	?)	usage ;;
	esac
}
handle_mode_diff()
{
	local fmt1="" fmt2="" date1="" date2=""
	test "${#}" -gt 0 || usage
	: ${Out_units:="${OUT_UNITS_DEFAULT}"}
	if [ "${#}" -eq 1 ]; then
		fmt1="${INPUT_FMT_DEFAULT}"
		date1=$(now "${fmt1}")
		fmt2="${Fmt:-"${INPUT_FMT_DEFAULT}"}"
		date2="${1}"
	else
		date1="${1}"
		fmt1="${Fmt:-"${INPUT_FMT_DEFAULT}"}"
		Fmt=""
		shift
		eval "${HANDLE_OPTS_EVAL}"
		test "${#}" -gt 0 || usage
			fmt2="${Fmt:-"${INPUT_FMT_DEFAULT}"}"
			date2="${1}"
	fi
	local sec1=$(date2epoch "${date1}" "${fmt1}")
	local sec2=$(date2epoch "${date2}" "${fmt2}")
	local sec_max="" sec_min="" diff_sign=""
	if [ "${sec1}" -gt "${sec2}" ]; then
		sec_max="${sec1}"
		sec_min="${sec2}"
		diff_sign="-"
	elif [ "${sec2}" -gt "${sec1}" ]; then
		sec_max="${sec2}"
		sec_min="${sec1}"
		diff_sign="+"
	else
		sec_max="${sec2}"
		sec_min="${sec1}"
		diff_sign=""
	fi
	test "${No_diff_sign}" = "1" && diff_sign=""
	local diff_sec=$((sec_max - sec_min))
	local diff_res="0"
	test "${diff_sec}" -ne 0 && diff_res=$(units -t "${diff_sec} seconds" "${Out_units}")
	echo "${diff_sign}${diff_res}"
}

OPTS_SHIFT="i:o:s:u:"
handle_opts_shift()
{
	case "${1}" in
	i)	Input_fmt="${OPTARG}" ;;
	o)	Out_fmt="${OPTARG}" ;;
	s)	Start_date="${OPTARG}" ;;
	u)	Shift_units="${OPTARG}" ;;
	?)	usage ;;
	esac
}
handle_mode_shift()
{
	test "${#}" -eq 1 || usage
	: ${Input_fmt:="${INPUT_FMT_DEFAULT}"}
	: ${Out_fmt:="${OUT_FMT_DEFAULT}"}
	: ${Shift_units:="${SHIFT_UNITS_DEFAULT}"}
	: ${Start_date:=$(now "${Input_fmt}")}
	local shift_input="${1}"
	local shift_sign="+"
	local first_shift_char=$(char 0 "${shift_input}")
	test "${first_shift_char}" = "-" && shift_sign="-"
	local shift_input_abs="${shift_input}"
	if [ "${first_shift_char}" = "+" ] || [ "${first_shift_char}" = "-" ]; then
		shift_input_abs=$(echo "${shift_input}" |cut -c 2-)
	fi
	test -n "${shift_input_abs}" || err "Wrong shift: ${shift_input}"
	local input_sec=$(date2 "${Start_date}" "${Input_fmt}" "%s")
	local dest_sec="${input_sec}"
	if [ "${shift_input_abs}" != "0" ]; then
		local shift_sec=$(units -t "${shift_input_abs} ${Shift_units}" "seconds")
		test "${shift_sign}" = "-" && shift_sec=$((-shift_sec))
		dest_sec=$((input_sec + shift_sec))
	fi
	date2 "${dest_sec}" "%s" "${Out_fmt}"
}

test "${#}" -ne 0 || usage
mode="${1}"
shift
handle_mode_abbrev "${mode}" "${@}"
