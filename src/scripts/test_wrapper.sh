#!/usr/bin/env bash

set -euo pipefail

# TODO: TYLER CONSIDER BEHAVIOR WITH FORKS

##################################################
##### Handle Command Line Flags and Defaults #####
##################################################
tempdir=$(mktemp -d)
scripts_dir=$(dirname "${BASH_SOURCE[0]}")

PR_BRANCH=$(git branch --show-current)
if [[ -z ${PR_BRANCH} ]]; then
	PR_BRANCH="HEAD"
fi
TARGET_BRANCH=main
BAZEL_PATH=/home/tyler/repos/trunk/.trunk/tools/bazel
CACHE_DIR="${HOME}/.cache/trunk/bazel-diff"
# VERBOSE=1 # TODO: REMOVE

#################
##### Utils #####
#################
try_checkout_head() {
	if [[ -n ${head+x} ]]; then
		git checkout -q "${head}"
		unset head
	fi
}

try_reset() {
	if [[ -n ${reset_hash+x} ]]; then
		git reset -q "${reset_hash}"
		unset reset_hash
	fi
}

try_rm_tempdir() {
	if [[ -n ${tempdir+x} ]]; then
		rm -rf "${tempdir}"
		unset tempdir
	fi
}

cleanup() {
	try_checkout_head
	try_reset
	try_rm_tempdir
}

trap 'cleanup' EXIT

#####################
##### Git setup #####
#####################
# If there are any uncommitted changes then commit them, we will undo this on exit.
status="$(git status --porcelain)"
if [[ -n ${status} ]]; then
	reset_hash=$(git rev-parse HEAD)
	git -c "user.name=Trunk Actions" -c "user.email=actions@trunk.io" commit -qnam "test-impacted-targets" --allow-empty
fi

# The new hash after commiting.
head_hash=$(git rev-parse HEAD)

if ! head=$(git symbolic-ref -q --short HEAD); then
	head=${head_hash}
fi

##############################
##### Call prerequisites #####
##############################
GITHUB_OUTPUT="${tempdir}/bazel_action_prerequisites.txt"
rm -f "${GITHUB_OUTPUT}"
touch "${GITHUB_OUTPUT}"

echo "RUNNING PREREQS" # TODO: REMOVE
. ${scripts_dir}/prerequisites.sh
echo "DONE WITH PREREQS" # TODO: REMOVE

cat ${GITHUB_OUTPUT} # TODO: REMOVE

# Use merge base sha instead of merge head sha to calculate the correct diff for testing.
MERGE_INSTANCE_BRANCH_HEAD_SHA=$(awk -F "=" '$1=="merge_base_sha" {print $2}' ${GITHUB_OUTPUT})
PR_BRANCH=$(awk -F "=" '$1=="pr_branch" {print $2}' ${GITHUB_OUTPUT})
PR_BRANCH_HEAD_SHA=$(awk -F "=" '$1=="pr_branch_head_sha" {print $2}' ${GITHUB_OUTPUT})
WORKSPACE_PATH=$(awk -F "=" '$1=="workspace_path" {print $2}' ${GITHUB_OUTPUT})
BAZEL_DIFF_CMD=$(awk -F "=" '$1=="bazel_diff_cmd" {print $2}' ${GITHUB_OUTPUT})

################################
##### Call compute targets #####
################################
GITHUB_OUTPUT="${tempdir}/bazel_action_compute.txt"
rm -f "${GITHUB_OUTPUT}"
touch "${GITHUB_OUTPUT}"

echo "RUNNING COMPUTE TARGETS" # TODO: REMOVE
. ${scripts_dir}/compute_impacted_targets.sh
echo "DONE WITH COMPUTE TARGETS" # TODO: REMOVE

IMPACTED_TARGETS_FILE=$(awk -F "=" '$1=="impacted_targets_out" {print $2}' ${GITHUB_OUTPUT})
BAZEL_KIND_FILTER=".+_library|.+_binary|.+_test"
BAZEL_NEGATIVE_KIND_FILTER="generated file"
BAZEL_NEGATIVE_SCOPE_FILTER="//external"

###################################
##### Filter and Test targets #####
###################################
echo "RUNNING TESTING TARGETS" # TODO: REMOVE
. ${scripts_dir}/test_impacted_targets.sh
echo "DONE WITH TESTING TARGETS" # TODO: REMOVE
