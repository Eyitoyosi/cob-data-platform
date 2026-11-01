# Demonstration

| Scenario | What I did | Control proven | Evidence |
|---|---|---|---|
| A: valid change | Added a curated-zone bucket via `storage-s3` (PR #__) | Full path works; merger cannot approve the deployment | [run](...), `docs/demo/A1-A6` |
| B: invalid Terraform | Referenced a non-existent module output (PR #__, closed unmerged) | Failed validation blocks merge even when a human approves | `docs/demo/B1-B2` |
| C: unchanged environment | Re-ran the deployment; merged a docs-only PR (PR #__) | No approval prompt, no apply, no state change | `docs/demo/C1-C2` |

## Reviewed change
PR #__ was reviewed by @reviewer1 and the deployment approved by @reviewer2.
Plan: 6 to add, 0 to change, 0 to destroy.

## Deviations and findings
(Anything that failed unexpectedly, such as a missing permission, and how it was fixed.)