#!/bin/sh

#
# bup -- backup the system.
#
# The behaviour of this script is fully driven by its configuration file
# /usr/local/etc/buprc.  It allows to specify the backup strategies and
# configure them.  Additionally, if file ~/.buprc exists, its contents
# is appended to the main configuration file.
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
# If `out' is omitted, then `/tmp/bup-<strategy>_$DATE(%y-%m-%d_%H-%M-%S).txz'
# will be used.
#
# `root' is a flag which should be set to `1', if making a backup with this
# strategy requires root privileges.  By default, it's `0'.
#
# `dump_ports_to' is FreeBSD-only and names the file where list of installed
# ports(7) will be dumped to.  This file will be removed after the backup.
#
# Optionally, a `exclude_all' section may be specified.  It lists the files
# that will be excluded from backup (see `exclude' section) for every strategy.
#
# Resulting tar(1) with the backup is compressed with xz(1).
#

progname=$(basename "$0" .sh)
cfg_file_sys="/usr/local/etc/buprc"
cfg_file_home="$HOME/.buprc"

if [ ! -f "$cfg_file_sys" ]; then
	echo "[bup]: Config file $cfg_file_sys is mandatory" 1>&2
	exit 1
fi

cfg=$(cat "$cfg_file_sys" "$cfg_file_home" 2>/dev/null |sed -e '/^[\t\s]*#/d' \
    -e "s%\$HOME%$HOME%g" \
    |perl -0pe 's/\n\t/ /g')

strats=$(echo "$cfg" |egrep '^\w+:' |sed -e "s/:.*//" -e '/^$/d')
# Use printf(1) instead of echo(1) in order to suppress trailing newline.
strats_split=$(printf "$strats" |perl -0pe 's/\n/ | /g')

strat="$1"
if [ -z "$strat" ] || ! (echo "$strats" |grep -q "^$strat$"); then
	echo "Usage: $progname <$strats_split>"
	exit 1
fi

strat_cfg=$(echo "$cfg" |grep "^$strat: " \
    |sed "s/^$strat: //" \
    |tr -s ' ' '\n' \
    |perl -0pe 's/\n\t/ /g')

if [ -z "$strat_cfg" ]; then
	echo "[bup]: No configuration for $strat strategy" 1>&2
	exit 1
fi

include=$(echo "$strat_cfg" |grep "^include: " \
    |sed 's/^include: //' \
    |tr ' ' '\n' \
    |sort \
    |uniq)
exclude_strat=$(echo "$strat_cfg" |grep "^exclude: " \
    |sed 's/^exclude: //' \
    |tr ' ' '\n' \
    |sort \
    |uniq)
exclude_all=$(echo "$cfg" |grep "^exclude_all => " \
    |tr ' ' '\n' \
    |sort \
    |uniq)
out_raw=$(echo "$strat_cfg" |grep "^out: " \
    |sed 's/^out: //' \
    |tr ' ' '\n')
root=$(echo "$strat_cfg" |grep "^root: " \
    |sed 's/^root: //')
dump_ports_to=$(echo "$strat_cfg" |grep "^dump_ports_to: " \
    |sed 's/^dump_ports_to: //')

if [ -z "$include" ]; then
	echo "[bup]: 'include' config not found for $strat" 1>&2
	exit 1
fi

if [ "$root" = "1" ] && [ $(id -u) -ne 0 ]; then
	echo "[bup]: Insufficent privileges for $strat strategy" 1>&2
	exit 1
fi

include_cmd=$(echo "$include" |tr '\n' ' ')
exclude_cmd=$(printf "$exclude_all\n$exclude_strat" \
    |sed 's/\(.*\)/--exclude=\1/' \
    |tr '\n' ' ')

date_used=$(echo "$out_raw" |grep "\$DATE(.*)")
if [ -n "$date_used" ]; then
	date_args=$(echo "$out_raw" |sed 's/.*\$DATE(\(.*\)).*/\1/')
	ts=$(date +"$date_args")
	out=$(echo "$out_raw" |sed "s/\$DATE(.*)/$ts/")
else
	out="$out_raw"
fi


if [ -z "$out" ]; then
	out="/tmp/bup-${strat}_$(date +%y-%m-%d_%H-%M-%S).txz"
fi

abrupt_handler() {
	rm -f "$out"
	if [ -n "$dump_ports_to" ]; then
		rm -f "$dump_ports_to"
	fi
}
trap abrupt_handler 2 15

if [ -n "$dump_ports_to" ]; then
	pkg prime-origins >"$dump_ports_to"
	if [ $? -ne 0 ]; then
		echo "[bup]: Can't dump ports list to $dump_ports_to" 1>&2
		exit
	fi
fi
time tar $exclude_cmd -cJvf "$out" $include_cmd
if [ -n "$dump_ports_to" ]; then
	rm -f "$dump_ports_to"
fi
