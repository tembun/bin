#!/bin/sh

#
# gig -- git(1) interface.
#
# The invocation form is similar to git(1):
#     gig <command> [arguments]
#
# List of commands:
#     push -	push current branch changes to all remote refs.
#           	If a remote has a push-url set to `NOPUSH', no push is done.
#     prune -	prune merged branches interactively.
#     ignore -	manage gitignore(5).
#               Options:
#                   -a	Add given patterns to the file.
#                   -d	Delete given patterns from the file.
#                   -l	Show current contents of the file.
#

progname=$(basename "$0" .sh)

#=============== Common general-purpose functions ===============
prompt()
{
	printf "$@: " 1>&2
}

warn()
{
	local extra_prefix=""
	[ -n "$cmd" ] && extra_prefix="$cmd: "
	echo "$progname: ${extra_prefix}$@" 1>&2
}

err()
{
	warn "$@"
	exit 1
}

usage_template()
{
	local usage_str=$(echo "$1" |sed -e "s/^/$progname /" \
	    -e '2,$s/^/       /')
	local options="$2"
	echo "usage: $usage_str" 1>&2
	[ -n "$options" ] && options_template "$options"
	exit 2
}

usage()
{
	local usage_str_vars="PUSH__USAGE_STR PRUNE__USAGE_STR
IGNORE__USAGE_STR"
	local usage_str
	local idx=0
	printf "usage: " 1>&2
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


CONVERT__USAGE_STR=$(cat <<__EOF__
$CONVERT_CMD from to
$CONVERT_CMD [-d output_directory] -e output_extension file ...
__EOF__
)

#=============== Common git(1) functions ===============
git_check_branch()
{
	git rev-parse --verify "$1" >/dev/null 2>&1
}

git_get_repo_path()
{
	git rev-parse --show-toplevel
}

#=============== Push ===============
PUSH_CMD="push"
PUSH__USAGE_STR=$(cat <<__EOF__
$PUSH_CMD [git-push(1) options]
__EOF__
)
# Don't push if push url for a git-remote(1) is set to this value.
PUSH_NOPUSH_URL="NOPUSH"

# git_check_push_url remote
push__check_push_url()
{
	[ $(git remote get-url --push "$1") != "${PUSH_NOPUSH_URL}" ]
}

push__do_push()
{
	for remote in $(git remote); do
		if ! push__check_push_url "${remote}"; then
			warn "Push is disabled for ${remote}"
			continue
		fi
		echo "Push ${remote}"
		git push $@ $remote HEAD &
	done
	wait
}

push__cmd()
{
	push__do_push $@
}

#=============== Prune ===============
PRUNE_CMD="prune"
PRUNE__USAGE_STR=$(cat <<__EOF__
$PRUNE_CMD [target branch]
__EOF__
)

# Prune merged branches interactively.
#
prune__do_prune()
{
	local target_branch="$1"
	local sure
	git rev-parse --verify "$target_branch" >/dev/null 2>&1 \
	    || err "Target branch not found: $target_branch"
	branches=$(git branch --format='%(refname:short)' --merged \
	    "$target_branch" \
	    |grep -v "^$target_branch")
	for br in $branches; do
		prompt "Prune $br? [y/N]"
		read sure
		if [ "$sure" != "y" ] && [ "$sure" != "Y" ]; then
			continue
		fi
		git branch -d "$br"
	done
}

prune__handle_args()
{
	local target_branch="$1"
	if [ -z "$target_branch" ]; then
		for mb_br in main master $(git branch --show-current); do
			if git_check_branch "$mb_br"; then
				target_branch="$mb_br"
				warn "$mb_br is assumed to be target branch"
				break
			fi
		done
	fi
	prune__do_prune "$target_branch"
}

prune__cmd()
{
	prune__handle_args $@
}

#=============== Ignore ===============
IGNORE_CMD="ignore"
IGNORE__USAGE_STR=$(cat <<__EOF__
$IGNORE_CMD -a|-d pattern ...
$IGNORE_CMD -l
__EOF__
)
IGNORE_FILENAME=".gitignore"
IGNORE_FILE="$(git_get_repo_path)/${IGNORE_FILENAME}"
IGNORE_MODE_ADD="add"
IGNORE_MODE_DELETE="delete"
IGNORE_MODE_LIST="list"

ignore__usage()
{
	usage_template "$IGNORE__USAGE_STR"
}

ignore__validate_ignorefile()
{
	[ -f "$IGNORE_FILE" ] || err "gitignore file not found: $IGNORE_FILE"
}

ignore__add()
{
	local added
	for add in "$@"; do
		added="$added
$add"
	done
	echo "$added" |sed '1d' >>"$IGNORE_FILE"
}

ignore__delete()
{
	local content=$(cat "$IGNORE_FILE")
	local pattern_escaped
	for pattern in "$@"; do
		pattern_escaped=$(echo "$pattern" |sed 's#/#\\/#g')
		content=$(echo "$content" |sed "/^${pattern_escaped}$/d")
	done
	echo "$content" >"$IGNORE_FILE"
}

ignore__list()
{
	cat "$IGNORE_FILE"
}

ignore__handle_add()
{

	[ $# -gt 0 ] || ignore__usage
	ignore__add "$@"
}

ignore__handle_delete()
{
	ignore__validate_ignorefile
	[ $# -gt 0 ] || ignore__usage
	ignore__delete "$@"
}

ignore__handle_list()
{
	ignore__validate_ignorefile
	ignore__list
}

ingnore__handle_opts()
{
	local o
	while getopts "adl" o; do
		case $o in
		a)	setvar mode "$IGNORE_MODE_ADD" ;;
		d)	setvar mode "$IGNORE_MODE_DELETE" ;;
		l)	setvar mode "$IGNORE_MODE_LIST" ;;
		?)	ignore__usage ;;
		esac
	done
}

ignore__handle_args()
{
	case $mode in
	$IGNORE_MODE_ADD)	ignore__handle_add "$@" ;;
	$IGNORE_MODE_DELETE)	ignore__handle_delete "$@" ;;
	$IGNORE_MODE_LIST)	ignore__handle_list ;;
	esac
}

ignore__cmd()
{
	local mode
	ingnore__handle_opts "$@"
	shift $((OPTIND - 1))
	[ -n "$mode" ] || ignore__usage
	ignore__handle_args "$@"
}

#=============== Main ===============
[ $# -ge 1 ] || usage

cmd="$1"
shift
case $cmd in
$PUSH_CMD)	push__cmd "$@" ;;
$PRUNE_CMD)	prune__cmd "$@" ;;
$IGNORE_CMD)	ignore__cmd "$@" ;;
*)		usage ;;
esac
