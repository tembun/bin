#!/bin/sh

#
# wrd -- simple password manager.
#

progname=$(basename "$0" .sh)

WRD_DIR="$HOME/var/wrd"
UNSAFE_COPIER="xsc"
SAFE_COPY_DURATION="30"
SAFE_COPIER="xsc -d $SAFE_COPY_DURATION"

MODE_PRINT="print"
MODE_COPY="copy"
MODE_ADD="add"
MODE_DEL="del"
MODE_EDIT="edit"
copy_mode_safe=1
read_multiline_pass=0

ENTRY_TYPE_FILE="1"
ENTRY_TYPE_DIR="0"
ENTRY_TYPE_ERR="-1"

prompt()
{
	printf "$@ " 1>&2
}

warn()
{
	echo "$progname: $@" 1>&2
}

err()
{
	warn $@
	exit 1
}

print_usage()
{
	cat 1>&2 <<__EOF__
usage: $progname [-p | -u | -a | -A | -e | -E] [password_entry]
       $progname -d password_entry ...
       $progname -h
__EOF__
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

check_sure()
{
	local sure="$1"
	
	if [ "$sure" = "y" ] || [ "$sure" = "Y" ]; then
		echo "1"
	else
		echo "0"
	fi
}

get_entry_path()
{
	local arg="$1"
	
	invalid=$(echo "$arg" |grep -E '\.(\/|\.$)')
	[ -n "$invalid" ] && err "Wrong syntax for password entry: $arg"
	echo "$WRD_DIR/$arg"
}

get_entry_type()
{
	local entry_path="$1"
	
	if [ -f "$entry_path" ]; then
		echo "$ENTRY_TYPE_FILE"
	elif [ -d "$entry_path" ]; then
		echo "$ENTRY_TYPE_DIR"
	else
		echo "$ENTRY_TYPE_ERR"
	fi
}

list_dir()
{
	local dir="$1"
	
	ls -1 "$dir"
}

print_file()
{
	local file="$1"
	
	xargs printf "%s\n" <"$file"
}

write_entry_path()
{
	local entry_path="$1"
	local is_add="$2"
	local new_prefix multiline_suffix
	
	[ "$is_add" = "0" ] && new_prefix="new "
	[ "$read_multiline_pass" = "1" ] && multiline_suffix=" (multiline)"
	prompt "Enter ${new_prefix}password for ${arg}${multiline_suffix}:"
	if [ "$read_multiline_pass" = "1" ]; then
		pass=$(cat)
	else
		read pass
	fi
	mkdir -p $(dirname "$entry_path")
	printf "$pass" >"$entry_path"
}

handle_addedit_mode()
{
	local is_add="$1"
	shift
	
	local arg="$1"
	local entry_path=$(get_entry_path "$arg")
	local entry_type=$(get_entry_type "$entry_path")
	local pass dir_edit_prefix
	
	[ $# -eq 1 ] || usage
	case $entry_type in
	$ENTRY_TYPE_FILE)
		if [ "$is_add" = "1" ]; then
			err "$arg already exists"
		else
			write_entry_path "$entry_path" "0"
		fi
		;;
	$ENTRY_TYPE_DIR)
		[ "$is_add" = "0" ] && dir_edit_prefix=" and can't be edited"
		err "$arg is a directory${dir_edit_prefix}"
		;;
	$ENTRY_TYPE_ERR)
		if [ "$is_add" = "1" ]; then
			write_entry_path "$entry_path" "1"
		else
			err "$arg doesn't exist"
		fi
	esac
	
}

handle_print_mode()
{
	local arg="$1"
	local entry_path entry_type
	
	[ $# -le 1 ] || usage
	[ -z "$arg" ] && entry_path="$WRD_DIR"
	entry_path=$(get_entry_path "$arg")
	entry_type=$(get_entry_type "$entry_path")
	
	case $entry_type in
	$ENTRY_TYPE_FILE)	print_file "$entry_path" ;;
	$ENTRY_TYPE_DIR)	list_dir "$entry_path" ;;
	$ENTRY_TYPE_ERR)	err "$arg is not a password entry" ;;
	esac
}

del_entry_file()
{
	local arg="$1"
	local entry_path="$2";
	local sure
	
	prompt "Delete $arg? [y/N]:"
	read sure
	sure=$(check_sure "$sure")
	[ "$sure" = "0" ] && return
	rm -f "$entry_path"
	rmdir -p $(dirname "$entry_path") 2>/dev/null
}

del_entry_dir()
{
	local arg="$1"
	local entry_path="$2"
	
	nested_entries=$(find "$entry_path" -type f |sed "s#$WRD_DIR##")
	for nested_entry in $nested_entries; do
		del_entry "$nested_entry"
	done
}

del_entry()
{
	local arg="$1"	
	local entry_path=$(get_entry_path "$arg")
	local entry_type=$(get_entry_type "$entry_path")
	
	case $entry_type in
	$ENTRY_TYPE_FILE)	del_entry_file "$arg" "$entry_path" ;;
	$ENTRY_TYPE_DIR)	del_entry_dir "$arg" "$entry_path" ;;
	$ENTRY_TYPE_ERR)	err "$arg is not a password entry" ;;
	esac
}

handle_del_mode()
{
	[ $# -gt 0 ] || usage
	
	for entry in $@; do
		del_entry "$entry"
	done
}

unsafe_copy()
{
	local path="$1"
	
	$UNSAFE_COPIER <"$path"
}

safe_copy()
{
	local path="$1"
	
	$SAFE_COPIER <"$path"
	warn "Password copied into clipboard and will be wiped after \
$SAFE_COPY_DURATION seconds"
}

handle_copy_mode()
{
	local arg="$1"
	
	[ $# -le 1 ] || usage
	[ -z "$arg" ] && entry_path="$WRD_DIR"
	entry_path=$(get_entry_path "$arg")
	entry_type=$(get_entry_type "$entry_path")
	
	case $entry_type in
	$ENTRY_TYPE_FILE)
		if [ "$copy_mode_safe" = "1" ]; then
			safe_copy "$entry_path"
		else
			unsafe_copy "$entry_path"
		fi
		;;
	$ENTRY_TYPE_DIR)	err "$arg is a directory and can't be copied" ;;
	$ENTRY_TYPE_ERR)	err "$arg is not a password entry" ;;
	esac
}

handle_opts()
{
	local o
	
	while getopts "puaAeEdh" o; do
		case $o in
		p)	setvar mode "$MODE_PRINT" ;;
		u)	setvar copy_mode_safe "0" ;;
		a)	setvar mode "$MODE_ADD" ;;
		A)
			setvar mode "$MODE_ADD"
			setvar read_multiline_pass "1"
			;;
		e)	setvar mode "$MODE_EDIT" ;;
		E)
			setvar mode "$MODE_EDIT"
			setvar read_multiline_pass "1"
			;;
		d)	setvar mode "$MODE_DEL" ;;
		h)	help ;;
		?)	usage ;;
		esac
	done
}

handle_opts $@
shift $((OPTIND - 1))
if [ -z "$mode" ]; then
	if [ $# -eq 0 ]; then
		mode="$MODE_PRINT"
	elif [ $# -eq 1 ]; then
		entry_type=$(get_entry_type $(get_entry_path "$1"))
		if [ "$copy_mode_safe" = "1" ] && \
		    [ "$entry_type" = "$ENTRY_TYPE_DIR" ]; then
			mode="$MODE_PRINT"
		else
			mode="$MODE_COPY"
		fi
	fi
fi

if [ "$mode" != "$MODE_ADD" ] && [ ! -d "$WRD_DIR" ]; then
	err "root $progname directory has no entries"
fi

case $mode in
$MODE_PRINT)	handle_print_mode $@ ;;
$MODE_COPY)	handle_copy_mode $@ ;;
$MODE_ADD)	handle_addedit_mode 1 $@ ;;
$MODE_EDIT)	handle_addedit_mode 0 $@ ;;
$MODE_DEL)	handle_del_mode $@ ;;
*)		usage ;;
esac
