# Lessons learned

## Technical

1. **Tag after the merge, then verify the tag.** A release was tagged before
   its fix PR was merged and pulled, so the tag held the old code. Tags are
   immutable, so that version number was burnt. Verify with
   `git grep <pattern> <tag> -- modules/` before consuming a tag.
2. **Modules must not contain provider blocks.** A `provider` block inside
   the `iam` module made it a "legacy module" that cannot be used with
   `count`. Modules declare `required_providers`; only root modules
   configure providers. Consuming COB for real found this; COB's own
   development had not.
3. **Security-relevant formats change. Check current docs, not memory.**
   Every OIDC login failed because new repos use an immutable subject claim
   (with numeric IDs). Printing the real token claims in a debug step found
   it in one run. The same applied to action versions: the current major was
   not the one I would have guessed.
4. **A negative test needs a positive control.** The "apply role must be
   refused" check was green while both roles were failing for the same
   wrong reason. It proved nothing until the plan role also worked.
5. **Skipped required checks can count as passing.** The static-check jobs
   are required directly, so a skipped plan cannot hide a failed validation.
   Path filters on required workflows can leave a check pending forever.
6. **Configuration the pipeline needs must be in Git.** An early
   `.gitignore` excluded `*.tfvars`, which would have left CI without its
   inputs. tfvars hold no secrets here, so they are committed, along with
   `.terraform.lock.hcl`.
7. **Name things so permissions cannot loop back.** The pipeline's roles are
   `gha-*`, not `cob-*`, so the apply role's IAM scope can never edit them.
8. **Apply the plan that was reviewed.** A saved plan plus Terraform's
   stale-plan check means an approval cannot be silently swapped for a
   different change.
9. **`tee` hides failures.** A piped command reports the pipe's last exit
   code, so `terraform apply | tee` needs `pipefail` or it reports success
   after a failure.
10. **Dependabot runs get no OIDC token.** They are treated like fork runs
    with a read-only token, and re-running them does not change that. A
    pipeline whose required check needs AWS cannot be satisfied by a
    Dependabot PR; a maintainer pushes a commit as themselves.

## Process

11. **Build it by hand before automating it.** Doing Phase 1 manually
    meant pipeline failures were always pipeline problems, not Terraform
    problems.
12. **Use the platform as a customer to find its gaps.** Real use surfaced
    module bugs and missing outputs that review had missed. Fix them in the
    platform with a release, never around it in the consumer.
13. **Reverse decisions when the evidence changes.** The OIDC role started as
    a platform-module idea and ended as consumer code once the singleton
    provider and per-stack permissions were clear (the rule of three).
14. **Model the team you want, not the team you have.** The first design
    assumed one person approving their own work. Rebuilding it around
    separation of duties (and two reviewers, so it cannot deadlock) made
    the controls real.
15. **Approval is only as good as the plan the approver reads.** The PR
    template's reviewer checklist and the destroy/replace warning in the run
    summary exist because "approved" must mean "read".
16. **Public repos are a trade-off, not a free lunch.** Free rulesets and
    approvals came with world-readable plans and artifacts. Fine for this
    stack, wrong for one that holds secrets.
17. **Costs are real.** A forgotten NAT gateway produced a bill in the first
    project. The data lake needs no VPC and costs almost nothing at rest,
    and teardown is documented because the pipeline has no destroy path.