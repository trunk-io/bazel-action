#!/usr/bin/env bash

set -euo pipefail

workspace_path="${WORKSPACE_PATH-}"
if [[ -z ${workspace_path} ]]; then
	workspace_path=$(pwd)
fi

# If we're not in the workspace, we need to run from there (e.g. for bazel info)
cd "${workspace_path}"

# Pin the release rather than tracking `latest`: bazel-diff rewrote its CLI in Rust and stopped
# publishing `bazel-diff_deploy.jar` as of v48.0.0, and the flags compute_impacted_targets.sh passes
# are only valid for a specific range of releases. Bump this deliberately after verifying those flags.
bazel_diff_version="${BAZEL_DIFF_VERSION:-v47.0.0}"

try_bazel_diff() {
	curl --retry 5 -Lo bazel-diff.jar "$1" --fail && "${_java}" -jar bazel-diff.jar -V
}

# Setup bazel-diff if necessary
if command -v bazel-diff; then
	_bazel_diff="bazel-diff"
else
	_java=$(bazel info java-home)/bin/java

	# Install the bazel-diff JAR. Avoid cloning the repo, as there will be conflicting WORKSPACES.
	if ! try_bazel_diff "https://github.com/Tinder/bazel-diff/releases/download/${bazel_diff_version}/bazel-diff_deploy.jar"; then
		echo "Failed to install bazel-diff ${bazel_diff_version}"
		exit 1
	fi
	"${_java}" -jar bazel-diff.jar -V
	bazel version # Does not require running with startup options.

	_bazel_diff="${_java} -jar ${workspace_path}/bazel-diff.jar"
fi

# Outputs
if [[ -v GITHUB_OUTPUT && -f ${GITHUB_OUTPUT} ]]; then
	echo "bazel_diff_cmd=${_bazel_diff}" >>"${GITHUB_OUTPUT}"
else
	echo "::set-output name=bazel_diff_cmd::${_bazel_diff}"
fi
