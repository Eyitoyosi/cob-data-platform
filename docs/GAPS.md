# Gaps found while consuming COB

| # | Gap | How found | Platform or app-specific? | Decision | Status |
|---|---|---|---|---|---|
| 1 | `data-platform` does not output the crawler name; consumers rebuild it from the naming convention | Reading the module while starting the crawler | Platform (every consumer needs it) | Add `crawler_name` output | Open |
| 2 | Bucket names `cob-<env>-<name>` can collide globally | Risk noted before first apply | Platform | Add account ID suffix | To confirm |
| 3 | No CI/CD deploy role module (OIDC) | Known limitation from COB 1 | Platform | Add module | Open |
| 4 | Athena workgroup and non-empty buckets block `terraform destroy` | To confirm at teardown | Platform | Optional `force_destroy` for dev | To confirm |
| 5 | No transformation capability (Glue job) | Scope of this project | App-specific for now | Stay in consumer | Open |