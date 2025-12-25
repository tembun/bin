#!/bin/sh

#
# medo -- manage media files in various ways.
#
# Features implemented: convertion (convert), cutting (cut), stripping (strip),
# {de}muxing ({de}mux).
#

progname=$(basename "$0" .sh)
TMP_DIR="/tmp"

#=============== Common functions ===============

prompt()
{
	printf "$@" 1>&2
}

warn()
{
	local extra_prefix=""
	
	[ -n "$cmd" ] && extra_prefix="$cmd: "
	echo "$progname: $extra_prefix$@" 1>&2
}

err()
{
	warn $@
	exit 1
}

options_template()
{
	local options_str=$(echo "$1" |sed 's/^/    /')
	
	printf "Options:\n$options_str\n" 1>&2
}

usage_template()
{
	local usage_str=$(echo "$1" |sed -e "s/^/$progname /" \
	    -e '2,$s/^/       /')
	local options="$2"
	
	
	echo "Usage: $usage_str" 1>&2
	[ -n "$options" ] && options_template "$options"
	exit 2
}

usage()
{
	local usage_str_vars="CONVERT__USAGE_STR CUT__USAGE_STR
STRIP__USAGE_STR MUX__USAGE_STR DEMUX__USAGE_STR"
	local usage_str
	local idx=0
	
	printf "Usage: " 1>&2
	for usage_str_var in $usage_str_vars; do
		first_padded_line_idx=1
		[ $idx -eq 0 ] && first_padded_line_idx=2
		usage_str=$(eval "echo \"\$$usage_str_var\"" \
		    |sed -e "s/^/$progname /" \
		        -e "$first_padded_line_idx,\$s/^/       /")
		printf "$usage_str\n" 1>&2
		idx=$((idx+1))
	done
	exit 2
}

check_ffmpeg()
{
	which ffmpeg 2>&1 >/dev/null || err "ffmpeg(1) not found"
}

#=============== Convert ===============

CONVERT_CMD="convert"
CONVERT__USAGE_STR=$(cat <<__EOF__
$CONVERT_CMD from to
$CONVERT_CMD [-d output_directory] -e output_extension file ...
__EOF__
)

convert__usage()
{
	usage_template "$CONVERT__USAGE_STR"
}

convert__get_ext()
{
	local file=$(basename "$1")
	local ext_var="$2"
	local ext=$(echo "$file" |grep -Eo '\..+$' |sed 's/^\.//')
	
	setvar "$ext_var" "$ext"
}

convert__get_target_path()
{
	local src="$1"
	local target target_base
	
	convert__get_ext "$src" ext
	[ -n "$ext" ] || warn "$src extension not found; skip"
	target_base=$(basename "$src" |sed "s~$ext$~$target_ext~")
	[ ! -d "$target_dir" ] && target_dir=$(dirname "$src")
	mkdir -p "$target_dir" || err "Can't create directory $target_dir"
	target="$target_dir/$target_base"
	echo "$target"
}

convert__set_ffmpeg_opts()
{
	local ext_src="$1"
	local ext_tgt="$2"
	
	if ([ "$ext_src" = "mkv" ] && [ "$ext_tgt" = "mp4" ]) || \
	    ([ "$ext_src" = "mp4" ] && [ "$ext_tgt" = "mkv" ]); then
		setvar ffmpeg_opts "-c copy -map 0"
	fi
}

convert__do_conv()
{
	local src="$1"
	local tgt="$2"
	local ffmpeg_opts
	
	setvar conv_src "$src"
	setvar conv_tgt "$tgt"
	
	convert__get_ext "$src" src_ext
	convert__get_ext "$tgt" tgt_ext
	convert__set_ffmpeg_opts "$src_ext" "$tgt_ext"
	#
	# Put this job in the background to be able to receive SIGINFO
	# (otherwise it would be delivered to ffmpeg(1) and not to us).
	#
	ffmpeg -loglevel 8 -y -i "$src" $ffmpeg_opts "$tgt" &
	# See notes in siginfo_handler().
	wait $!
	[ $? -eq 0 ] && echo "$src -> $tgt"
}

convert__preconv_check()
{
	local src="$1"
	local tgt="$2"
	
	[ -f "$src" ] || err "$src doesn't exist"
	if [ -f "$tgt" ]; then
		setvar existing "$tgt
$existing"
	else
		setvar safe_srcs "$src
$safe_srcs"
	fi
}

convert__handle_opts()
{
	local o
	
	while getopts "e:d:" o; do
		case $o in
		e) setvar target_ext "$OPTARG" ;;
		d) setvar target_dir "$OPTARG" ;;
		?) convert__usage ;;
		esac
	done
}

convert__handle_args()
{
	local srcs=$(echo "$@" |sort |uniq)
	local src tgt sure
	local final_srcs
	local existing safe_srcs
	
	if [ -z "$target_ext" ]; then
		[ $# -eq 2 ] && [ -z "$target_dir" ] || convert__usage
		src="$1"
		tgt="$2"
		convert__preconv_check "$src" "$tgt"
		if [ -n "$existing" ]; then
			prompt "$tgt already exists. Overwrite? [y/N]: "
			read sure
			[ "$sure" != "y" ] && [ "$sure" != "Y" ] && exit 0
		fi
		convert__do_conv "$src" "$tgt"
	else
		for src in $srcs; do
			tgt=$(convert__get_target_path "$src")
			convert__preconv_check "$src" "$tgt"
		done
		final_srcs="$srcs"
		if [ -n "$existing" ]; then
			prompt "Some files already exist:\n$existing"
			prompt "Overwrite them? [y/N/q]: "
			read sure
			[ "$sure" = "q" ] && exit 0
			[ "$sure" != "y" ] && [ "$sure" != "Y" ] && \
			    final_srcs="$safe_srcs"
		fi
		for src in $final_srcs; do
			tgt=$(convert__get_target_path "$src")
			convert__do_conv "$src" "$tgt"
		done
	fi
}

convert__cmd()
{
	local target_ext target_dir
	
	convert__handle_opts $@
	shift $((OPTIND - 1))
	convert__handle_args $@
}

#=============== Cut ===============

CUT_CMD="cut"
CUT__USAGE_STR=$(cat <<__EOF__
$CUT_CMD [-i extension] [-s hh:mm:ss[.ms]] [-e hh:mm:ss[.ms]] file
__EOF__
)

CUT__DEFAULT_BAK_EXT="bak"

CUT__OPTIONS_STR=$(cat <<__EOF__
-s -- cut start timestamp. If omitted, file is cut from the begining.
-e -- cut end timestamp. If omitted, file is cut to the end.
-i -- extension for backup files (.$CUT__DEFAULT_BAK_EXT by default).
      When empty string is used, no backup files will be done.
__EOF__
)

cut__usage()
{
	usage_template "$CUT__USAGE_STR" "$CUT__OPTIONS_STR"
}

cut__do_cut()
{
	local file="$1"
	local start="$2"
	local end="$3"
	local start_opt end_opt
	local tmp_prefix=$(mktemp -u "XXXXXXXX")
	local tmp_name="$TMP_DIR/$tmp_prefix.$(basename $file)"
	local backup_ext="$bak_ext"
	
	[ -n "$start" ] && start_opt="-ss $start"
	[ -n "$end" ] && end_opt="-to $end"
	ffmpeg -loglevel 8 $start_opt $end_opt -i "$file" -c copy "$tmp_name"
	if [ $? -eq 0 ]; then
		[ $bak_opt -eq 1 ] && backup_ext="$bak_ext"
		if [ -n "$backup_ext" ]; then
			mv "$file" "$file.$backup_ext"
		fi
		mv "$tmp_name" "$file"
		echo "$file"
	fi
}

cut__handle_opts()
{
	local o
	
	while getopts "i:s:e:" o; do
		case $o in
		s)
			setvar start "$OPTARG"
			echo "$start" |grep -qE '^[0-9]+:[0-9]+:[0-9]+(\.[0-9]+)?$' || \
		    	err "Start timestamp must be in the format: hh:mm:ss[.ms]"
			;;
		e)
			setvar end "$OPTARG"
			echo "$end" |grep -qE '^[0-9]+:[0-9]+:[0-9]+(\.[0-9]+)?$' || \
		    	err "End timestamp must be in the format: hh:mm:ss[.ms]"
			;;
		i)
			setvar bak_opt 1
			setvar bak_ext "$OPTARG"
			;;
		?) cut__usage ;;
		esac
	done
}

cut__handle_args()
{
	local file="$1"
	
	([ -n "$start" ] || [ -n "$end" ] && [ $# -eq 1 ]) || cut__usage
	[ -f "$file" ] || err "File not found: $file"
	cut__do_cut "$file" "$start" "$end"
}

cut__cmd()
{
	local start end bak_ext="$CUT__DEFAULT_BAK_EXT" bak_opt=0
	
	cut__handle_opts "$@"
	shift $((OPTIND - 1))
	cut__handle_args "$@"
}

#=============== Strip ===============

STRIP_CMD="strip"
STRIP__USAGE_STR=$(cat <<__EOF__
$STRIP_CMD [-i extension] file ...
__EOF__
)

STRIP__DEFAULT_BAK_EXT="bak"

STRIP__OPTIONS_STR=$(cat <<__EOF__
-i -- extension for backup files (.$STRIP__DEFAULT_BAK_EXT by default).
      When empty string is used, no backup files will be done.
__EOF__
)

strip__usage()
{
	usage_template "$STRIP__USAGE_STR" "$STRIP__OPTIONS_STR"
}

strip__do_strip()
{
	local file="$1"
	local tmp_prefix=$(mktemp -u "XXXXXXXX")
	local tmp_name="$TMP_DIR/$tmp_prefix.$(basename "$file")"
	local backup_ext="$bak_ext"
	
	ffmpeg -loglevel 8 -i "$file" -map 0:a -c:a copy -map_metadata -1 \
	    "$tmp_name" >/dev/null
	if [ $? -eq 0 ]; then
		[ $bak_opt -eq 1 ] && backup_ext="$bak_ext"
		if [ -n "$backup_ext" ]; then
			mv "$file" "$file.$backup_ext"
		fi
		mv "$tmp_name" "$file"
		echo "$file"
	fi
}

strip__handle_opts()
{
	local o
	
	while getopts "i:" o; do
		case $o in
		i)
			setvar bak_opt 1
			setvar bak_ext "$OPTARG"
			;;
		?) strip__usage ;;
		esac
	done
}

strip__handle_args()
{
	[ $# -ge 1 ] || strip__usage
	
	for file in $@; do
		[ -f "$file" ] || err "File not found: $file"
	done
	for file in $@; do
		strip__do_strip "$file"
	done
}

strip__cmd()
{
	local bak_ext="$STRIP__DEFAULT_BAK_EXT" bak_opt=0
	
	strip__handle_opts "$@"
	shift $((OPTIND - 1))
	strip__handle_args "$@"
}

#=============== Mux ===============

MUX_CMD="mux"
MUX__USAGE_STR=$(cat <<__EOF__
$MUX_CMD file_1 file_2 output
__EOF__
)

mux__usage()
{
	usage_template "$MUX__USAGE_STR"
}

mux__do_mux()
{
	local inp_1="$1"
	local inp_2="$2"
	local out="$3" do_out=1 sure_out
	
	if [ -f "$out" ]; then
		prompt "$out already exists, overwrite? [y/N]:"
		read sure_out
		([ "$sure_out" != "y" ] && [ "$sure_out" != "Y" ]) && do_out=0
	fi
	
	[ $do_out -eq 1 ] || return
	ffmpeg -loglevel 8 -y -i "$inp_1" -i "$inp_2" -c:v copy -c:a aac "$out" \
	    >/dev/null && echo "$out"
}

mux__handle_args()
{
	[ $# -eq 3 ] || mux__usage
	
	setvar inp_1 "$1"
	setvar inp_2 "$2"
	setvar out "$3"
	[ -f "$inp_1" ] || err "File not found: $inp_1"
	[ -f "$inp_2" ] || err "File not found: $inp_2"
	
	mux__do_mux "$inp_1" "$inp_2" "$out"
}

mux__cmd()
{
	local inp_1 inp_2 out
	
	mux__handle_args "$@"
}

#=============== Demux ===============

DEMUX_CMD="demux"
DEMUX__USAGE_STR=$(cat <<__EOF__
$DEMUX_CMD file
__EOF__
)

demux__usage()
{
	usage_template "$DEMUX__USAGE_STR"
}

demux__do_demux()
{
	local file="$1"
	local name out_vid out_aud do_vid=1 do_aud=1 sure_vid sure_aud
	
	name=$(echo "$file" |sed 's/\(.*\)\..*/\1/')
	out_vid="$name.m4v"
	out_aud="$name.m4a"
	
	if [ -f "$out_vid" ]; then
		prompt "$out_vid already exists, overwrite? [y/N]: "
		read sure_vid
		([ "$sure_vid" != "y" ] && [ "$sure_vid" != "Y" ]) && do_vid=0
	fi
	if [ -f "$out_aud" ]; then
		prompt "$out_aud already exists, overwrite? [y/N]: "
		read sure_aud
		([ "$sure_aud" != "y" ] && [ "$sure_aud" != "Y" ]) && do_aud=0
	fi
	
	if [ $do_vid -eq 1 ]; then
		(ffmpeg -loglevel 8 -y -i "$file" -an -vcodec copy \
		    "$out_vid" >/dev/null \
		    && echo "$out_vid") &
	fi
	if [ $do_aud -eq 1 ]; then
		(ffmpeg -loglevel 8 -y -i "$file" -vn -acodec copy "$out_aud" \
		    >/dev/null \
		    && echo "$out_aud") &
	fi
	wait
}

demux__handle_args()
{
	[ $# -eq 1 ] || demux__usage
	
	setvar file "$1"
	[ -f "$file" ] || err "File not found: $file"
	
	demux__do_demux "$file"
}

demux__cmd()
{
	local file
	
	demux__handle_args "$@"
}

#=============== Main ===============

check_ffmpeg
[ $# -ge 1 ] || usage

cmd="$1"
shift
case $cmd in
$CONVERT_CMD) convert__cmd "$@" ;;
$CUT_CMD) cut__cmd "$@" ;;
$STRIP_CMD) strip__cmd "$@" ;;
$MUX_CMD) mux__cmd "$@" ;;
$DEMUX_CMD) demux__cmd "$@" ;;
*) usage ;;
esac
