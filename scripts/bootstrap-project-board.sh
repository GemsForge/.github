#!/usr/bin/env zsh
# Wire a repository to a user-owned GitHub Project board.
#
# Usage:
#   scripts/bootstrap-project-board.sh <owner/repo> <project-number> <local-checkout-path>
#
# Before running: copy a classic PAT (scopes: project, repo) to the clipboard.
# The token is read from the clipboard, verified, and stored as the
# PROJECTS_TOKEN secret. It is never printed.
#
# The script does not commit, push, or edit the Project itself. Review the
# copied files, then commit them through the repository's normal branch/PR flow.
set -euo pipefail

if (( $# != 3 )); then
  print -u2 "Usage: $0 <owner/repo> <project-number> <local-checkout-path>"
  exit 2
fi
repo=$1; project=$2; checkout=$3
here=${0:A:h:h}
owner=${repo%%/*}

[[ $project == <1-> ]] || { print -u2 "Project number must be a positive integer."; exit 2; }
[[ -d $checkout/.git ]] || { print -u2 "$checkout is not a git checkout."; exit 2; }

# 1. Verify the clipboard token without echoing it.
token=$(pbpaste | tr -d '[:space:]')
login=$(GH_TOKEN=$token gh api user --jq .login 2>/dev/null) || {
  print -u2 "Clipboard does not hold a working token (Bad credentials)."; exit 1; }
scopes=$(GH_TOKEN=$token gh api -i user 2>/dev/null | awk -F': ' 'tolower($1)=="x-oauth-scopes"{print $2}' | tr -d '\r')
[[ $scopes == *project* ]] || { print -u2 "Token for $login lacks the 'project' scope (has: $scopes)."; exit 1; }

# 2. Confirm the token can see the board.
GH_TOKEN=$token gh project view "$project" --owner "$owner" --format json --jq .title >/dev/null 2>&1 || {
  print -u2 "Token for $login cannot see Project #$project owned by $owner."; exit 1; }

# 3. Repository secret and variable.
print -rn -- "$token" | gh secret set PROJECTS_TOKEN --repo "$repo"
unset token
gh variable set PROJECT_NUMBER --body "$project" --repo "$repo"

# 4. Standard caller workflows (shared logic stays in GemsForge/.github).
"$here/scripts/install-callers.sh" "$checkout"

# 5. Report the board's Status options so mismatches are visible now.
expected=(Backlog Ready "In progress" "In review" Approved Done)
actual=("${(@f)$(gh project field-list "$project" --owner "$owner" --format json \
  --jq '.fields[] | select(.name=="Status") | .options[].name')}")
missing=(${expected:|actual})
print "Wired $repo to Project #$project as $login."
if (( ${#missing} )); then
  print "Missing Status options: ${(j:, :)missing}"
else
  print "Status options OK."
fi
print "Next: commit .github/ in $checkout, align built-in Project workflows, copy something else to the clipboard."
