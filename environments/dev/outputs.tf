output "raw_bucket_id" {
  value = module.raw_zone.bucket_id
}

output "glue_database_name" {
  value = module.catalog.glue_database_name
}

output "athena_workgroup_name" {
  value = module.catalog.athena_workgroup_name
}