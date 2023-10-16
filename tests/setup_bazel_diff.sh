#!/usr/bin/env bash

set -euo pipefail

_java=$(bazel info java-home)/bin/java
curl --retry 5 -Lo bazel-diff.jar https://github.com/Tinder/bazel-diff/releases/latest/download/bazel-diff_deploy.jar
"${_java}" -jar bazel-diff.jar -V
echo "bazel_diff_cmd=${_java} -jar ./tests/simple_bazel_workspace/bazel-diff.jar" >>"${GITHUB_OUTPUT}"
