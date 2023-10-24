#!/usr/bin/env bash

set -euo pipefail

tempdir=$(mktemp -d)
info_color="\033[1;36m"
reset="\033[0m"

bazel_startup_options=""
if [[ -n ${BAZEL_STARTUP_OPTIONS-} ]]; then
	bazel_startup_options=$(echo "${BAZEL_STARTUP_OPTIONS}" | tr ',' ' ')
fi

_bazel() {
	# trunk-ignore(shellcheck)
	${BAZEL_PATH} ${bazel_startup_options} "$@"
}

##########################
##### Filter targets #####
##########################

exec 3>"${tempdir}/query.txt"
echo "let targets = set(" >&3
sed -e "s/^/'/g" -e "s/\$/'/g" <"${IMPACTED_TARGETS_FILE}" >&3
echo ") in" >&3
if [[ -n ${BAZEL_SCOPE_FILTER} ]]; then
	echo "let targets = filter('${BAZEL_SCOPE_FILTER}', \$targets) in" >&3
fi
echo "let targets = kind('${BAZEL_KIND_FILTER}', \$targets) in" >&3
# trunk-ignore(shellcheck/SC2016)
echo '$targets' >&3
if [[ -n ${BAZEL_NEGATIVE_KIND_FILTER} ]]; then
	echo "- kind('${BAZEL_NEGATIVE_KIND_FILTER}', \$targets)" >&3
fi
if [[ -n ${BAZEL_NEGATIVE_SCOPE_FILTER} ]]; then
	echo "- filter('${BAZEL_NEGATIVE_SCOPE_FILTER}', \$targets)" >&3
fi
exec 3>&-

_bazel query --query_file="${tempdir}/query.txt" >"${tempdir}/filtered_targets.txt"

# List the targets in a collapsed list if running on GH.
if [[ -n ${CI+x} ]]; then
	echo "::group::All targets"
	cat "${IMPACTED_TARGETS_FILE}"
	echo "::endgroup::"
	echo "::group::Query"
	cat "${tempdir}/query.txt"
	echo "::endgroup::"
	echo "::group::Filtered targets"
	cat "${tempdir}/filtered_targets.txt"
	echo "::endgroup::"
fi

# Run bazel test.
target_count=$(wc -l <"${tempdir}/filtered_targets.txt")

if [[ ${target_count} -eq 0 ]]; then
	echo -e "${info_color}Nothing to test (no affected targets)"
	exit 0
fi

echo -e "${info_color}Running bazel ${BAZEL_TEST_COMMAND} on ${target_count} targets...${reset}"

echo
ret=0
_bazel "${BAZEL_TEST_COMMAND}" --target_pattern_file="${tempdir}/filtered_targets.txt" || ret=$?

# Lazily cleanup tempdir since we rely on other wrappers' trap invocations
if [[ -n ${tempdir+x} ]]; then
	rm -rf "${tempdir}"
	unset tempdir
fi

# Exit code 4 from bazel test means: Build successful but no tests were found even though testing was requested.
# This is ok since this change may legitimately cause no test targets to run.
if [[ ${ret} -eq 4 ]]; then
	exit 0
fi

exit "${ret}"
