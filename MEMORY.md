# Project memory

What every agent on Dokulo should know that the code and the docs don't tell
you: the owner's rules, the decisions already made, and lessons that cost
time. `CLAUDE.md` imports this file, so every session starts with it. Add to
it with `python tools/team.py remember <topic> -m "..."` when you learn
something the next agent would otherwise learn the hard way; it lands at the
bottom. Your own notes go to `team.py note` (your `agents/agent-N.md`).

**All memory lives in the project** (the owner, 2026-10-07): this file, the
agent files, the worklog and the task specs, on the `team` branch in `.team/`.
Claude Code's own auto-memory is switched off for this project
(`.claude/settings.json`); never write memory outside the project.

## The owner's rules (binding; carried over from DeutschPlan, the owner's other project)

- **Identity.** Every commit uses this repo's git identity (the owner's; never override it). `gh` is logged in as the owner's account. Commit messages end with the `Co-Authored-By:` line your system prompt gives you. Every PR body starts with `**Agent-N**` on line 1 and ends with `🤖 Generated with [Claude Code](https://claude.com/claude-code)`.
- **The repo is public.** No keys, passwords, keystores, phone serials, personal data or other people's files on `main` or on this board.
- **One task (or a batch of 2–5 related tasks) → one branch `feat/DK-NNNN-<slug>` → one PR**, titled `<type>(<scope>): <what> (DK-NNNN)`; the body lists every task id. Squash merge with `gh pr merge P --squash --subject "<title> (#P)"`, no `--delete-branch`; delete the branch with `git push origin --delete <branch>` only once the PR is MERGED (deleting first closes it).
- **Merge only on an approving review** by another agent, read in full (again just before merging). Before merging, `git merge origin/main` into the branch (no rebase) and re-run the touched tests and the repo-wide guards. agent-4's `website/`-only PRs need no review (as on sogda-website); agent-4 merges them on a green website gate and reports them.
- **Merge open PRs first.** Reviews beat new work; at most two open PRs per agent. Never sit waiting for a review: ask an idle agent directly (`team.py msg agent-N --kind question`).
- **Keep working.** Never idle-wait on a review or a subagent; take the next ready task in parallel.
- **CI is off** until the owner says otherwise (DK-0010 asks). The basic check in `CLAUDE.md` is the only check: run it before you push and again before you merge if `origin/main` moved. Never wait for, re-run or enable a workflow.
- **Decisions are the owner's.** App name, price, ads, app ids, signing, licences, the domain: `team.py decision <id> -m "the question and the options"`; never guess.
- **Docs win.** A behaviour change updates the docs in the same PR. A spec gap you fill is named in the PR.
- **Never chain past a failure:** a merge, a lock, a build or a test is its own command; gate steps join with `&&`, never `;`.
- **Ids come from tools.** Shas, PR numbers and task ids in comments come from git, gh or team.py output (a shell variable), never typed from memory.
- **One machine, two teams.** DeutschPlan's agents work on this machine too. Never `taskkill /IM flutter_tester.exe` (it kills every agent's tests, theirs too). Don't restart a process the system stopped for low memory without the owner's OK.
- **Emulators.** DeutschPlan's `emulator-5554`, `-5556` and `-5558` are not ours: never install on or drive them. Dokulo's developers share **`emulator-5562`** (AVD `dk-dev`) under `team.py device`; **`emulator-5564`** (AVD `dk-sqa`) is agent-3's alone. A plain `adb` call always names `-s emulator-556x`. agent-3 creates both AVDs in DK-0668.
- **Marketing never publishes.** agent-5 prepares every post, video and pitch; only the owner posts, sends or holds accounts. No price, "free", ratings or user counts until the owner decides them.
- **The board is touched only by `team.py`.** No `git pull`, `reset` or `commit` by hand in `.team/` (the lead's PLAN.md edits are committed by the next `team.py` command).

## Lessons carried over from DeutschPlan

- **Git Bash on Windows:** a heredoc halves backslashes (write scripts with a backslash through the Write tool); an argument like `/de` becomes a Windows path unless `MSYS_NO_PATHCONV=1`; `cmd | tail` hides `cmd`'s exit code.
- **Times:** `gh` prints UTC, the board local time (UTC+2 in summer). Convert before deciding what came first.
- **Tests:** wrap test batches in `timeout`; never await a drift watch's `.first` in a provider (it hangs tests). Widget-test keyboard insets are physical pixels (× devicePixelRatio). After a `git stash` round trip, re-run code generation (l10n, build_runner) before trusting goldens.
- **Installs:** after `adb install`, check `dumpsys package <id> | grep lastUpdateTime`: a "Success" once left the old build and nearly faked a bug.
- **Release builds:** R8 needs keep rules for ML Kit and other reflection-based plugins, or the release build crashes where debug works.
- **JSON with escapes:** replace strings as text; a `json.dumps` round trip turns ` `-style escapes into invisible literals.

## Learned by the team

- **PR reviews on one account** (2026-10-07, agent-0): Every agent is the owner's gh account, so GitHub refuses APPROVE and REQUEST_CHANGES ('Can not request changes on your own pull request'). Post the review with event COMMENT, inline comments on the lines, and the verdict on the first line of the body: '**Agent-N** · **Approved**' or '**Agent-N** · **Changes requested**'. That line is the approving review the merge rule asks for.
- **M01 needs no review** (2026-10-07, agent-2): (the owner, 2026-10-07, to agent-2): PRs for milestone M01 (Platform & engine foundation) need no approving review. When the basic check passes, merge origin/main into the branch, re-run the check, and merge. Every other rule still applies: the PR body, squash merge, done on the board. Other milestones still need a review.
- **M01 needs no review** (2026-10-07, agent-1): The owner, 2026-10-07: PRs for milestone M01 (Platform & engine foundation) need no approving review; the author merges once the basic check passes (git merge origin/main first, re-run the check). Other milestones keep the review rule.
- **Windows MAX_PATH and native builds** (2026-10-07, agent-1): opencv_dart (dartcv4) compiles OpenCV from source through CMake/ninja; on Windows the build fails with 'Filename longer than 260 characters' when the project path is deep (failed at 112 chars, fine at .worktrees/agent-N/<short app path>). Build native probes inside your worktree, never in the scratchpad; keep package paths short.
- **Close the GitHub issue on merge** (2026-10-07, agent-1): The owner, 2026-10-07: every board task has a GitHub issue (title 'DK-NNNN · …', one milestone each). When a task's PR merges, close its issue too: I=$(gh issue list --search 'DK-NNNN in:title' --state all --json number,title -q '.[] | select(.title|startswith("DK-NNNN ")) | .number'); gh issue close $I -c 'Done in #P (merged).' -r completed. Do it right after team.py done. Tasks done before their issue was uploaded: close it once it appears.
- **Owner decisions 2026-10-07: CI, app ids, crash reports** (2026-10-07, agent-1): Asked by agent-1 for M01. (1) DK-0010: NO CI/CD. Only local tests: DK-0010 delivers one local gate script every agent runs before merging; CI-only parts (hosted pipelines, signed CI artefacts) are out. DK-0012/0015/0017/0018 depend on it as a local check. (2) DK-0015: base app id app.dokulo (prod app.dokulo, app.dokulo.staging, app.dokulo.dev); the app name itself is still DK-0698. (3) DK-0011: no crash-reporting SDK: crashes logged locally without file names, paths or text; the user sends a report by email from Settings (opt-in, user-initiated).
- **Hy-MT2 allowed** (2026-10-07, agent-0): The owner, 2026-10-07: the Hy-MT2 licence is okay (Apache-2.0, Tencent's own repo). Hy-MT2 1.8B stays an optional download translation engine (UI spec, DK-0566), as in Sogda. HY-MT1.5 stays excluded (its licence excludes the EU, UK, South Korea). Re-read the model card's licence file at release (intake checklist, docs/compliance/ai-models.md).
- **emulator-5554 for Dokulo tests** (2026-10-07, agent-0): The owner, 2026-10-07: emulator-5554 (AVD flutter_emulator, Android x86_64) is up and running for Dokulo's tests. This overrides '5554 is DeutschPlan's' for this emulator. Share it under team.py device (hold the lock while you install or drive it, release right after); always name it: adb -s emulator-5554. adb is not on PATH in Git Bash: $LOCALAPPDATA/Android/Sdk/platform-tools/adb.exe. 5556 and 5558 stay DeutschPlan's; dk-dev (5562) and dk-sqa (5564) come with DK-0668.
- **Git Bash: /tmp and heredoc chains** (2026-10-07, agent-2): (agent-2, 2026-10-07) Two traps that bit a merge. (1) Git Bash's /tmp is not the Windows %TEMP%: python, gh and other Windows programs can't open /tmp/x, so write temp files to your scratchpad (a C:/... path). (2) 'cmd <<EOF ... EOF' ends the && chain at its newline: whatever comes on the next line runs even if the heredoc command failed. Put a gate step like 'gh pr merge' in its own Bash call, after checking the previous step's output.
