#!/bin/sh

# src -- locate source code for executable in FreeBSD.
#
# It determines the source code depending on information
# that can be obtained from Makefiles under /usr/src.
# Operations with Makefiles require certain time, that's
# why it does it once and stores the information in the index
# file (under /usr/local/share/src by default), that is later
# issued for actual fast searching.


progname=$(basename "$0" .sh)
TOP="/usr/src"
INDEX_DIR="/usr/local/share/src"
INDEX_NAME="base.index"
INDEX="$INDEX_DIR/$INDEX_NAME"

# The program supports two forms of invocation:
#  `-u [-v]': creating an index file that we will make use of when
#             actually locating the sources.
#             `-v' activates verbose mode - added lines will be printed.
#  `[-a] file ...': find sources for specified files.
#                   With `-a' all the found paths are printed.
usage() {
	echo "usage: $progname -u [-v]
       src [-a] file ..."
	exit 1
}

if [ "$#" = "0" ]; then
	usage
fi

# Check if we have a source tree.
if [ ! -d "$TOP" ]; then
	echo "[src]: source code directory $TOP doesn't exist" 1>&2
	exit 1
fi

# The program is invoked in "update" mode, which creates an index file.
# The index file consists of lines:
#   `<executable path and its hard links, if any> . <source paths>'.
# Example:
#   `/bin/ed /bin/ed /bin/red . /usr/src/bin/ed'.
if [ "$1" = "-u" ]; then
	# If in the verbose mode, the actual lines that go to the index
	# file will be directed to stdout as well.
	if [ "$2" = "-v" ]; then
		verbose="1"
	fi
	# Delete previously created index file if it exists.
	rm -f "$INDEX" 2>/dev/null
	# Create a path for index if it doesn't exist.
	mkdir -p "$INDEX_DIR" 2>/dev/null
	if [ $? -ne 0 ]; then
		echo "[src]: can not create directory for index file $INDEX_DIR" 1>&2
		exit 1
	fi
	# Since index file will be situated under /usr/local/share, only
	# root user will be able to modify the file. We want to check if
	# we have appropriate permissions for this before we start.
	if ! touch "$INDEX" 2>/dev/null; then
		echo "[src]: can not create an index file at $INDEX" 1>&2
		exit 1
	fi
	# Collect all the Makefiles we possibly will be interested in.
	# Also avoiding lots of Makefiles that are for tests.
	for mf in $(find ${TOP}/bin/ ${TOP}/sbin/ \
	                 ${TOP}/usr.bin/ ${TOP}/usr.sbin/ \
	                 ${TOP}/libexec/ \
	                 ${TOP}/secure/usr.bin/ ${TOP}/secure/usr.sbin/ \
	                 ${TOP}/cddl/ ${TOP}/kerberos5/ \
	            -type f \
	            -name Makefile \
	            -not -path "*\/*tests\/*" \
	            -maxdepth 4)
	do
		mfd=$(dirname $mf)
		# Now we want to filter the Makefiles we don't need.
		# We're only looking for those ones that are for producing
		# binaries (PROG or PROG_CXX) or scripts (man(1), for example,
		# is actually a shell script, but we want to be able to search
		# for its source too).
		if grep -Eq "(PROG(_CXX)|SCRIPTS)?\??( |	)*=" $mf ; then
			# Here we're obtaining paths that this Makefile searches through.
			# It's stored in `.PATH' variable.
			sea_paths=$(make -C "$mfd" \
		                	-V '${.PATH}' \
		                	-f $mf \
		           	2>/dev/null \
		           	|sed "s/\.//")
	    	# If no such paths, then just skip this Makefile.
	    	if [ "$sea_paths" = " ." ]; then
	    		continue
	    	fi
	    	seas=" ."
	    	# Now we try to filter out all the search paths
	    	# that do not actually contain the source code.
	    	# If the path does not have source code files for
	    	# C, C++ programs or shell scripts, or there are
	    	# no executable files (that usually go without extensions),
	    	# then it's most likely not a source code directory.
	    	for sea in $sea_paths;do
	    		prog_files=$(find "$sea" -type f \
	    		                \( -perm -111 \
	    	                	-or -name "*\.c" \
	    	                	-or -name "*\.cpp" \
	    	                	-or -name "*\.cc" \
	    	                	-or -name "*\.sh" \
	    	                	-or -name "*\.y" \) \
	    	                    -maxdepth 1)
	    		if [ -n "$prog_files" ]; then
					seas="$seas $sea"
				fi
	    	done
	    	# Obtain binary destination path and its hard links.
			bin_and_links=$(make -C "$mfd" \
		                     	-V '${BINDIR}/${PROGNAME} ${LINKS}' \
		                     	-f $mf \
		                	2>/dev/null
			)
			# We have included scripts in our search along with binaries,
			# but a lot of Makefiles produce scripts that are used for
			# building, I guess, and they are not system-wide.
			# We can tell it's one of such scripts if its search
			# paths look like that:
			if [ "$bin_and_links" = "/ " ] \
			   || [ "$bin_and_links" = "/bin/ " ] \
			   || [ "$bin_and_links" = "/sbin/ " ] \
			   || [ "$bin_and_links" = "/usr/bin/ " ] \
			   || [ "$bin_and_links" = "/usr/sbin/ " ]; then
				continue
			fi
			# Build up an index line entry.
			index_line=$(echo "$bin_and_links$seas" |sed 's/  / /g')
			if [ "$verbose" = "1" ];
			then echo "$index_line" |tee -a "$INDEX"
			else echo "$index_line" >>"$INDEX"
			fi
		fi
	done
	exit 0
fi

# If we've reached this place, this means we're in the
# second invocation form (searching sources).

# First, check if we have an index file.
if [ ! -f "$INDEX" ]; then
	echo "[src]: index file $INDEX not found" 1>&2
	exit 1
fi

# In "print all" mode all the paths, that were found
# (usually more than one path is found, when the program is
# built of several modules or it also can be that the program
# includes a source code of some external program).
if [ "$1" = "-a" ]; then
	all_mode="1"
	shift
	if [ "$#" = "0" ]; then
		usage
	fi
fi

# Search paths for specified programs one-by-one.
tgts="$@"
for tgt in $tgts;do
	tgt_path=$(which $tgt 2>/dev/null)
	if [ "$?" != "0" ]; then
		echo "[src]: $tgt is not found" 1>&2
		continue
	fi
	# Resolve symlinks (like tar(1) is a symlink to /usr/bin/bsdtar).
	# And also escape characters like "[" and "" for executables
	# like [(1) (which is also test(1)) (otherwise, they will be
	# treated as part of regex sytax by grep(1)).
	tgt_path=$(realpath "$tgt_path" \
	           |sed -e 's/\[/\\\[/g' \
	                -e 's/\./\\\./g')
	# Search the target path in the index file.
	# Looking only into the first part of line, where binaries and links.
	srcs=$(grep "$tgt_path .*\. " "$INDEX")
	if [ -z "$srcs" ]; then
		echo "[src]: no sources found for $tgt" 1>&2
		continue
	fi
	srcs=$(echo "$srcs" |sed 's/.* \. //')
	# Print only first path or all of them if appropriate flag is set.
	for src in $srcs;do
		echo "$src"
		if [ "$all_mode" != "1" ]; then
			break
		fi
	done
done
