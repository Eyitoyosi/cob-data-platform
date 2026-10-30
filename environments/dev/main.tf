locals {

  project = "beejan-lake"
}

# Raw zone: data lands here exactly as received.
module "raw_zone" {
  source      = "git::https://github.com/Eyitoyosi/cob.git//modules/storage-s3?ref=v0.1.3"
  name        = "${local.project}-raw"
  environment = var.environment
}

# Catalog + query layer over the raw zone (Glue Data Catalog, crawler, Athena).
module "catalog" {
  source          = "git::https://github.com/Eyitoyosi/cob.git//modules/data-platform?ref=v0.1.3"
  name            = local.project
  environment     = var.environment
  data_bucket_id  = module.raw_zone.bucket_id
  data_bucket_arn = module.raw_zone.bucket_arn
  data_s3_prefix  = "orders/"
}

# Sample dataset. This is specific to this application, not a platform
# capability, so it lives here rather than in COB.
resource "aws_s3_object" "orders_sample" {
  bucket      = module.raw_zone.bucket_id
  key         = "orders/orders.csv"
  source      = "${path.module}/../../data/sample/orders.csv"
  source_hash = filemd5("${path.module}/../../data/sample/orders.csv")
}

# Curated zone: cleaned, query-ready data.
module "curated_zone" {
  source      = "git::https://github.com/Eyitoyosi/cob.git//modules/storage-s3?ref=v0.1.3"
  name        = "${local.project}-curated"
  environment = var.environment
}