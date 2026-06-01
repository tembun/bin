#!/bin/sh

#
# bat -- check out the battery charge in FreeBSD.
#

progname=$(basename -- "${0}" .sh)

BAT_LOW_DEFAULT="25"

usage()
{
	echo "usage: ${progname} [-c] [-l percent]" 1>&2
	exit 2
}

get_bat()
{
	sysctl -n "hw.acpi.battery.life"
}

check_bat_low()
{
	local bat="${1}"
	test ${bat} -gt ${bat_low}
}

handle_print_mode()
{
	get_bat
}

handle_check_mode()
{
	local bat=$(get_bat)
	check_bat_low "${bat}"
}

handle_opts()
{
	local o
	while getopts "cl:" o; do
		case "${o}" in
		c)	check_mode=1 ;;
		l)	bat_low="${OPTARG}" ;;
		?)	usage ;;
		esac
	done
}

handle_opts ${@}
shift $((OPTIND - 1))
test ${#} -eq 0 || usage
: ${bat_low:="${BAT_LOW_DEFAULT}"}

if [ "${check_mode}" = "1" ]; then
	handle_check_mode
else
	handle_print_mode
fi
