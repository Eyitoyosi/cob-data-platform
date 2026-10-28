output "plan_role_arns" {
  value = { for env, role in aws_iam_role.plan : env => role.arn }
}

output "apply_role_arns" {
  value = { for env, role in aws_iam_role.apply : env => role.arn }
}