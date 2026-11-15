# GemsForge shared GitHub workflows

One place for the GitHub Actions policy and automation every GemsForge repository uses. Fix a workflow here once; every repository picks it up on its next run.

## How it works

Each repository keeps four short **caller** files that never change. They point at the **reusable workflows** in this repository:

```text
your-repo/.github/workflows/            GemsForge/.github/.github/workflows/
  gemsforge-policy.yml   ───uses──▶       branch-policy.yml, label-policy.yml
  commit-policy.yml      ───uses──▶       commit-policy.yml  (+ scripts/commit-policy.mjs)
  sync-issue-metadata.yml ──uses──▶       sync-issue-metadata.yml (issue/PR metadata + Project board)
  sync-labels.yml        ───uses──▶       sync-labels.yml    (+ labels.json)
```

Repository-specific build and test workflows (`ci.yml`, `console-checks.yml`, `database-validation.yml`, …) stay in their own repositories.

## Versioning

Callers use `@v1`, a moving tag.

- **Compatible fix:** merge to `main`, then move `v1`:
  ```sh
  git tag -f v1 && git push -f origin v1
  ```
  Every repository uses it on its next run. No per-repository edits.
- **Breaking change** (renamed input, changed check name, new required setting): tag `v2`, update the callers in `templates/workflows/`, and migrate repositories one PR at a time.
- Exact releases are also tagged (`v1.0.0`, `v1.1.0`, …) so a repository can pin one if it ever needs to.

## Per-repository settings

Callers are identical everywhere. Differences live in repository variables and secrets:

| Setting | Kind | Used by | Default |
| --- | --- | --- | --- |
| `PROJECT_NUMBER` | variable | sync-issue-metadata | blank: Project board skipped |
| `PROJECTS_TOKEN` | secret | sync-issue-metadata | classic PAT, `project` + `repo` |
| `ALLOWED_BASE_BRANCHES` | variable | branch policy | blank: default branch only |
| `REQUIRE_CLOSING_KEYWORD` | variable | branch policy | `false`: a plain `#N` is enough |
| `Scripts/commit-policy.json` → `legacyBase` (read from the default branch) | file | commit policy | none: every commit is checked |

```sh
gh variable set ALLOWED_BASE_BRANCHES --body "master,master-toolkit" --repo GemsForge/GemsForgeAPI
```

## Add the standard workflows to a repository

```sh
scripts/install-callers.sh ~/GitRepositories/<repo>
```

This copies `templates/workflows/*.yml` into the repository and removes the superseded copies (`branch-policy.yml`, `label-policy.yml`, `sync-pr-metadata.yml`). It does not commit. Review the diff and open a PR.

To also connect a Project board (token on the clipboard):

```sh
scripts/bootstrap-project-board.sh GemsForge/<repo> <project-number> ~/GitRepositories/<repo>
```

New repositories created from [`GemsForge/repo-template`](https://github.com/GemsForge/repo-template) already include the callers.

## Branch protection check names

Reusable-workflow checks are reported as `<caller job> / <job name>`:

| Check | Required? |
| --- | --- |
| `branch / Branch and issue linkage` | yes |
| `labels / Require type-compatible story label` | yes |
| `commits / Commit policy` | yes |
| `sync / Maintain issue relationships and metadata` | no |

Update a repository's protection rules when migrating it, because the old names (`Commit policy`, …) stop reporting.

## Change a shared workflow

1. Branch, edit, and add or adjust tests.
2. Run them locally:
   ```sh
   node --test .github/tests/sync-issue-workflow.test.cjs
   node --test scripts/commit-policy.test.mjs
   ```
3. Merge, then move `v1` (or cut `v2` for breaking changes).

## Security

- This repository is public so public repositories can call it. It holds no secrets; callers pass only `PROJECTS_TOKEN` explicitly (not `secrets: inherit`), so the shared code never sees their other secrets.
- Policy workflows run on `pull_request_target` but never check out or run pull-request code.
- A called workflow can only narrow the permissions its caller grants.

## Contents

| Path | Purpose |
| --- | --- |
| `.github/workflows/*.yml` | Reusable workflows (`on: workflow_call`), plus `ci.yml` for this repository's own tests |
| `.github/tests/` | Offline test of the sync workflow's inline script |
| `scripts/commit-policy.*` | Commit-subject validator, shared config, tests |
| `scripts/install-git-hooks.mjs`, `.githooks/pre-push` | Optional local pre-push hook |
| `scripts/install-callers.sh` | Install or refresh callers in a repository |
| `scripts/bootstrap-project-board.sh` | Connect a repository to a Project board |
| `templates/workflows/` | The caller files every repository uses |
| `labels.json` | Shared label catalog |
