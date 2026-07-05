#!/bin/sh

#
# dac -- date calculator.
#

. "$(dirname $(readlink -f "${0}"))/../libexec/subr.sh"

define_usage "[-S] [-f fmt] [-t to] [date_1] [-f fmt] date_2"

TO_DEFAULT="days"
FMT_DEFAULT="%m-%d"

OPTS="Sf:t:"
handle_opts()
{
	case "${1}" in
	S)	No_diff_sign=1 ;;
	f)	Fmt="${OPTARG}" ;;
	t)	To="${OPTARG}" ;;
	?)	usage ;;
	esac
}

get_date()
{
	local fmt="${1}"
	date "+${fmt}"
}

date2sec()
{
	local date="${1}"
	local fmt="${2}"
	date -jf "${fmt}" "${date}" "+%s"
}

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
sec1=$(date2sec "${date1}" "${fmt1}")
sec2=$(date2sec "${date2}" "${fmt2}")
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
diff_sec=$((sec_max - sec_min))
diff=$(units -t "${diff_sec} seconds" "${To}")
echo "${diff_sign}${diff}"
