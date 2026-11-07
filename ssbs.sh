#!/bin/sh
### Rozhuk Ivan 2026
### Shell script based build system

# Copyright (c) 2026 Rozhuk Ivan <rozhuk.im@gmail.com>
# All rights reserved.
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions
# are met:
# 1. Redistributions of source code must retain the above copyright
#    notice, this list of conditions and the following disclaimer.
# 2. Redistributions in binary form must reproduce the above copyright
#    notice, this list of conditions and the following disclaimer in the
#    documentation and/or other materials provided with the distribution.
#
# THIS SOFTWARE IS PROVIDED BY THE REGENTS AND CONTRIBUTORS ``AS IS'' AND
# ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
# IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
# ARE DISCLAIMED.  IN NO EVENT SHALL THE REGENTS OR CONTRIBUTORS BE LIABLE
# FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
# DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS
# OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
# HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT
# LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY
# OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF
# SUCH DAMAGE.
#
# Author: Rozhuk Ivan <rozhuk.im@gmail.com>
#


# Exit on error.
set -e

# Init constans.
: "${BUILD_SYS_SCRIPT_NAME:=$(readlink -nf "${0}")}"
BUILD_SYS_DIR="$(dirname "${BUILD_SYS_SCRIPT_NAME}")"
export BUILD_SYS_DIR


apply_paches() { # patch_files_list/patch_dir_and_mask, target_dir_name
	# shellcheck disable=SC3043
	local __PATCH_FILE

	for __PATCH_FILE in ${1}; do
		echo "Apply patch: ${__PATCH_FILE}"
		patch \
			--quiet \
			--backup \
			--version-control 'numbered' \
			--strip '0' \
			--directory "${2}" \
			--input "${__PATCH_FILE}"
	done
	return 0
}

restore_files() { # dir_name
	# shellcheck disable=SC3043
	local __BAK_FILENAME

	if [ -r "${1}" ]; then
		for __BAK_FILENAME in $(find "${1}/" -type f \( -name '*.orig' -o -name '*.~1~' \) | sort -u); do
			[ -z "${__BAK_FILENAME}" ] && continue
			__ORIG_FILENAME=$(echo "${__BAK_FILENAME}" | sed -e 's|\.orig||g' -e 's|\.~.*~||g')
			mv -f "${__BAK_FILENAME}" "${__ORIG_FILENAME}"
		done
		find "${1}/" -type f \( -name '*.~?~' -o -name '*.rej' \) -delete > /dev/null 2>&1
	fi
	return 0
}


pkg_check_module() { # modulename, [mod, ver]
	# shellcheck disable=SC3043
	local __VER_MATCH __MOD_VER __ENV_VAR_NAME __ENV_VAR_VAL

	__ENV_VAR_NAME=$(echo "${*}_check_module" | sed -e 's|/|_|g' -e 's|-|_|g' -e 's|+|_|g' -e 's|=|_EQ_|g' -e 's|>|_GT_|g' -e 's|<|_LT_|g' -e 's|\.|_|g' -e 's|,|_|g' -e 's| |_|g' | tr '[:lower:]' '[:upper:]')
	eval __ENV_VAR_VAL="\$${__ENV_VAR_NAME}" 2>/dev/null

	printf "%s" "-- Checking for module '${*}' - "
	if [ 'failed' = "${__ENV_VAR_VAL}" ]; then
		echo 'Not found ❌ (cached)'
		return 1
	fi
	if [ -n "${__ENV_VAR_VAL}" ]; then
		echo "Found version ${__ENV_VAR_VAL} ✅ (cached)"
		return 0
	fi

	case "${2}" in
	'>')
		__VER_MATCH="--atleast-version ${3}"
		;;
	'=')
		__VER_MATCH="--exact-version ${3}"
		;;
	'<')
		__VER_MATCH="--max-version ${3}"
		;;
	esac

	__MOD_VER=$(pkg-config --modversion "${__VER_MATCH}" "${1}")
	# shellcheck disable=SC2181
	if [ '0' = "${?}" ] && [ -n "${__MOD_VER}" ]; then
		MODULES_CFLAGS="${MODULES_CFLAGS} $(pkg-config --cflags "${__VER_MATCH}" "${1}" | sed -e 's|  | |g')"
		MODULES_LIBS_STATIC="${MODULES_LIBS_STATIC} $(pkg-config --libs --static "${__VER_MATCH}" "${1}" | sed -e 's|  | |g')"
		MODULES_LIBS_SHARED="${MODULES_LIBS_SHARED} $(pkg-config --libs --shared "${__VER_MATCH}" "${1}" | sed -e 's|  | |g')"
		echo "Found version ${__MOD_VER} ✅"
		eval export "${__ENV_VAR_NAME}"="${__MOD_VER}"
		return 0
	fi
	echo 'Not found ❌'
	eval export "${__ENV_VAR_NAME}"='failed'
	return 1
}

pkg_check_modules() { # modules_list
	# shellcheck disable=SC3043
	local __MODULE

	for __MODULE in "${@}"; do
		# shellcheck disable=SC3043
		local IFS=' 	'
		pkg_check_module "${__MODULE}"
	done
	return 0
}


check_c_compiler_flag() { # flag
	# shellcheck disable=SC3043
	local __ENV_VAR_NAME __ENV_VAR_VAL __TEST_FLAG

	__ENV_VAR_NAME=$(echo "${*}_c_compiler_flag" | sed -e 's|/|_|g' -e 's|-|_|g' -e 's|+|_|g' -e 's|=|_|g' -e 's|\.|_|g' -e 's|,|_|g' -e 's| |_|g' | tr '[:lower:]' '[:upper:]')
	eval __ENV_VAR_VAL="\$${__ENV_VAR_NAME}" 2>/dev/null

	printf "%s" "-- Performing Test ${*} - "
	if [ '1' = "${__ENV_VAR_VAL}" ]; then
		echo 'Success ✅ (cached)'
		return 0
	fi
	if [ '0' = "${__ENV_VAR_VAL}" ]; then
		echo 'Failed ❌ (cached)'
		return 1
	fi
	# GCC workaround: strip the "no-" prefix if it exists for the compiler check.
	__TEST_FLAG="$(echo "${@}" | sed 's/^-Wno-/-W/')"
	if "${CC}" '-Werror' "${__TEST_FLAG}" -E - < /dev/null > /dev/null 2>&1 ; then
		echo 'Success ✅'
		eval "export ${__ENV_VAR_NAME}=1"
		return 0
	fi
	echo 'Failed ❌'
	eval "export ${__ENV_VAR_NAME}=0"
	return 1
}
check_c_linker_flag() { # flag
	# shellcheck disable=SC3043
	local __ENV_VAR_NAME __ENV_VAR_VAL __STD_ERR

	__ENV_VAR_NAME=$(echo "${*}_c_linker_flag" | sed -e 's|/|_|g' -e 's|-|_|g' -e 's|+|_|g' -e 's|=|_|g' -e 's|\.|_|g' -e 's|,|_|g' -e 's| |_|g' | tr '[:lower:]' '[:upper:]')
	eval __ENV_VAR_VAL="\$${__ENV_VAR_NAME}" 2>/dev/null

	printf "%s" "-- Performing Test ${*} - "
	if [ '1' = "${__ENV_VAR_VAL}" ]; then
		echo 'Success ✅ (cached)'
		return 0
	fi
	if [ '0' = "${__ENV_VAR_VAL}" ]; then
		echo 'Failed ❌ (cached)'
		return 1
	fi
	__STD_ERR=$(echo "int main() { return (0); }" | "${CC}" "${@}" -x c - -o /dev/null 2>&1 > /dev/null)
	# shellcheck disable=SC2181
	if [ '0' = "${?}" ] && [ -z "${__STD_ERR}" ]; then
		echo 'Success ✅'
		eval "export ${__ENV_VAR_NAME}=1"
		return 0
	fi
	echo 'Failed ❌'
	eval "export ${__ENV_VAR_NAME}=0"
	return 1
}

# Flags list, each line contain multiple flags to check.
# First avail flag from line - win, continue with next line.
check_c_compiler_flag_optional_one_of() { # flags list to select first avail
	# shellcheck disable=SC3043
	local __CFLAG

	# shellcheck disable=SC3043
	local IFS=' 	'
	# shellcheck disable=SC2068
	for __CFLAG in ${@}; do
		if check_c_compiler_flag "${__CFLAG}" ; then
			CFLAGS="${CFLAGS} ${__CFLAG}"
			break
		fi
	done
	return 1
}
check_c_compiler_flags_optional_one_of() { # flags list
	# shellcheck disable=SC3043
	local __CFLAG_ONE_OF

	for __CFLAG_ONE_OF in "${@}"; do
		# shellcheck disable=SC2086
		check_c_compiler_flag_optional_one_of ${__CFLAG_ONE_OF} || true
	done
	return 0
}

check_c_type_size() { # type
	# shellcheck disable=SC3043
	local __ENV_VAR_NAME __ENV_VAR_VAL __TEST_BIN_NAME
	__ENV_VAR_NAME=$(echo "sizeof_${1}" | sed -e 's| |_|g' | tr '[:lower:]' '[:upper:]')
	__TEST_BIN_NAME="${BUILD_DIR}/${__ENV_VAR_NAME}"
	eval __ENV_VAR_VAL="\$${__ENV_VAR_NAME}" 2>/dev/null

	printf "%s" "-- Looking for sizeof ${*} - "
	if [ -n "${__ENV_VAR_VAL}" ] && [ '1' = "${__ENV_VAR_VAL}" ]; then
		echo "found (${__ENV_VAR_VAL}) ✅ (cached)"
		return 0
	fi
	if [ '0' = "${__ENV_VAR_VAL}" ]; then
		echo 'not found ❌ (cached)'
		return 1
	fi
	if ( echo "#include <stddef.h>" ; echo "#include <stdint.h>" ; echo "#include <time.h>" ; echo "int main() { return (sizeof(${1})); }" ) | "${CC}" -o "${__TEST_BIN_NAME}" -x c - > /dev/null 2>&1 ; then
		"${__TEST_BIN_NAME}" || __ENV_VAR_VAL="${?}"
		rm -f "${__TEST_BIN_NAME}"
		echo "found (${__ENV_VAR_VAL}) ✅"
		eval "export ${__ENV_VAR_NAME}=${__ENV_VAR_VAL}"
		return 0
	fi
	echo 'not found ❌'
	eval "export ${__ENV_VAR_NAME}=0"
	return 1
}
check_c_types_size() { # types list
	# shellcheck disable=SC3043
	local __TYPE

	for __TYPE in "${@}"; do
		# shellcheck disable=SC2086
		check_c_type_size ${__TYPE} || true
	done
	return 0
}

check_c_function_exists() { # function_name
	# shellcheck disable=SC3043
	local __ENV_VAR_NAME __ENV_VAR_VAL

	__ENV_VAR_NAME=$(echo "${1}_function_exists" | sed -e 's|/|_|g' -e 's|-|_|g' -e 's|+|_|g' -e 's|=|_|g' -e 's|\.|_|g' -e 's|,|_|g' -e 's| |_|g' | tr '[:lower:]' '[:upper:]')
	eval __ENV_VAR_VAL="\$${__ENV_VAR_NAME}" 2>/dev/null

	printf "%s" "-- Looking for ${*} - "
	if [ '1' = "${__ENV_VAR_VAL}" ]; then
		echo 'found ✅ (cached)'
		return 0
	fi
	if [ '0' = "${__ENV_VAR_VAL}" ]; then
		echo 'not found ❌ (cached)'
		return 1
	fi
	if echo "int main() { void ${1}(); ${1}(); return (0); }" | "${CC}" -o /dev/null -x c - > /dev/null 2>&1 ; then
		echo 'found ✅'
		eval "export ${__ENV_VAR_NAME}=1"
		return 0
	fi
	echo 'not found ❌'
	eval "export ${__ENV_VAR_NAME}=0"
	return 1
}
check_c_functions_exists() { # functions_list
	# shellcheck disable=SC3043
	local __FUNC __TMP

	while read -r __FUNC; do
		[ -z "${__FUNC}" ] && continue
		if check_c_function_exists "${__FUNC}" ; then
			__TMP=$(echo "${__FUNC}" | tr '[:lower:]' '[:upper:]')
			CFLAGS="${CFLAGS} -DHAVE_${__TMP}=1"
		fi
	done <<-EOF
	$(printf '%s\n' "${FUNC_TO_CHECK}")
	EOF
	return 0
}

check_c_symbol_exists() { # symbol, file
	# shellcheck disable=SC3043
	local __ENV_VAR_NAME __ENV_VAR_VAL
	# XXX: probably we should cache ${@} as symbol+file item.
	__ENV_VAR_NAME=$(echo "${1}_symbol_exists" | sed -e 's|/|_|g' -e 's|-|_|g' -e 's|+|_|g' -e 's|=|_|g' -e 's|\.|_|g' -e 's|,|_|g' -e 's| |_|g' | tr '[:lower:]' '[:upper:]')
	eval __ENV_VAR_VAL="\$${__ENV_VAR_NAME}" 2>/dev/null

	printf "%s" "-- Looking for ${*} - "
	if [ '1' = "${__ENV_VAR_VAL}" ]; then
		echo 'found ✅ (cached)'
		return 0
	fi
	if [ '0' = "${__ENV_VAR_VAL}" ]; then
		echo 'not found ❌ (cached)'
		return 1
	fi
	if ( echo "#include <${2}>" ; echo "int main() { void *p = (void*)&${1}; return (0); }" ) | "${CC}" -o /dev/null -x c - > /dev/null 2>&1 ||
	   ( echo "#include <${2}>" ; echo "int main() { int i = (int)${1}; return (0); }" ) | "${CC}" -o /dev/null -x c - > /dev/null 2>&1 ; then
		echo 'found ✅'
		eval "export ${__ENV_VAR_NAME}=1"
		return 0
	fi
	echo 'not found ❌'
	eval "export ${__ENV_VAR_NAME}=0"
	return 1
}
check_c_symbols_exists() { # symbols_list
	# shellcheck disable=SC3043
	local __SYMBOL __TMP

	for __SYMBOL in "${@}"; do
		# shellcheck disable=SC3043
		local IFS=' 	'
		# shellcheck disable=SC2086
		if check_c_symbol_exists ${__SYMBOL} ; then
			__TMP=$(echo "${__SYMBOL}" | sed -e 's| .*||g' | tr '[:lower:]' '[:upper:]')
			CFLAGS="${CFLAGS} -DHAVE_${__TMP}=1"
		fi
	done
	return 0
}

check_c_include_file_exists() { # include_file
	# shellcheck disable=SC3043
	local __ENV_VAR_NAME __ENV_VAR_VAL
	__ENV_VAR_NAME=$(echo "${1}_include_exists" | sed -e 's|/|_|g' -e 's|-|_|g' -e 's|+|_|g' -e 's|=|_|g' -e 's|\.|_|g' -e 's|,|_|g' -e 's| |_|g' | tr '[:lower:]' '[:upper:]')
	eval __ENV_VAR_VAL="\$${__ENV_VAR_NAME}" 2>/dev/null

	printf "%s" "-- Looking for ${*} - "
	if [ '1' = "${__ENV_VAR_VAL}" ]; then
		echo 'found ✅ (cached)'
		return 0
	fi
	if [ '0' = "${__ENV_VAR_VAL}" ]; then
		echo 'not found ❌ (cached)'
		return 1
	fi
	if echo "#include <${1}>" | "${CC}" -x c -E - > /dev/null 2>&1 ; then
		echo 'found ✅'
		eval "export ${__ENV_VAR_NAME}=1"
		return 0
	fi
	echo 'not found ❌'
	eval "export ${__ENV_VAR_NAME}=0"
	return 1
}
check_c_include_files_exists() { # include_files_list
	# shellcheck disable=SC3043
	local __INC_FILE

	for __INC_FILE in "${@}"; do
		# shellcheck disable=SC3043
		local IFS=' 	'
		# shellcheck disable=SC2086
		check_c_include_file_exists ${__INC_FILE} || true
	done
	return 0
}


build_profile_appy() { # no args!
	# shellcheck disable=SC3043
	local __BUILD_TYPE_UPPER __CFLAG __CFLAGS __CFLAGS_OPTIONAL
	# shellcheck disable=SC3043
	local __CFLAGS_OPTIONAL_ONE_OF __CTYPES_SIZE __LDFLAG __LDFLAGS __LDFLAGS_OPTIONAL

	__BUILD_TYPE_UPPER=$(echo "${BUILD_TYPE}" | tr '[:lower:]' '[:upper:]')
	eval __CFLAGS="\$CFLAGS_${__BUILD_TYPE_UPPER}" 2>/dev/null
	eval __CFLAGS_OPTIONAL="\$CFLAGS_${__BUILD_TYPE_UPPER}_OPTIONAL" 2>/dev/null
	eval __CFLAGS_OPTIONAL_ONE_OF="\$CFLAGS_${__BUILD_TYPE_UPPER}_OPTIONAL_ONE_OF" 2>/dev/null
	eval __CTYPES_SIZE="\$CTYPES_SIZE_${__BUILD_TYPE_UPPER}" 2>/dev/null
	eval __LDFLAGS="\$LDFLAGS_${__BUILD_TYPE_UPPER}" 2>/dev/null
	eval __LDFLAGS_OPTIONAL="\$LDFLAGS_${__BUILD_TYPE_UPPER}_OPTIONAL" 2>/dev/null
	CFLAGS="${CFLAGS} ${__CFLAGS}"
	LDFLAGS="${LDFLAGS} ${__LDFLAGS}"

	# shellcheck disable=SC2153
	for __CFLAG in ${CFLAGS_OPTIONAL} ${__CFLAGS_OPTIONAL}; do
		if check_c_compiler_flag "${__CFLAG}" ; then
			CFLAGS="${CFLAGS} ${__CFLAG}"
		fi
	done

	# shellcheck disable=SC2086,SC2153
	check_c_compiler_flags_optional_one_of ${CFLAGS_OPTIONAL_ONE_OF} ${__CFLAGS_OPTIONAL_ONE_OF}

	# shellcheck disable=SC2086,SC2153
	check_c_types_size ${CTYPES_SIZE} ${__CTYPES_SIZE}

	# shellcheck disable=SC2153
	for __LDFLAG in ${LDFLAGS_OPTIONAL} ${__LDFLAGS_OPTIONAL}; do
		if check_c_linker_flag "${__LDFLAG}" ; then
			LDFLAGS="${LDFLAGS} ${__LDFLAG}"
		fi
	done

	return 0
}


# Var line format:
# type	name	value
# e - env var name with value
# eq - env var name with value, will be quoted
# t - text
# tq - text, will be quoted
config_h_write_line() { # filename, type, name, value
	# shellcheck disable=SC3043
	local __H_FILE_NAME __TMP

	__H_FILE_NAME="${1}"
	case "${2}" in
	'e')
		eval __TMP="\$${4}" 2>/dev/null
		echo "#define ${3}	${__TMP}" >> "${__H_FILE_NAME}"
		;;
	'eq')
		eval __TMP="\$${4}" 2>/dev/null
		echo "#define ${3}	\"${__TMP}\"" >> "${__H_FILE_NAME}"
		;;
	't')
		(	printf "%s" "#define ${3}	"
			shift 3
			echo "${*}"
		) >> "${__H_FILE_NAME}"
		;;
	'tq')
		(	printf "%s" "#define ${3}	\""
			shift 3
			echo "${*}\""
		) >> "${__H_FILE_NAME}"
		;;
	esac
	return 0
}
config_h_generate() { # filename, env vars list
	# shellcheck disable=SC3043
	local __H_FILE_NAME __VAR_LINE

	__H_FILE_NAME="${1}"
	# File header.
	echo '#ifndef __CONFIG_H__' > "${__H_FILE_NAME}"
	echo '#define __CONFIG_H__' >> "${__H_FILE_NAME}"
	echo '' >> "${__H_FILE_NAME}"
	# File content.
	shift 1 # Exclude arg from loop.
	for __VAR_LINE in "${@}"; do
		# shellcheck disable=SC3043
		local IFS=' 	'
		# shellcheck disable=SC2086
		config_h_write_line "${__H_FILE_NAME}" ${__VAR_LINE}
	done
	# File footer.
	echo '' >> "${__H_FILE_NAME}"
	echo '#endif /* __CONFIG_H__ */' >> "${__H_FILE_NAME}"
	return 0
}


# Add files to ${SRC} var from "env_var_name filename" list
# in case env_var_name is set.
add_required_srcs_ev_set_line() { # env_var_name filename
	# shellcheck disable=SC3043
	local __ENV_VAR_VAL
	eval __ENV_VAR_VAL="\$${1}" 2>/dev/null

	if [ -n "${__ENV_VAR_VAL}" ]; then
		SRCS="${SRCS}
${2}"
	fi
	return 0
}
add_required_srcs_ev_set() { # "env_var_name filename" list
	# shellcheck disable=SC3043
	local __SRC_LINE

	for __SRC_LINE in "${@}"; do
		# shellcheck disable=SC3043
		local IFS=' 	'
		# shellcheck disable=SC2086
		add_required_srcs_ev_set_line ${__SRC_LINE}
	done
	return 0
}

# Add files to ${SRC} var from "env_var_name env_var_value filename" list
# in ${case env_var_name} = env_var_value.
add_required_srcs_ev_val_line() { # env_var_name env_var_value filename
	# shellcheck disable=SC3043
	local __ENV_VAR_VAL
	eval __ENV_VAR_VAL="\$${1}" 2>/dev/null

	if [ "${2}" = "${__ENV_VAR_VAL}" ]; then
		SRCS="${SRCS}
${3}"
	fi
	return 0
}
add_required_srcs_ev_val() { # "env_var_name filename" list
	# shellcheck disable=SC3043
	local __SRC_LINE

	for __SRC_LINE in "${@}"; do
		# shellcheck disable=SC3043
		local IFS=' 	'
		# shellcheck disable=SC2086
		add_required_srcs_ev_val_line ${__SRC_LINE}
	done
	return 0
}


# compile.
# ARGS: files_list
# ENV VARS: JOBS, BUILD_SYS_DIR, SRC_DIR, BUILD_DIR, CC, CFLAGS, MODULES_CFLAGS
c_compiler_compile() { # files_list
	# shellcheck disable=SC3043
	local __FILE_NAME __FILES_LIST

	# Preparing files list.
	__FILES_LIST=''
	for __FILE_NAME in "${@}"; do
		[ -z "${__FILE_NAME}" ] && continue
		if [ -f "${__FILE_NAME}" ]; then
			__FILES_LIST=$(printf '%s\n%s' "${__FILES_LIST}" "${__FILE_NAME}")
		else
			__FILES_LIST=$(printf '%s\n%s/%s' "${__FILES_LIST}" "${SRC_DIR}" "${__FILE_NAME}")
		fi
	done

	CFLAGS="-I${BUILD_DIR} -fdiagnostics-color=always ${CFLAGS} ${MODULES_CFLAGS}"
	export BUILD_DIR
	export SRC_DIR
	export CC
	export CFLAGS

	printf '%s\n' "${__FILES_LIST}" | grep -v '^[[:space:]]*$' | sort -u | tr '\n' '\0' | xargs -0 -s 4096 -n 1 -P "${JOBS}" sh "${BUILD_SYS_DIR}/ssbs_c_compiler.sh"
}


# Link static lib.
# ARGS: result_file_name, files_list
# ENV VARS: BUILD_DIR, AR, RANLIB
c_compiler_link_static_lib() { # result_file_name, files_list
	# shellcheck disable=SC3043
	local __RES_FILE_NAME __FILE_NAME __FILES_LIST

	__RES_FILE_NAME="${BUILD_DIR}/${1}"
	__FILES_LIST=''
	shift 1 # Exclude arg from loop.
	for __FILE_NAME in "${@}"; do
		__FILE_NAME=$(echo "${__FILE_NAME}" | sed -e 's|/|_|g' -e 's|\.c$|.o|g' -e 's|\.\.|up_|g')
		if [ -f "${__FILE_NAME}" ]; then
			__FILES_LIST=$(printf "%s\n%s" "${__FILES_LIST}" "${__FILE_NAME}")
		else
			__FILES_LIST=$(printf "%s\n%s/%s" "${__FILES_LIST}" "${BUILD_DIR}" "${__FILE_NAME}")
		fi
	done

	echo "${AR} ${__RES_FILE_NAME} ${__FILES_LIST}"
	# shellcheck disable=SC2086
	eval "${AR}" "${__RES_FILE_NAME}" ${__FILES_LIST}
	echo
	echo "${RANLIB} ${__RES_FILE_NAME}"
	eval "${RANLIB}" "${__RES_FILE_NAME}"
	echo
}

# Link shared lib.
# ARGS: result_file_name, files_list
# ENV VARS: BUILD_DIR, CC, CFLAGS, MODULES_CFLAGS, MODULES_LIBS_SHARED, LIBS, LDFLAGS
c_compiler_link_shared_lib() { # result_file_name, files_list
	# shellcheck disable=SC3043
	local __RES_FILE_NAME __FILE_NAME __FILES_LIST __CFLAGS

	__RES_FILE_NAME="${BUILD_DIR}/${1}"
	__FILES_LIST=''
	shift 1 # Exclude arg from loop.
	for __FILE_NAME in "${@}"; do
		__FILE_NAME=$(echo "${__FILE_NAME}" | sed -e 's|/|_|g' -e 's|\.c$|.o|g' -e 's|\.\.|up_|g')
		if [ -f "${__FILE_NAME}" ]; then
			__FILES_LIST=$(printf "%s\n%s" "${__FILES_LIST}" "${__FILE_NAME}")
		else
			__FILES_LIST=$(printf "%s\n%s/%s" "${__FILES_LIST}" "${BUILD_DIR}" "${__FILE_NAME}")
		fi
	done
	__CFLAGS=$(echo "${CFLAGS} ${MODULES_CFLAGS}" | sed -E -e 's/ -[DIW][^ ]*//g' -e 's/^-[DIW][^ ]*( )?//g' -e 's/ *$//g')

	echo "${CC} -shared -o ${__RES_FILE_NAME} ${__FILES_LIST} ${__CFLAGS} ${MODULES_LIBS_SHARED} ${LIBS} ${LDFLAGS}"
	# shellcheck disable=SC2086
	eval "${CC}" -shared -o "${__RES_FILE_NAME}" ${__FILES_LIST} "${__CFLAGS}" "${MODULES_LIBS_SHARED}" "${LIBS}" "${LDFLAGS}"
	echo
}

# Link executable.
# ARGS: result_file_name, files_list
# ENV VARS: BUILD_DIR, CC, CFLAGS, MODULES_CFLAGS, MODULES_LIBS_SHARED, LIBS, LDFLAGS
c_compiler_link_executable() { # result_file_name, files_list
	# shellcheck disable=SC3043
	local __RES_FILE_NAME __FILE_NAME __FILES_LIST __CFLAGS

	__RES_FILE_NAME="${BUILD_DIR}/${1}"
	__FILES_LIST=''
	shift 1 # Exclude arg from loop.
	for __FILE_NAME in "${@}"; do
		__FILE_NAME=$(echo "${__FILE_NAME}" | sed -e 's|/|_|g' -e 's|\.c$|.o|g' -e 's|\.\.|up_|g')
		if [ -f "${__FILE_NAME}" ]; then
			__FILES_LIST=$(printf "%s\n%s" "${__FILES_LIST}" "${__FILE_NAME}")
		else
			__FILES_LIST=$(printf "%s\n%s/%s" "${__FILES_LIST}" "${BUILD_DIR}" "${__FILE_NAME}")
		fi
	done
	__CFLAGS=$(echo "${CFLAGS} ${MODULES_CFLAGS}" | sed -E -e 's/ -[DIW][^ ]*//g' -e 's/^-[DIW][^ ]*( )?//g' -e 's/ *$//g')

	echo "${CC} -o ${__RES_FILE_NAME} ${__FILES_LIST} ${__CFLAGS} ${MODULES_LIBS_SHARED} ${LIBS} ${LDFLAGS}"
	# shellcheck disable=SC2086
	eval "${CC}" -o "${__RES_FILE_NAME}" ${__FILES_LIST} "${__CFLAGS}" "${MODULES_LIBS_SHARED}" "${LIBS}" "${LDFLAGS}"
	echo
}


target_dist_git() {
	# shellcheck disable=SC3043
	local __FILE_NAME __PREFIX __FILES_LIST

	__FILE_NAME="${1}"
	__PREFIX=$(basename "${__FILE_NAME}" | sed -e 's|\.tar.*$||g')
	__FILES_LIST=$(mktemp -q '/tmp/files-XXXXXXXX')

	git ls-files > "${__FILES_LIST}"
	for __SUBMOD in $(git submodule | awk '{ print $2 }'); do
		git -C "${__SUBMOD}" ls-files | sed -e "s|^|${__SUBMOD}/|" >> "${__FILES_LIST}"
	done

	cat "${__FILES_LIST}"
	"${TAR}" -c --exclude='.[^/]*' --exclude='*.xz' --exclude='*.gz' --no-recursion -a -T "${__FILES_LIST}" -v -f "${__FILE_NAME}"
	rm -f "${__FILES_LIST}"
	return 0
}

target_help() {
	echo 'Usage'
}


# Init constants.
# To avoid having each word of the reason treated separately.
IFS='
'

SYSTEM_NAME=$(uname -s)
case "${SYSTEM_NAME}" in
CYGWIN*|MINGW*|MSYS*)
	echo "Operating System: Windows (Bash environment)"
	;;
Darwin*)
	echo "Operating System: macOS (OSX)"
	: "${TAR:=gnutar}"
	;;
FreeBSD*)
	echo "Operating System: FreeBSD"
	: "${CC:=$(make -C '/tmp' -V 'CC')}"
	: "${CFLAGS:=$(make -C '/tmp' -V 'CFLAGS')}"
	: "${LDFLAGS:=$(make -C '/tmp' -V 'LDFLAGS')}"
	;;
Linux*)
	echo "Operating System: Linux"
	;;
*)
	echo "Operating System: Unknown (${SYSTEM_NAME})"
	;;
esac


: "${BUILD_TYPE:=release}"
: "${CC:=gcc}"
: "${CFLAGS:=}"
: "${LDFLAGS:=}"
: "${AR:=ar rc}"
: "${RANLIB:=ranlib}"
: "${TAR:=tar}"
: "${JOBS:=$(getconf _NPROCESSORS_ONLN)}"


MODULES_CFLAGS=''
MODULES_LIBS_STATIC=''
MODULES_LIBS_SHARED=''


build_sys_start() {
	if [ -n "${1}" ]; then
		TARGET="${1}"
	else
		TARGET='build'
	fi

	if [ ${#} -gt 1 ]; then
		shift 1
	fi
	"target_${TARGET}" "${@}"
}
