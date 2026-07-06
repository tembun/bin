#!/bin/sh

#
# cur -- currency converter.
#

. "$(dirname $(readlink -f "${0}"))/../libexec/subr.sh"

define_usage -- "-f from -t to amount"

URL="https://api.frankfurter.dev/v2/rate"
JQ="jq"
AMOUNT_DEFAULT=1

get_convert_currency_url()
{
	local from="${1}"
	local to="${2}"
	echo "${URL}/$(upper "${from}")/$(upper "${to}")"
}

convert_currency()
{
	local from="${1}"
	local to="${2}"
	local amount="${3}"
	local rate=$(fetch -qo - $(get_convert_currency_url "${from}" "${to}" "${amount}") \
	    |"${JQ}" ".rate")
	bc -e "${rate} * ${amount}" \
	    |sed -E "s/\.0+$//"		# Trim trailing floating point zeros
}

OPTS="f:t:"
handle_opts()
{
	case "${1}" in
	f)	From="${OPTARG}" ;;
	t)	To="${OPTARG}" ;;
	?)	usage ;;
	esac
}

ensure_prog "${JQ}"
eval "${HANDLE_OPTS_EVAL}"
test -n "${From}" && test -n "${To}" && test "${#}" -le 1 || usage
amount="${1:-"${AMOUNT_DEFAULT}"}"
convert_currency "${From}" "${To}" "${amount}"
