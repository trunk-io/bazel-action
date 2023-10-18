#!/usr/bin/env bash

set -euo pipefail

is_test=false
targets_file=""

for var in "$@"; do
	if [[ ${var} == "test" ]]; then
		is_test=true
	elif [[ ${var} =~ ^--target_pattern_file ]]; then
		targets_file=$(echo "${var}" | awk -F "=" '{print $2}')
	fi
done

if [[ ${is_test} == true ]]; then
	echo "Using bazel testing stub for $*"
	diff "${targets_file}" "${TEST_TARGETS_EXPECTED_FILE}"
	num_targets=$(wc -l "${targets_file}")

	echo "detected_test_targets=${num_targets}" >>"${GITHUB_OUTPUT}"
else
	bazel "$@"
fi
