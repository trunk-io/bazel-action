#!/usr/bin/env bash

set -euo pipefail
shopt -s expand_aliases

##################################
##### Validate required vars #####
##################################
if [[ -z ${PR_BRANCH} ]]; then
	echo "Missing branch"
	exit 2
fi

if [[ (-z ${MERGE_INSTANCE_BRANCH_HEAD_SHA}) || (-z ${PR_BRANCH_HEAD_SHA}) ]]; then
	echo "Missing sha"
	exit 2
fi

original_branch="${PR_BRANCH}"
if [[ ${original_branch} == "HEAD" ]]; then
	original_branch="${PR_BRANCH_HEAD_SHA}"
fi

if [[ -z ${WORKSPACE_PATH} ]]; then
	echo "Missing workspace path"
	exit 2
fi

#################
##### Utils #####
#################
ifVerbose() {
	if [[ -n ${VERBOSE-} ]]; then
		"$@"
	fi
}

logIfVerbose() {
	# trunk-ignore(shellcheck/SC2312): Always query date with each echo statement.
	ifVerbose echo "$(date -u)" "$@"
}

# If specified, parse the Bazel startup options when generating hashes.
bazel_startup_options=""
if [[ -n ${BAZEL_STARTUP_OPTIONS-} ]]; then
	bazel_startup_options=$(echo "${BAZEL_STARTUP_OPTIONS}" | tr ',' ' ')
fi
logIfVerbose "Bazel startup options" "${bazel_startup_options}"

_bazel() {
	# trunk-ignore(shellcheck)
	${BAZEL_PATH} ${bazel_startup_options} "$@"
}

_bazel_diff() {
	if [[ -n ${VERBOSE-} ]]; then
		${BAZEL_DIFF_CMD} "$@" --verbose
	else
		${BAZEL_DIFF_CMD} "$@"
	fi
}

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

cleanup() {
	try_checkout_head
	try_reset
}

trap 'cleanup' EXIT

generate_hashes() {
	echo "generating hashes 1"
	_bazel_diff generate-hashes \
		--bazelPath "${BAZEL_PATH}" \
		-so="${bazel_startup_options}" \
		--workspacePath "${WORKSPACE_PATH}" \
		--bazelCommandOptions "--noshow_progress" \
		"$1"
	echo "generating hashes 1 done"
}

cache_dir=${CACHE_DIR:-.}

#####################
##### Git setup #####
#####################
## Verbose logging for the Merge Instance and PR branch.
if [[ -n ${VERBOSE-} ]]; then
	# Find the merge base of the two branches
	merge_base_sha=$(git merge-base "${MERGE_INSTANCE_BRANCH_HEAD_SHA}" "${PR_BRANCH_HEAD_SHA}")
	echo "Merge Base= ${merge_base_sha}"

	# Find the number of commits between the merge base and the merge instance's HEAD
	merge_instance_depth=$(git rev-list "${merge_base_sha}".."${MERGE_INSTANCE_BRANCH_HEAD_SHA}" | wc -l)
	echo "Merge Instance Depth= ${merge_instance_depth}"

	git checkout -q "${MERGE_INSTANCE_BRANCH_HEAD_SHA}"
	git log -n "${merge_instance_depth}" --oneline | cat

	# Find the number of commits between the merge base and the PR's HEAD
	pr_depth=$(git rev-list "${merge_base_sha}".."${PR_BRANCH_HEAD_SHA}" | wc -l)
	echo "PR Depth= ${pr_depth}"

	git checkout -q "${original_branch}"
	git log -n "${pr_depth}" --oneline | cat
fi

###########################
##### Compute targets #####
###########################
# Output Files
merge_instance_branch_out=${cache_dir}/${MERGE_INSTANCE_BRANCH_HEAD_SHA}
merge_instance_with_pr_branch_out=${cache_dir}/${PR_BRANCH_HEAD_SHA}_${MERGE_INSTANCE_BRANCH_HEAD_SHA}
impacted_targets_out=${cache_dir}/impacted_targets_${PR_BRANCH_HEAD_SHA}

# Generate Hashes for the Merge Instance/Upstream Branch if needed
if [[ -e ${merge_instance_branch_out} ]]; then
	logIfVerbose "Hashes for upstream already exist in cache: ${merge_instance_branch_out}..."
else
	# The tool changes your git branch, make sure the final hash is the symbolic name of the currently
	# checked out branch so that we are back where we started. If we are in a detached state then just
	# use the hash.
	if ! head=$(git symbolic-ref -q --short HEAD); then
		head=${head_hash}
	fi
	logIfVerbose "Hashes for upstream don't exist in cache, changing branch and computing..."
	git checkout -q "${MERGE_INSTANCE_BRANCH_HEAD_SHA}"
	generate_hashes "${merge_instance_branch_out}"
	try_checkout_head
fi

# Generate Hashes for the Merge Instance/Upstream Branch + PR Branch
if [[ -e ${merge_instance_with_pr_branch_out} ]]; then
	logIfVerbose "Hashes for merge result already exist: ${merge_instance_branch_out}..."
else
	logIfVerbose "Hashes for merge result don't exist in cache, merging and computing..."
	git -c "user.name=Trunk Actions" -c "user.email=actions@trunk.io" merge --squash "${original_branch}"
	generate_hashes "${merge_instance_with_pr_branch_out}"
fi

# Reset back to the original branch
git checkout -q "${original_branch}"

# Compute impacted targets
_bazel_diff get-impacted-targets --startingHashes="${merge_instance_branch_out}" --finalHashes="${merge_instance_with_pr_branch_out}" --output="${impacted_targets_out}"

num_impacted_targets=$(wc -l <"${impacted_targets_out}")
echo "Computed ${num_impacted_targets} targets for sha ${PR_BRANCH_HEAD_SHA}"

# Outputs
if [[ -v GITHUB_OUTPUT && -f ${GITHUB_OUTPUT} ]]; then
	echo "impacted_targets_out=${impacted_targets_out}" >>"${GITHUB_OUTPUT}"
else
	echo "::set-output name=impacted_targets_out::${impacted_targets_out}"
fi
