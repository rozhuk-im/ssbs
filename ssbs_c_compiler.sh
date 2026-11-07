#!/bin/sh
### Rozhuk Ivan 2026
### Shell script based build system: C compiller wrapper

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


# No exit on error.
set +e

# Init constans.
INPUT_FILE_NAME="${1}"
INPUT_FILE_NAME_BASE=$(echo "${INPUT_FILE_NAME}" | sed -e "s|${SRC_DIR}/||g")
OUTPUT_FILE_NAME="${BUILD_DIR}/$(echo "${INPUT_FILE_NAME_BASE}" | sed -e 's|/|_|g' -e 's|\.c$|.o|g' -e 's|\.\.|up_|g')"

# Do we need to recompile?
#if ! [ "${INPUT_FILE_NAME}" -nt "${OUTPUT_FILE_NAME}" ]; then
#	echo "${INPUT_FILE_NAME}: not changed."
#	exit 0
#fi

# shellcheck disable=SC2086
__STD_ALL=$("${CC}" ${CFLAGS} -c "${INPUT_FILE_NAME}" -o "${OUTPUT_FILE_NAME}" 2>&1)
__EXIT_CODE="${?}"

printf "%s\n%s\n" "${CC} ${CFLAGS} -c ${INPUT_FILE_NAME} -o ${OUTPUT_FILE_NAME}" "${__STD_ALL}"

if [ '0' != "${__EXIT_CODE}" ]; then
	exit 255
fi

# Copy file time.
#touch -r "${INPUT_FILE_NAME}" "${OUTPUT_FILE_NAME}"

exit 0
