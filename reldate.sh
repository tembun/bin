#!/bin/sh

#
# reldate -- get FreeBSD release date.
#
# See also getosreldate(3).
#

rel_date=$(sed -ne 's/^#define __FreeBSD_version \(.*\)/\1/p' \
    /usr/include/sys/param.h)

if [ -n "$rel_date" ]; then
	echo "$rel_date"
else
	sysctl -n kern.osreldate
fi
