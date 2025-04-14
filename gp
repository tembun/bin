#!/bin/sh

# gp -- push current branch changes to all the remote refs.
#
# Pass `f' as a first argument to force the push.

if [ "$1" = "f" ]; then
	opts="-f"
fi

for remote in $(git remote); do
	git push $opts $remote HEAD
done
