#!/bin/sh

#
# ipoo - manage IP and VPN.
#

progname=$(basename "$0")
SHOWPUB_CMD="pub"
VPN_CMD="vpn"
VPN_STATUS_CMD="status"
VPN_ON_CMD="on"
VPN_OFF_CMD="off"
SHOWPUB_URL="zx2c4.com/ip"
SHOWPUB_REQ="curl"
VPN_STATUS_IF="wg"
VPN_STATUS_IF_STATUS_ARGS="show wg0 endpoints"
VPN_MANAGER_IF="wg-quick"
VPN_MANAGER_IF_ON="up wg0"
VPN_MANAGER_IF_OFF="down wg0"
LOG_DIR="/tmp/$progname"
VPN_ON_LOG_TMPL="$LOG_DIR/${VPN_CMD}-${VPN_ON_CMD}.log.$(date +%s).XXXXXXXX"
VPN_OFF_LOG_TMPL="$LOG_DIR/${VPN_CMD}-${VPN_OFF_CMD}.log.$(date +%s).XXXXXXXX"

err()
{
	echo "$progname: $@" 1>&2
	exit 1
}

print_usage_template()
{
	echo "usage: $(printf "$@" |sed '2,$s/^/       /')" 1>&2
}

VPN_CMD_USAGE_STR="$progname $VPN_CMD <$VPN_STATUS_CMD | $VPN_ON_CMD | $VPN_OFF_CMD>"
vpn_usage()
{
	print_usage_template "$VPN_CMD_USAGE_STR"
	exit 1
}

print_usage()
{
	print_usage_template "$progname $SHOWPUB_CMD
$VPN_CMD_USAGE_STR"
}

help()
{
	print_usage
	exit 0
}

usage()
{
	print_usage
	exit 2
}

check_SHOWPUB_REQ()
{
	[ -x $(which "$SHOWPUB_REQ") ]
}

check_root()
{
	[ $(id -u) = "0" ]
}

check_vpn_status_if()
{
	[ -x $(which "$VPN_STATUS_IF") ]
}

check_vpn_manager_if()
{
	[ -x $(which "$VPN_MANAGER_IF") ]
}

require_root_net()
{
	check_root || err "Only root can do the networking"
}

require_vpn_status_if()
{
	check_vpn_status_if || err "You need $VPN_STATUS_IF to check VPN status"
}

require_vpn_manager_if()
{
	check_vpn_manager_if || err "You need $VPN_MANAGER_IF to manage VPN"
}

make_log_dir()
{
	local path="$1"
	
	mkdir -p $(dirname "$path")
	mktemp "$path"
}

get_pub_ip()
{
	$SHOWPUB_REQ "$SHOWPUB_URL"
}

vpn_endpoint()
{
	$VPN_STATUS_IF $VPN_STATUS_IF_STATUS_ARGS 2>/dev/null |cut -d '	' -f 2
}

vpn_on()
{
	$VPN_MANAGER_IF $VPN_MANAGER_IF_ON
}

vpn_off()
{
	$VPN_MANAGER_IF $VPN_MANAGER_IF_OFF
}

handle_showpub_cmd()
{
	check_SHOWPUB_REQ || err "You need $SHOWPUB_REQ to get your public IP"
	get_pub_ip
}

handle_vpn_status_cmd()
{
	local endpoint
	
	require_vpn_status_if
	
	endpoint=$(vpn_endpoint)
	if [ -n "$endpoint" ]; then
		echo "VPN is on ($endpoint)"
	else
		echo "VPN is off"
	fi
}

handle_vpn_on_cmd()
{
	local log endpoint
	
	require_root_net
	require_vpn_manager_if
	
	endpoint=$(vpn_endpoint)
	if [ -n "$endpoint" ]; then
		echo "VPN is already on ($endpoint)"
		exit
	fi
	
	log=$(make_log_dir "$VPN_ON_LOG_TMPL")
	vpn_on >"$log" 2>&1 || err "Error turning VPN on.
Logs available at: $log"
	vpn_endpoint
}

handle_vpn_off_cmd()
{
	local log
	
	require_root_net
	require_vpn_manager_if
	
	if [ -z "$(vpn_endpoint)" ]; then
		echo "VPN is already off"
		exit
	fi
	
	log=$(make_log_dir "$VPN_OFF_LOG_TMPL")
	vpn_off >"$log" 2>&1 || err "Error turning VPN off.
Logs available at: $log"
}

handle_vpn_cmd()
{
	local cmd="$1"
	
	[ $# -ne 0 ] || vpn_usage
	
	shift
	case $cmd in
	$VPN_STATUS_CMD)	handle_vpn_status_cmd ;;
	$VPN_ON_CMD)		handle_vpn_on_cmd ;;
	$VPN_OFF_CMD)		handle_vpn_off_cmd ;;
	*)			vpn_usage ;;
	esac
}

[ $# -ne 0 ] || usage

cmd="$1"
shift
case $cmd in
$SHOWPUB_CMD)	handle_showpub_cmd ;;
$VPN_CMD)	handle_vpn_cmd $@ ;;
*)		usage ;;
esac
