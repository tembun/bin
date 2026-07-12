#!/bin/sh

#
# dac -- date calculator.
#

. "$(dirname $(readlink -f "${0}"))/../libexec/subr.sh"

MODE_DIFF="diff"
define_usage -m "${MODE_DIFF}" "[-S] [-f fmt] [-t to] [date_1] [-f fmt] date_2"

TO_DEFAULT="days"
FMT_DEFAULT="%m-%d"

OPTS_DIFF="Sf:t:"
handle_opts_diff()
{
	case "${1}" in
	S)	No_diff_sign=1 ;;
	f)	Fmt="${OPTARG}" ;;
	t)	To="${OPTARG}" ;;
	?)	usage ;;
	esac
}

handle_mode_diff()
{
	local fmt1="" fmt2="" date1="" date2=""
	eval "${HANDLE_OPTS_EVAL}"
	test "${#}" -gt 0 || usage
	: ${To:="${TO_DEFAULT}"}
	if [ "${#}" -eq 1 ]; then
		fmt1="${FMT_DEFAULT}"
		date1=$(get_date "${fmt1}")
		fmt2="${Fmt:-"${FMT_DEFAULT}"}"
		date2="${1}"
	else
		date1="${1}"
		fmt1="${Fmt:-"${FMT_DEFAULT}"}"
		Fmt=""
		shift
		eval "${HANDLE_OPTS_EVAL}"
		test "${#}" -gt 0 || usage
			fmt2="${Fmt:-"${FMT_DEFAULT}"}"
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
	local diff_res=$(units -t "${diff_sec} seconds" "${To}")
	echo "${diff_sign}${diff_res}"
}

test "${#}" -ne 0 || usage
mode="${1}"
shift
handle_mode_abbrev "${mode}" "${@}"
