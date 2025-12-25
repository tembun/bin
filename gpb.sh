#!/bin/sh

#
# gpb -- git(1) prune merged branches interactively.
#

progname=$(basename "$0" .sh)

print_usage()
{
	cat 1>&2 <<__EOF__
usage: $progname [target_branch]
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

err()
{
	echo "$progname: $@" 1>&2
	exit 1
}

while getopts "h" o; do
	case $o in
	h) help ;;
	?) usage ;;
	esac
done
shift $((OPTIND - 1))

target_br="$1"
[ -z "$target_br" ] && target_br="master"
git rev-parse --verify "$target_br" >/dev/null 2>&1 \
    || err "Branch $target_br not found"
branches=$(git branch --format='%(refname:short)' --merged "$target_br" \
    |grep -v "^$target_br")
for br in $branches; do
	printf "$br [y/N]: "
	read del
	if [ "$del" = "y" ] || [ "$del" = "Y" ]; then
		git branch -d "$br"
	fi
done
