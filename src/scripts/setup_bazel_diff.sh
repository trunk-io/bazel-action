#!/usr/bin/env bash

set -euo pipefail

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
	# trunk-ignore(shellcheck/SC2129)
	echo "bazel_diff_cmd=${_bazel_diff}" >>"${GITHUB_OUTPUT}"
else
	echo "::set-output name=bazel_diff_cmd::${_bazel_diff}"
fi
