#!/bin/sh

#
# brio -- build the FreeBSD system from source.
#

progname=$(basename -- "${0}" .sh)
SRC_DEFAULT="/usr/src"
MODE_BUILD="build"
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
MODE_SYNC="sync"
SYNC_REMOTE_DEFAULT="origin"
MODE_DEFAULT="${MODE_BUILD}"
FILEMON="filemon"
KERN_CONF_VAR="KERNCONF"
KERN_INST_NAME_VAR="INSTKERNNAME"
GIT="git"

usage()
{
	cat 1>&2 <<__EOF__
usage: ${progname} [-s source_dir] ['${MODE_INSTALL}'] '${TARGET_WORLD}'
       ${progname} [-s source_dir] ['${MODE_INSTALL}' [-n kern_install_name]] '${TARGET_KERNEL}' kernel_name
       ${progname} [-s source_dir] ['${MODE_INSTALL}' [-n kern_install_name]] '${TARGET_UNIVERSE}' kernel_name
       ${progname} [-s source_dir] '${MODE_SYNC}' [-r remote] branch
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
}

check_prog()
{
	local prog="${1}"
	local path=$(which "${prog}" 2>/dev/null)
	test -n "${path}" && test -x "${path}"
}

contains()
{
	local val="${1}"
	shift
	echo "${@}" |grep -q "^${val}$"
}

ensure_kld()
{
	local mod="${1}"
	kldstat -qm "${mod}" || err "${mod}(4) is not loaded into the kernel"
}

git_get_branch()
{
	local path="${1}"
	${GIT} -C "${path}" branch --show-current
}

git_get_all_branches()
{
	local path="${1}"
	${GIT} -C "${path}" branch |sed "s/^[\* ]*//"
}

git_ensure_clean()
{
	local path="${1}"
	local tree_modified=$(${GIT} -C "${path}" status --porcelain)
	[ -z "${tree_modified}" ] || err "Your working tree is dirty: ${path}"
}

git_ensure_branch()
{
	local path="${1}"
	local branch="${2}"
	local all_branches=$(git_get_all_branches "${path}")
	contains "${branch}" "${all_branches}" || err "Branch not found: ${branch}"
}

check_install_mode()
{
	test "${mode}" = "${MODE_INSTALL}"
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

handle_opts_install()
{
	local o
	while getopts "n:" o; do
		case "${o}" in
		n)	kern_inst_name="${OPTARG}" ;;
		?)	usage ;;
		esac
	done
}

do_make()
{
	local src="${1}"
	local make_cmd="${2}"
	local make_vars="${3}"
	make -C "${src}" \
		-j $(sysctl -n hw.ncpu) \
		${make_cmd} ${make_vars}
}

handle_build_install_modes()
{
	case "${mode}" in
	"${MODE_INSTALL}")
		handle_opts_install "${@}"
		shift $((OPTIND - 1))
	esac
	target="${1}"
	kern="${2}"
	shift 2

	case "${target}" in
	"${TARGET_WORLD}")
		test -n "${kern}" && usage
		if check_install_mode; then
			make_cmd="${WORLD_INSTALL_MAKE}"
		else
			make_cmd="${WORLD_BUILD_MAKE}"
		fi
		;;
	"${TARGET_KERNEL}")
		require_kern "${kern}"
		if check_install_mode; then
			make_cmd="${KERNEL_INSTALL_MAKE}"
		else
			make_cmd="${KERNEL_BUILD_MAKE}"
		fi
		;;
	"${TARGET_UNIVERSE}")
		require_kern "${kern}"
		if check_install_mode; then
			make_cmd="${UNIVERSE_INSTALL_MAKE}"
		else
			make_cmd="${UNIVERSE_BUILD_MAKE}"
		fi
		;;
	*)	usage ;;
	esac

	case "${target}" in
	"${TARGET_KERNEL}"|"${TARGET_UNIVERSE}")
		make_vars="${KERN_CONF_VAR}=${kern}"
		if check_install_mode; then
			test -n "${kern_inst_name}" &&
			    make_vars="${make_vars} ${KERN_INST_NAME_VAR}=${kern_inst_name}"
		fi
		;;
	*)	test -n "${kern_inst_name}" && usage ;;
	esac

	ensure_dir "${src}"
	ensure_kld "${FILEMON}"
	do_make "${src}" "${make_cmd}" "${make_vars}"
}

handle_opts_sync()
{
	local o
	while getopts "r:" o; do
		case "${o}" in
		r)	sync_remote="${OPTARG}" ;;
		?)	usage ;;
		esac
	done
}

handle_sync_mode()
{
	handle_opts_sync "${@}"
	shift $((OPTIND - 1))
	: ${sync_remote:="${SYNC_REMOTE_DEFAULT}"}
	local branch="${1}"
	local current_branch=$(git_get_branch "${src}")
	test -n "${branch}" || usage
	test "${current_branch}" != "${branch}" || err "Already on branch: ${branch}"
	check_prog "${GIT}" || err "You need ${GIT} for ${MODE_SYNC} mode"
	git_ensure_branch "${src}" "${branch}"
	git_ensure_clean "${src}"
	${GIT} -C "${src}" checkout "${branch}" || err "Cannot checkout branch: ${branch}"
	${GIT} -C "${src}" pull "${sync_remote}" "${branch}" ||
	    err "Cannot pull branch ${branch} from remote ${sync_remote}"
	${GIT} -C "${src}" checkout - || err "Cannot checkout to previous branch"
	${GIT} -C "${src}" rebase "${branch}" ||
	    err "Cannot rebase ${current_branch} on top of ${branch}"
}

handle_opts "${@}"
shift $((OPTIND - 1))
: "${src:="${SRC_DEFAULT}"}"
arch=$(uname -p)
kern_conf_dir="${src}/sys/${arch}/conf"
test ${#} -gt 0 || usage
case "${1}" in
"${MODE_INSTALL}"|"${MODE_SYNC}")
	mode="${1}"
	shift
	;;
*)	mode="${MODE_DEFAULT}" ;;
esac
case "${mode}" in
"${MODE_BUILD}"|"${MODE_INSTALL}")	handle_build_install_modes "${@}" ;;
"${MODE_SYNC}")				handle_sync_mode "${@}" ;;
esac
