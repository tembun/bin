#!/bin/sh

#
# rand - random string generator.
#

progname=$(basename "$0")

err()
{
	echo "$progname: $@" 1>&2
	exit 1
}

DEFAULT_LEN=10

rand_dev="/dev/urandom"
[ -c "$rand_dev" ] || err "The entropy device not found: $rand_dev"

len="$1"
echo "$len" |grep -Eq '^[0-9]*$' >/dev/null
is_len_num=$?
[ $is_len_num -ne 0 ] && err "Invalid number: $len"
[ -z "$len" ] && len="$DEFAULT_LEN"

LC_ALL=C tr -dc A-Za-z0-9 <"$rand_dev" \
    |head -c "$len" |xargs -I %% printf "%s\n" %%
