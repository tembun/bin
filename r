#!/bin/sh
#replace matches.
pat="$1"
shift
rep="$1"
shift
pths="$@"
grep -Rl "$pat" "$pths"|xargs sed -i "s/${pat}/${rep}/"
/home/artembunichev/bin/f "$rep" "$pths"