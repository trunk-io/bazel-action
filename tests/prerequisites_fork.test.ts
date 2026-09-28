/** Test that prerequisites.sh resolves a fork PR's head, which exists on origin only as refs/pull/N/head. */
import { execFileSync, spawnSync } from "node:child_process";
import fs from "node:fs";
import os from "node:os";
import path from "node:path";

const SCRIPT = path.resolve("src/scripts/prerequisites.sh");

const git = (cwd: string, ...args: string[]) =>
  execFileSync("git", ["-c", "user.name=t", "-c", "user.email=t@t", ...args], {
    cwd,
    encoding: "utf8",
  }).trim();

describe("prerequisites on a fork pull request", () => {
  let dir: string;
  let checkout: string;
  let forkSha: string;

  beforeEach(() => {
    dir = fs.mkdtempSync(path.join(os.tmpdir(), "prereq-fork-"));
    const origin = path.join(dir, "origin.git");
    const work = path.join(dir, "work");
    git(dir, "init", "-q", "--bare", "-b", "main", origin);
    git(dir, "init", "-q", "-b", "main", work);
    git(work, "commit", "-q", "--allow-empty", "-m", "base");
    git(work, "push", "-q", `file://${origin}`, "main");
    git(work, "checkout", "-q", "-b", "fork-branch");
    git(work, "commit", "-q", "--allow-empty", "-m", "fork change");
    forkSha = git(work, "rev-parse", "HEAD");
    // A fork's head reaches the base repository only as a pull ref, never as a branch.
    git(work, "push", "-q", `file://${origin}`, "HEAD:refs/pull/7/head");
    checkout = path.join(dir, "checkout");
    git(dir, "clone", "-q", "--depth=1", `file://${origin}`, checkout);
  });

  afterEach(() => {
    fs.rmSync(dir, { recursive: true, force: true });
  });

  const run = (env: Record<string, string>) => {
    const output = path.join(dir, "github_output");
    fs.writeFileSync(output, "");
    const result = spawnSync("bash", [SCRIPT], {
      cwd: checkout,
      env: {
        PATH: process.env.PATH,
        GITHUB_OUTPUT: output,
        TARGET_BRANCH: "main",
        DEFAULT_BRANCH: "main",
        PR_BRANCH: "fork-branch",
        WORKSPACE_PATH: checkout,
        BAZEL_PATH: "/bin/true",
        ...env,
      },
      encoding: "utf8",
    });
    const outputs = Object.fromEntries(
      fs
        .readFileSync(output, "utf8")
        .split("\n")
        .filter(Boolean)
        .map((line) => line.split("=", 2)),
    );
    return { status: result.status, stderr: result.stderr, outputs };
  };

  it("uses the event's head sha", () => {
    const { status, outputs } = run({ PR_HEAD_SHA: forkSha });
    expect(status).toBe(0);
    expect(outputs.pr_branch_upload_head_sha).toBe(forkSha);
  });

  // Proves the fixture is a fork: its branch is not on origin.
  it("cannot resolve the head from the branch name alone", () => {
    const { status, stderr } = run({});
    expect(status).not.toBe(0);
    expect(stderr).toContain("couldn't find remote ref fork-branch");
    expect(stderr).toContain("unknown revision");
  });

  // The action's own CI matrix sets PR_SETUP_BRANCH on pull_request events, where PR_HEAD_SHA is set too.
  it("keeps the test matrix on its setup branch", () => {
    git(checkout, "checkout", "-q", "-b", "setup-branch");
    git(checkout, "commit", "-q", "--allow-empty", "-m", "setup");
    const setupSha = git(checkout, "rev-parse", "setup-branch");
    git(checkout, "checkout", "-q", "main");
    expect(setupSha).not.toBe(forkSha);
    expect(setupSha).not.toBe(git(checkout, "rev-parse", "origin/main"));
    const { status, outputs } = run({ PR_HEAD_SHA: forkSha, PR_SETUP_BRANCH: "setup-branch" });
    expect(status).toBe(0);
    expect(outputs.pr_branch_upload_head_sha).toBe(setupSha);
  });
});
