#!/usr/bin/env zsh
# Install the standard GemsForge caller workflows into a repository checkout.
#
# Usage: scripts/install-callers.sh <local-checkout-path>
#
# Copies templates/workflows/*.yml into <checkout>/.github/workflows/ and
# removes the superseded per-repository copies listed below. It does not
# commit, push, or touch repository settings: review the diff and open a PR.
# Repository-specific build/test workflows are left untouched.
set -euo pipefail
(( $# == 1 )) || { print -u2 "Usage: $0 <local-checkout-path>"; exit 2; }
checkout=${1:A}
here=${0:A:h:h}
[[ -e $checkout/.git ]] || { print -u2 "$checkout is not a git checkout."; exit 2; }

superseded=(branch-policy.yml label-policy.yml sync-pr-metadata.yml)
dest=$checkout/.github/workflows
mkdir -p $dest
for name in $superseded; do
  if [[ -f $dest/$name ]]; then rm $dest/$name; print "removed  .github/workflows/$name"; fi
done
for file in $here/templates/workflows/*.yml; do
  cp $file $dest/${file:t}
  print "installed .github/workflows/${file:t}"
done
print "\nNext: review 'git -C $checkout diff', update branch-protection check names, open a PR."
