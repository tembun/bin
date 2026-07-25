#!/bin/sh

#
# rgpg -- rg(1), passed through a pager.
#
# A convenient alias.  For myself!
#

. "$(dirname $(readlink -f "${0}"))/../libexec/subr.sh"

RG="rg"
LF="lf"

ensure_prog "${RG}" "${LF}"
"${RG}" -p ${@} |"${LF}"
