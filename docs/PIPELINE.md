# Using the pipeline

## Roles

| Role | Who | Can | Cannot |
|---|---|---|---|
| **Author** | Anyone with write access | Open PRs, merge an approved PR | Approve their own PR; approve a deployment they triggered |
| **Reviewer** | A code owner (see `.github/CODEOWNERS`) | Approve PRs | Bypass the ruleset |
| **Deployment approver** | The `dev` environment's reviewers | Approve or reject a deployment | Approve a deployment they triggered |
| **Admin** | Repository owner | Apply `bootstrap/` by hand | Skip review (the ruleset has no bypass list) |

Whoever merges a PR triggers the deployment, so **the merger and the
deployment approver must be different people**.

## The flow at a glance

```
PR opened ──► static checks ──► plan ──► plan comment ──► review + approval ──► merge
                (no AWS)       (read-only role)                                    │
                                                                                   ▼
        result in run summary ◄── apply saved plan ◄── approval ◄── plan on main
                                   (apply role)       (dev gate)   (skip if no changes)
```

## 1. Authoring a change

```bash
git switch main && git pull
git switch -c feat/short-description
# edit files under environments/dev/
terraform fmt -recursive
git add -A && git commit -m "feat: short description"
git push -u origin feat/short-description
```

Open the PR and fill in the template. Then wait for three checks:

| Check | Needs AWS? | Fails when |
|---|---|---|
| `Static checks (bootstrap)` | No | Formatting is wrong or the configuration is invalid |
| `Static checks (environments/dev)` | No | Same, for the data lake |
| `Plan (dev)` | Yes (read-only role) | Terraform cannot produce a plan. Skipped if a static check failed |

All three are required to merge. The bot posts the plan as a comment and
updates it on each push.

## 2. Reviewing a pull request

Open the plan comment and read it. Approving without reading the plan is
not a review. Check:

| Plan symbol | Meaning | What to do |
|---|---|---|
| `+` | Create | Expected for new resources. Do the names and counts match the description? |
| `~` | Update in place | Which attribute changes, and why? |
| `-` | **Destroy** | Stop. Is it explained in the PR? |
| `-/+` | **Replace** (destroy then create) | Stop. Replacement can lose data |

Also confirm: no IAM, bucket-policy or public-access changes that are not
explained; COB modules are pinned to a tag, never a branch; the cost impact
is understood. Approving a new commit is required after the author pushes
again, because earlier approvals are dismissed.

## 3. Approving a deployment

After a merge, open **Actions → Terraform Apply** and the run for that
merge commit.

1. If the plan job reports `No changes. Nothing to deploy.`, the apply job
   is skipped and nothing is needed from you.
2. Otherwise the apply job shows **Waiting**. Read the plan in the run
   summary. A warning appears there if the plan destroys or replaces
   anything.
3. Click **Review deployments**, tick `dev`, add a comment, and choose
   **Approve and deploy** or **Reject**.
4. Reject any deployment you do not recognise. A run that waits holds the
   queue and blocks later deployments.

The plan you approve is the exact file that is applied. If the state
changes in between, Terraform refuses it (`Saved plan is stale`) and the
run is re-run for a fresh plan.

## 4. After a deployment

The apply job's summary reports `success` or `failure`, the commit, who
triggered it, and Terraform's result line. Spot-check in AWS if the change
matters (for example `aws s3api get-bucket-encryption`).

## Special kinds of change

| Change | How |
|---|---|
| **Upgrade a COB version** | Change `ref=vX.Y.Z` in `environments/dev/main.tf` (`grep -rn "ref=" environments/`), open a PR, and read the plan: a patch release should show no or few changes |
| **Edit workflows** (`.github/`) | Normal PR. Code owners must review. The workflow that runs on the PR is the PR's version |
| **Change pipeline IAM** (`bootstrap/`) | PR with code-owner review. After merge, an admin runs `terraform apply` in `bootstrap/` by hand. The pipeline cannot change its own roles, by design |
| **Add `prod`** | Add `prod` to `environments` in `bootstrap/` (admin applies); copy `environments/dev` to `environments/prod` with its own `prod.tfvars` and state key `data-platform/prod/terraform.tfstate`; create a GitHub environment `prod` with reviewers; add matrix entries and a concurrency group in both workflows; add the `prod` checks to the ruleset |

## Emergencies

There is no bypass. In a genuine emergency an admin edits the ruleset,
which is logged, makes the change through a PR, and restores the ruleset.
Do not apply by hand against `environments/dev` except to recover from a
failed pipeline, and record why in the PR.

## Troubleshooting

| Symptom | Likely cause and fix |
|---|---|
| Format check fails | Run `terraform fmt -recursive` and push |
| `Plan (dev)` fails at the AWS login step | The PR is from a fork or a bot (neither gets an OIDC token), or the role trust is wrong |
| Dependabot PR fails `Plan (dev)` | Expected: Dependabot runs get no OIDC token. A maintainer checks out the branch, pushes an empty commit as themselves (`git commit --allow-empty -m "ci: re-run checks"`), and the checks then run with normal permissions |
| `AccessDenied` during plan or apply | A role is missing a permission. Send the exact action to an admin. Fix it in `bootstrap/` through a PR; never widen a role by hand |
| `Saved plan is stale` | State changed after the plan. Re-run all jobs for a fresh plan |
| `Error acquiring the state lock` | Another run holds it. Wait. Use `terraform force-unlock <ID>` only after confirming no run is active |
| Apply waits forever | Nobody approved. Reviewers approve or reject; a waiting run blocks later ones |
| Merge button blocked | A required check is red or pending, an approval is missing, or the branch is behind `main` |

## Teardown (admin, manual)

The pipeline deliberately has no destroy path. To remove the data lake and
stop any cost, an admin runs this locally with their own credentials.
Buckets are versioned, so they must be emptied of all versions first
(requires `jq`):

```bash
empty_bucket() {
  local b="$1"
  aws s3api list-object-versions --bucket "$b" --region us-east-1 --output json \
    | jq -c '((.Versions // []) + (.DeleteMarkers // []))[] | {Key, VersionId}' \
    | while read -r obj; do
        aws s3api delete-object --bucket "$b" --region us-east-1 \
          --key "$(jq -r .Key <<<"$obj")" --version-id "$(jq -r .VersionId <<<"$obj")" >/dev/null
      done
}

empty_bucket cob-dev-beejan-lake-raw
empty_bucket cob-dev-beejan-lake-curated
empty_bucket cob-dev-beejan-lake-athena-results

# A workgroup with query history cannot be deleted normally
aws athena delete-work-group --work-group cob-dev-beejan-lake \
  --recursive-delete-option --region us-east-1

cd environments/dev
terraform destroy -var-file=dev.tfvars
```

Leave `bootstrap/` and the state bucket in place unless the whole project
is being retired; their cost is negligible. These manual steps are why
`force_destroy` is logged as a gap in `GAPS.md`.