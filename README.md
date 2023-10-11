# bazel-action

Provides a GitHub Action for computing, uploading, and testing bazel targets. Functions as an extension to the [Trunk Merge GitHub Action](https://github.com/trunk-io/merge-action). To get beta access to the Merge Graph, contact us
on [Slack](https://slack.trunk.io).

## Overview

Using impacted targets lets you only test what you need to test, saving CI time and money! Use this action to upload targets to the Trunk MergeGraph or to run tests on impacted targets directly, or both!

Trunk’s MergeGraph keeps your main branch green by ensuring that tests pass prior to merging your
main branch. The MergeGraph, unlike traditional MergeQueues, increases throughput by only testing
dependent PRs; no more waiting for your backend changes to test before landing your docs!

### How the MergeGraph Works

After creating a MergeGraph at [app.trunk.io](app.trunk.io), simply comment `/trunk merge` on your
PRs to submit it to the graph. Once the graph has passed the prerequisites to be admitted into the
graph (impacted targets have been uploaded, Github deems the PR mergeable), the Trunk Service will
en-graph the PR, constructing a test branch between the PR and all of its ancestors. On successful
completion of tests, Trunk merges the PR, keeping your main branch green 😎.

## Usage

<!-- start usage -->

```yaml
name: Upload and Test Impacted Targets
on: pull_request

jobs:
  impacted_targets:
    name: Impacted Targets
    runs-on: ubuntu-latest
    steps:
      - name: Checkout
        uses: actions/checkout@v3

      - name: Upload and Test Impacted Targets
        uses: trunk-io/bazel-action@v1
        with:
          ### To upload targets (default true)
          upload-targets: "true"
          ### To run tests (default false)
          test-targets: "true"
          ### Use your repositories API token to authenticate impacted targets uploads.
          trunk-token: ${{ secrets.TRUNK_REPO_API_TOKEN }}
```

<!-- end usage -->

### Tests

```
pnpm install
pnpm test
```

### What is an Impacted Target?

An impacted target is a unit that is affected by a particular PR. For example, a change at
`src/backend/app` will impact the Bazel `src/backend` package. Any two pull requests that share an
impacted target must be tested together; otherwise, they can be tested independently.

We currently support Bazel; other solutions, such as Buck, Nx, etc. are on the way! You may also
define your own suite of impacted targets using glob-based targets.

### Under the hood: Bazel

We use Tinder's [bazel-diff](https://github.com/Tinder/bazel-diff) tool to compute the impacted
targets of a particular PR. The tool computes a mapping of package --> hash at the source and dest
shas, then reports any packages which have a differing hash.
