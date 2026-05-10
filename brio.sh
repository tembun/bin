#!/bin/sh

#
# brio -- build the FreeBSD system from source.
#

progname=$(basename -- "${0}" .sh)
SRC_DEFAULT="/usr/src"
TARGET_WORLD="world"
TARGET_KERNEL="kernel"
TARGET_UNIVERSE="universe"
MODE_INSTALL="install"
WORLD_BUILD_MAKE="buildworld"
WORLD_INSTALL_MAKE="installworld"
KERNEL_BUILD_MAKE="buildkernel"
KERNEL_INSTALL_MAKE="installkernel"
UNIVERSE_BUILD_MAKE="${WORLD_BUILD_MAKE} ${KERNEL_BUILD_MAKE}"
UNIVERSE_INSTALL_MAKE="${WORLD_INSTALL_MAKE} ${KERNEL_INSTALL_MAKE}"
FILEMON="filemon"
KERN_CONF_VAR="KERNCONF"
KERN_INST_NAME_VAR="INSTKERNNAME"

usage()
{
	cat 1>&2 <<__EOF__
usage: ${progname} [-s source_dir] ['${MODE_INSTALL}'] '${TARGET_WORLD}'
       ${progname} [-s source_dir] ['${MODE_INSTALL}' [-n install_name]] '${TARGET_KERNEL}' kernel_name
       ${progname} [-s source_dir] ['${MODE_INSTALL}' [-n install_name]] '${TARGET_UNIVERSE}' kernel_name
__EOF__
	exit 2
}

err()
{
	echo "${progname}: ${@}" 1>&2
	exit 1
}

ensure_dir()
{
	local dir="${1}"
	test -d "${dir}" || err "${dir} is not a directory"
}

ensure_kern_conf()
{
	local kern="${1}"
	local config="${kern_conf_dir}/${kern}"
	test -f "${config}" || err "Kernel config not found: ${config}"
}

require_kern()
{
	local kern="${1}"
	test -n "${kern}" || usage
	ensure_kern_conf "${kern}"
	make_vars="${KERN_CONF_VAR}=${kern}"
}

ensure_kld()
{
	local mod="${1}"
	kldstat -qm "${mod}" || err "${mod}(4) is not loaded into the kernel"
}

do_build()
{
	make -C "${src}" \
	    -j $(sysctl -n hw.ncpu) \
	    ${make_cmd} ${make_vars}
}

handle_opts()
{
	local o
	while getopts "s:" o; do
		case "${o}" in
		s)	src="${OPTARG}" ;;
		?)	usage ;;
		esac
	done
}

handle_opts_install_kern()
{
	local o
	while getopts "n:" o; do
		case "${o}" in
		n)	kern_inst_name="${OPTARG}" ;;
		?)	usage ;;
		esac
	done
}

handle_opts "${@}"
shift $((OPTIND - 1))
src="${src:-"${SRC_DEFAULT}"}"
arch=$(uname -p)
kern_conf_dir="${src}/sys/${arch}/conf"
test ${#} -gt 0 || usage
if [ "${1}" = "${MODE_INSTALL}" ]; then
	install_mode="1"
	shift
	handle_opts_install_kern "${@}"
	shift $((OPTIND - 1))
fi
target="${1}"
kern="${2}"
shift 2
case "${target}" in
"${TARGET_WORLD}")
	test -n "${kern}" && usage
	if [ "${install_mode}" = "1" ]; then
		make_cmd="${WORLD_INSTALL_MAKE}"
	else
		make_cmd="${WORLD_BUILD_MAKE}"
	fi
	;;
"${TARGET_KERNEL}")
	require_kern "${kern}"
	if [ "${install_mode}" = "1" ]; then
		make_cmd="${KERNEL_INSTALL_MAKE}"
	else
		make_cmd="${KERNEL_BUILD_MAKE}"
	fi
	;;
"${TARGET_UNIVERSE}")
	require_kern "${kern}"
	if [ "${install_mode}" = "1" ]; then
		make_cmd="${UNIVERSE_INSTALL_MAKE}"
	else
		make_cmd="${UNIVERSE_BUILD_MAKE}"
	fi
	;;
*)	usage ;;
esac
case "${target}" in
"${TARGET_KERNEL}"|"${TARGET_UNIVERSE}")
	if [ "${install_mode}" = "1" ]; then
		test -n "${kern_inst_name}" && \
			make_vars="${make_vars} ${KERN_INST_NAME_VAR}=${kern_inst_name}"
	fi
	;;
*)
	test -n "${kern_inst_name}" && usage
	;;
esac
ensure_dir "${src}"
ensure_kld "${FILEMON}"
make -C "${src}" \
    -j $(sysctl -n hw.ncpu) \
    ${make_cmd} ${make_vars}
