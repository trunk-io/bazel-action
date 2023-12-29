#!/usr/bin/env bash

set -euo pipefail

workspace_path="${WORKSPACE_PATH-}"
if [[ -z ${workspace_path} ]]; then
	workspace_path=$(pwd)
fi

# If we're not in the workspace, we need to run from there (e.g. for bazel info)
cd "${workspace_path}"

# Setup bazel-diff if necessary
if command -v bazel-diff; then
	_bazel_diff="bazel-diff"
else
	_java=$(bazel info java-home)/bin/java

	# Install the bazel-diff JAR. Avoid cloning the repo, as there will be conflicting WORKSPACES.
	curl --retry 5 -Lo bazel-diff.jar https://github.com/Tinder/bazel-diff/releases/latest/download/bazel-diff_deploy.jar
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
