#!/bin/sh

# gp -- push current branch changes to all the remote refs.
#
# pass `f' as a first argument to force the push.


if [ ! -d .git ];then
	echo "[gp]: not a git repository." 1>&2
	exit 1
fi

if [ ! -f .git/HEAD ]\
 || [ -z "$(cat .git/HEAD)" ];then
	echo "[gp]: a repo has no HEAD." 1>&2
	exit 1
fi

if [ ! -d .git/refs/remotes ];then
	echo "[gp]: a repo doesn't have remote refs." 1>&2
	exit 1
fi

curbr=$(cat .git/HEAD |grep "ref: " |sed 's/.*\///')
rems=$(ls .git/refs/remotes)

opts=""
if [ "$1" = "f" ];then
	opts="-f"
fi

for rem in $rems;do
	git push $opts $rem $curbr &
done
