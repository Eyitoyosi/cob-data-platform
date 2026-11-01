# Engineering decisions

Each entry records the context, the decision, and what it costs. The
module-consumption decision (versioned Git tags) is ADR 0007 in the
[COB repository](https://github.com/Eyitoyosi/cob/tree/main/docs/decisions).

## D1. GitHub Actions as the CI/CD platform

**Context.** The code is on GitHub and needs PR-triggered checks and an
approval gate.
**Decision.** GitHub Actions. No extra server or subscription.
**Trade-offs.** Tied to GitHub. Terraform-specific tools (Atlantis, HCP
Terraform) offer richer plan comments and a locking UI, at the cost of a
server or a subscription. Revisit if many repos need shared workflows.

## D2. OIDC federation instead of stored AWS keys

**Context.** The pipeline needs AWS access. Access keys in secrets are
permanent and powerful, which is the opposite of COB's standards.
**Decision.** GitHub OIDC tokens exchanged for temporary role credentials
(about one hour). Nothing is stored.
**Trade-offs.** More setup, and a trust policy that must be exactly right
(see D3). Deployments depend on GitHub's token issuer being available.

## D3. Trust policies match immutable subject claims

**Context.** The first trust policy used the name-only subject format and
every login failed with `Not authorized`. Repositories created after
mid-2026 embed numeric owner and repository IDs in the subject. Name-only
matching is also vulnerable to a recycled account or repo name.
**Decision.** Match `repo:OWNER@OWNER_ID/REPO@REPO_ID:...`.
**Trade-offs.** IDs must be looked up. Recreating or transferring the
repo changes them and requires a trust-policy update. This is also why
the project stayed on a personal account (D6).

## D4. Two roles: read-only plan, environment-gated apply

**Context.** A PR author can edit the workflow in their own branch, so
anything a PR can reach must be harmless.
**Decision.** A plan role (read-only; trusts PRs and `main`) and an apply
role (trusts only the `dev` environment). Permissions are scoped by name
where the blast radius is largest (S3 and IAM) and by service elsewhere
(Glue, Athena). The roles are named `gha-*` so the apply role's IAM
permissions, scoped to `cob-*`, can never touch them.
**Trade-offs.** Permissions are maintained by hand and will grow with the
stack. IAM write access, even scoped to a name prefix, lets the apply role
create roles with arbitrary policies inside that prefix; a permissions
boundary would close this and is deferred.

## D5. Plan on PR, plan again on main, apply the saved plan

**Context.** The plan in a PR is a preview; `main` may have changed before
the merge. Approving one plan and applying another defeats the review.
**Decision.** A fresh plan after merge is saved and shown to the approver;
that exact file is applied. Terraform refuses it if state changed.
**Trade-offs.** The saved plan travels as an artifact. In a public repo
anyone can download it, and a binary plan can hold values the text hides.
Accepted here because the stack has no secrets and retention is one day.
A stale plan means a re-run.

## D6. Separation of duties

**Context.** The first design assumed a solo developer: no required
approvals, self-approval at the environment. That is not how a team works.
**Decision.** A ruleset on `main` (PR, one approval from someone else,
code-owner review, stale approvals dismissed, required checks, up to
date, no bypass) plus two deployment reviewers with self-review
prevented. Two reviewers so the rule cannot deadlock. The repo stayed on a
personal account.
**Trade-offs.** Depends on reviewer availability. The repo owner can still
edit the ruleset; an organization with restricted admin rights would close
that, but moving the repo would break the OIDC trust (D3) and every module
URL.

## D7. Pipeline identity is bootstrapped by hand, in its own stack

**Context.** The pipeline cannot create the credentials it needs to run,
and a pipeline that manages its own roles could rewrite its own
permissions through a bad PR.
**Decision.** `bootstrap/` holds the OIDC provider and the two roles,
with remote state, and is applied by an admin.
**Trade-offs.** IAM changes need a reviewed PR followed by a manual apply.
That friction is intentional.

## D8. The deploy role stays in the consumer, not in COB

**Context.** COB has no CI/CD role module (logged in GAPS.md). The first
instinct was to add one to the platform.
**Decision.** Keep it in this repo. The OIDC provider is a once-per-account
singleton, permissions differ per stack, and there is only one consumer.
**Trade-offs.** A second team would copy the pattern. Extract a module when
a second consumer needs a pipeline (the "rule of three").

## D9. Concurrency group, state lock and timeouts

**Context.** Two deployments must never write the same state.
**Decision.** A workflow-level concurrency group (`cancel-in-progress:
false`) queues runs; the DynamoDB state lock is the hard guarantee; job
timeouts stop a hung run from holding the lock.
**Trade-offs.** GitHub keeps only the newest pending run. That is safe
because every run plans the tip of `main`. A run waiting for approval
holds the group and blocks later runs.

## D10. One directory per environment, matrix in the workflows

**Context.** One root module switched by variables risks pairing the dev
variables with prod state.
**Decision.** `environments/dev` (and later `prod`), each with its own
backend key and tfvars. Workflows use a matrix so adding an environment is
one entry.
**Trade-offs.** Some duplication between environment directories, accepted
for the safety of not being able to mismatch variables and state.

## D11. Public repositories

**Context.** Rulesets and environment approvals are free for public
repositories.
**Decision.** Public repos, with no secrets anywhere in the code or state.
**Trade-offs.** Plan text and artifacts are world-readable, and fork or
bot PRs get no OIDC token. A stack that handles secrets would need a
private repo or a private plan store.