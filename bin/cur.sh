#!/bin/sh

#
# cur -- currency converter.
#

. "$(dirname $(readlink -f "${0}"))/../libexec/subr.sh"

define_usage -- "-f from -t to [-v] amount"

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
	local res_amount=$(bc -e "${rate} * ${amount}" \
	    |sed -E "s/\.0+$//")		# Trim trailing floating point zeros
	if [ "${Verbose}" = "1" ]; then
		echo "${amount} $(upper "${from}") = ${res_amount} $(upper "${to}")"
	else
		echo "${res_amount}"
	fi
}

OPTS="f:t:v"
handle_opts()
{
	case "${1}" in
	f)	From="${OPTARG}" ;;
	t)	To="${OPTARG}" ;;
	v)	Verbose=1 ;;
	?)	usage ;;
	esac
}

ensure_prog "${JQ}"
eval "${HANDLE_OPTS_EVAL}"
test -n "${From}" && test -n "${To}" && test "${#}" -le 1 || usage
amount="${1:-"${AMOUNT_DEFAULT}"}"
convert_currency "${From}" "${To}" "${amount}"
