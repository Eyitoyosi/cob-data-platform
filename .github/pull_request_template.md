## What and why
<!-- What does this change do, and why is it needed? -->

## Environment(s) affected
- [ ] dev

## Author checklist
- [ ] I read the Terraform plan comment and it matches my intent
- [ ] No unexpected destroys or replacements
- [ ] No secrets, keys or account-specific values added

## Reviewer checklist
- [ ] Plan matches the description (resource count and types)
- [ ] No `destroy` or `must be replaced` that isn't explained
- [ ] No IAM, bucket-policy or public-access changes that aren't explained
- [ ] COB module versions are pinned to a tag, not a branch
- [ ] Cost impact understood (NAT gateways, databases, crawlers)