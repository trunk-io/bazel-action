#!/usr/bin/env bash

set -euo pipefail

if [[ $1 == "test" ]]; then
	echo "Using bazel testing stub for $@"
	targets_file=$(echo $3 | awk -F "=" '{print $2}')
	diff "${targets_file}" "${TEST_TARGETS_EXPECTED_FILE}"
	num_targets=$(wc -l "${targets_file}")

	echo "detected_test_targets=${num_targets}" >>"${GITHUB_OUTPUT}"
else
	bazel "$@"
fi
