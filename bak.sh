#!/bin/sh

# bak -- make a backup.
#
# The behaviour of this script is fully driven by its configuration file
# /usr/local/etc/bakrc (or ~/.bakrc).  It allows to specify the backup
# strategies and configure them.
#
# The configuration file looks like this:
#     <strategy_name_1>:
#     <\t>	include:		(Required)
#     <\t><\t>		file-1
#     <\t><\t>		file-2
#     <\t><\t>		...
#     <\t>	exclude:		(Optional)
#     <\t><\t>		file-3
#     <\t><\t>		...
#     <\t>	out:
#     <\t><\t>		/tmp/backup.txz	(Optional)
#     <\t>	root:			(Optional)
#     <\t><\t>		1
#     <\t>	dump_ports_to:		(Optional, FreeBSD only)
#     <\t><\t>		/ports.list
#     <\n>
#     <strategy-name-2>:
#     ...
#     exclude_all =>			(Optional)
#     <\t>	file-4
#     <\t>	...
#
# Lines with first printable character `#' are comments and ignored.
#
# The strategy name is a handle which is specified as a script argument in
# order to make a backup according to this strategy rules.
#
# `include' section consists of a list of files that are about to be backed up.
#
# `exclude' section consists of a list of files that should be excluded from
# the backup.
#
# `out' specifies a name for a file with the backup.
# A special substring `$DATE(<args>)' may be used, which will be substituted to
# the date(1) output, to which `args' were passed as format specifiers.  Refer
# to strftime(3) for a full list of possible format specifiers.
# If `out' is omitted, then `/tmp/bak/<strategy>_$DATE(%y-%m-%d_%H-%M-%S).txz'
# will be used.
#
# `root' is a flag which should be set to `1', if making a backup with this
# strategy requires root privileges.  By default it's `0'.
#
# `dump_ports_to' is FreeBSD-only and names the file where list of installed
# ports(7) will be dumped to.  This file will be included in the backup and will
# be removed after the backup is done.
#
# Optionally, a `exclude_all' global section may be specified.  It lists the
# files that will be excluded from backup (see `exclude' section) for every
# strategy.
#
# The main invocation form of the script is:
#     bak [-c] <strategy>
# This will make a backup file according to strategy named <strategy>.
# If -c option is specified, a computed configuration for this strategy will be
# printed and no backup will be done.
#
# The second invocation form is:
#     bak -C
# which will print all the configuration files that were found, raw.  No backup
# will be done.
#
# Resulting tar(1) with the backup is compressed with xz(1).

progname=$(basename "$0" .sh)
CFG_FILENAME_STEM="${progname}rc"
CFG_FILE_SYS="/usr/local/etc/${CFG_FILENAME_STEM}"
CFG_FILE_USER="$HOME/.${CFG_FILENAME_STEM}"
CFG_FILES="$CFG_FILE_SYS $CFG_FILE_USER"
CFG_FILES_FMT=$(echo "$CFG_FILES" |sed 's/ /,&/g')
TMP_DIR="/tmp"
DEFAULT_BAK_DIR="${TMP_DIR}/${progname}"
DEFAULT_BAK_EXT="txz"

#=============== General-purpose functions ===============
warn()
{
	echo "$progname: $@" 1>&2
}

err()
{
	warn "$@" 1>&2
	exit 1
}

usage()
{
	# Use printf(1) instead of echo(1) to suppress trailing newline.
	local strats_split=$(printf "$strats" |perl -0pe 's/\n/ | /g')	
	cat 1>&2 <<__EOF__
Usage: $progname [-c] $strats_split
       $progname -C
__EOF__
	exit 1
}

# check_at_least_one_file files
check_at_least_one_file()
{
	for file in $@; do
		[ -f "$file" ] && return 0
	done
	return 1
}

# contains value list
contains()
{
	local val="$1"
	shift
	echo "$@" |grep -q "^${val}$"
}

check_root()
{
	[ $(id -u) = "0" ]
}

check_freebsd()
{
	[ $(uname) = "FreeBSD" ]
}

#=============== Config parsing ===============
GLOBAL_PROP_EXCLUDE_ALL="exclude_all"
STRAT_PROP_INCLUDE="include"
STRAT_PROP_EXCLUDE="exclude"
STRAT_PROP_OUT="out"
STRAT_PROP_ROOT="root"
STRAT_PROP_DUMP_PORTS="dump_ports_to"
VAR_HOME="HOME"
VAR_OUT_DATE="DATE"

# get_strat_default_out strat
get_strat_default_out()
{
	local date_str=$(date +%y-%m-%d_%H-%M-%S)
	echo "${DEFAULT_BAK_DIR}/${1}_${date_str}.${DEFAULT_BAK_EXT}"
}

# parse_cfg_files cfg_files
parse_cfg_files()
{
	cat $@ 2>/dev/null \
	    |sed -e '/^[\t\s]*#/d' -e "s%\$${VAR_HOME}%$HOME%g" \
	    |perl -0pe 's/\n\t/ /g'
}

# get_cfg_global_prop cfg prop
get_cfg_global_prop()
{
	local cfg="$1"
	local prop="$2"
	echo "$cfg" |grep "^${prop} => " \
	    |sed "s/^${prop} => //" \
	    |tr ' ' '\n' \
	    |sort -u
}

# get_cfg_strats cfg
get_cfg_strats()
{
	local strats=$(echo "$1" |grep -E '^\w+:' |sed -e "s/:.*//" -e '/^$/d')
	echo "$strats"
	test -n "$strats"
}

# get_strat_cfg cfg strat
#	Assumes that strat is at least defined in cfg; thus if exit code is 1,
#	it means that configuration for strat is empty (but not that there is
#	no strat in cfg whatsoever).
get_strat_cfg()
{
	local cfg="$1"
	local strat="$2"
	local strat_cfg=$(echo "$cfg" |grep "^${strat}: " \
	    |sed "s/^${strat}: //" \
	    |tr -s ' ' '\n' \
	    |perl -0pe 's/\n\t/ /g')
	echo "$strat_cfg"
	test -n "$strat_cfg"
}

# check_strat_cfg_prop strat_cfg prop
check_strat_cfg_prop()
{
	echo "$1" |grep -q "^$2: "
}

# get_strat_cfg_prop strat_cfg prop required
get_strat_cfg_prop()
{
	local strat_cfg="$1"
	local prop="$2"
	local required="$3"
	local prop_val
	if [ $required -eq 1 ]; then
		check_strat_cfg_prop "$strat_cfg" "$prop" || return 1
	fi
	prop_val=$(echo "$strat_cfg" |grep "^${prop}: " \
	    |sed "s/^${prop}: //" \
	    |tr ' ' '\n' \
	    |sort -u)
	echo "$prop_val"
	if [ $required -eq 1 ]; then
		test -n "$prop_val"
	fi
	
}

# get_dump_ports_to strat_cfg
get_dump_ports_to()
{
	local strat_cfg="$1"
	local prop="$STRAT_PROP_DUMP_PORTS"
	local val
	if ! check_freebsd && check_strat_cfg_prop "$strat_cfg" "$prop"; then
		warn "Strategy property '$prop' is only allowed in FreeBSD"
		return
	fi
	get_strat_cfg_prop "$strat_cfg" "$prop" 0
}

# get_strat_cfg_out_raw strat_cfg
get_strat_cfg_out_raw()
{
	get_strat_cfg_prop "$1" "$STRAT_PROP_OUT" 0
}

# strat_cfg_check_date_in_out_raw out_raw
strat_cfg_check_date_in_out_raw()
{
	echo "$out_raw" |grep -q '$DATE(.*)'
}

# get_strat_cfg_out strat strat_cfg
get_strat_cfg_out()
{
	local strat="$1"
	local strat_cfg="$2"
	local out_raw=$(get_strat_cfg_out_raw "$strat_cfg")
	local date_args ts
	if strat_cfg_check_date_in_out_raw "$out_raw"; then
		date_args=$(echo "$out_raw" |sed 's/.*\$DATE(\(.*\)).*/\1/')
		ts=$(date +"$date_args")
		echo "$out_raw" |sed "s/\$DATE(.*)/$ts/"
	elif [ -n "$out_raw" ]; then
		echo "$out_raw"
	else
		get_strat_default_out "$strat"
	fi
}

# get_include_files include_strat dump_ports_to
get_include_files()
{
	if [ -n "$dump_ports_to" ]; then
		printf "${include_strat}\n${dump_ports_to}" |sort -u
	else
		echo "$include_strat" |sort -u
	fi
}

# get_exclude_files cfg strat_cfg
get_exclude_files()
{
	local strat=$(get_strat_cfg_prop "$2" "$STRAT_PROP_EXCLUDE" 0)
	local all=$(get_cfg_global_prop "$1" "$GLOBAL_PROP_EXCLUDE_ALL")
	printf "${all}\n${strat}" |sort -u
}

#=============== tar(1) specific functions ===============
# tar_format_include_options include_files
tar_format_include_options()
{
	echo "$1" |tr '\n' ' '
}

# tar_format_exclude_options exclude_files
tar_format_exclude_options()
{
	echo "$1" \
	    |sed 's/\(.*\)/--exclude=\1/' \
	    |tr '\n' ' '
}

#=============== Main ===============
# dump_ports to
dump_ports()
{
	local to="$1"
	pkg prime-origins >"$to" ||
	    err "Can't dump ports list to $to"
}

# validate_root_prop strat root
validate_root_prop()
{
	[ "$2" = "1" ] && ! check_root &&
	    err "Only root can use strategy '$1'"
}

# validate_out out
validate_out()
{
	local out="$1"
	local out_dir=$(dirname "$out")
	mkdir -p "$out_dir" 2>/dev/null \
	    || err "Can't make a directory for backup: $out_dir"
	touch "$out" 2>/dev/null || err "Can't write to $out"
}

cleanup_dumped_port_list()
{
	[ -n "$dump_ports_to" ] && rm -f "$dump_ports_to"
}

abort_handler() {
	rm -f "$out"
	cleanup_dumped_port_list
}
trap abort_handler INT TERM

handle_opts()
{
	local o
	
	while getopts "Cc" o; do
	case $o in
	C)	setvar show_all_cfg 1 ;;
	c)	setvar show_strat_cfg 1 ;;
	?)	usage ;;
	esac
	done
}

show_all_cfg=0
show_strat_cfg=0

check_at_least_one_file "$CFG_FILES" ||
    err "At least one config file should be present: $CFG_FILES_FMT"
cfg=$(parse_cfg_files "$CFG_FILES")
strats=$(get_cfg_strats "$cfg") || err "No strategies found in $CFG_FILES_FMT"

# Handle options only when $strats is computed, because it may be potentially
# used in usage() if option is unknonwn.
handle_opts $@
shift $((OPTIND - 1))

[ $show_all_cfg -eq 1 ] && { cat $CFG_FILES 2>/dev/null; exit 0; }

[ $# -eq 0 ] && usage
strat="$1"
contains "$strat" "$strats" || usage
strat_cfg=$(get_strat_cfg "$cfg" "$strat") ||
    err "Configuration for strategy '$strat' is empty"
dump_ports_to=$(get_dump_ports_to "$strat_cfg")
include_strat=$(get_strat_cfg_prop "$strat_cfg" "$STRAT_PROP_INCLUDE" 1) ||
    err "Strategy property '$STRAT_PROP_INCLUDE' is required"

[ $show_strat_cfg -eq 1 ] && { echo "$strat_cfg"; exit 0; }

include_files=$(get_include_files "$include_strat" "$dump_ports_to")
include_cmd=$(tar_format_include_options "$include_files")
exclude_files=$(get_exclude_files "$cfg" "$strat_cfg")
exclude_cmd=$(tar_format_exclude_options "$exclude_files")
root=$(get_strat_cfg_prop "$strat_cfg" "$STRAT_PROP_ROOT" 0)
validate_root_prop "$strat" "$root"
out=$(get_strat_cfg_out "$strat" "$strat_cfg")
validate_out "$out"

[ -n "$dump_ports_to" ] && dump_ports "$dump_ports_to"
time tar $exclude_cmd -cJvf "$out" $include_cmd ||
    { err "Error during backup"; cleanup_dumped_port_list; }
echo "$out"
cleanup_dumped_port_list
