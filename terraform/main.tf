provider "aws" {
  region = var.aws_region
}

# =========================
# RAW BUCKET (USE OR CREATE)
# =========================
data "aws_s3_bucket" "raw_existing" {
  bucket = var.raw_bucket_name
}

resource "aws_s3_bucket" "raw_bucket" {
  count  = length(try(data.aws_s3_bucket.raw_existing.id, "")) == 0 ? 1 : 0
  bucket = var.raw_bucket_name
}


# CLEAN BUCKET (USE OR CREATE)

data "aws_s3_bucket" "clean_existing" {
  bucket = var.clean_bucket_name
}

resource "aws_s3_bucket" "clean_bucket" {
  count  = length(try(data.aws_s3_bucket.clean_existing.id, "")) == 0 ? 1 : 0
  bucket = var.clean_bucket_name
}

# GLUE SCRIPT BUCKET (USE OR CREATE)

data "aws_s3_bucket" "glue_script_existing" {
  bucket = var.glue_script_bucket
}

resource "aws_s3_bucket" "glue_script_bucket" {
  count  = length(try(data.aws_s3_bucket.glue_script_existing.id, "")) == 0 ? 1 : 0
  bucket = var.glue_script_bucket
}

# Upload Glue script from GitHub
resource "aws_s3_object" "glue_script_upload" {
  bucket = coalesce(
    try(aws_s3_bucket.glue_script_bucket[0].bucket, null),
    data.aws_s3_bucket.glue_script_existing.bucket
  )

  key    = "scripts/liquor_cleaning_job.py"
  source = "../glue/liquor_cleaning_job.py"
}


# EXISTING IAM ROLE (REUSE)

data "aws_iam_role" "glue_role" {
  name = "AWSGlueServiceRole-liquor-auto"
}


# GLUE JOB

resource "aws_glue_job" "liquor_job" {
  name     = "liquor-sales-cleaning-job"
  role_arn = aws_iam_role.glue_role.arn

  command {
    name            = "glueetl"
    python_version  = "3"
    script_location = "s3://${var.glue_script_bucket}/scripts/liquor_cleaning_job.py"
  }

  default_arguments = {
    "--job-language"  = "python"
    "--RAW_S3_PATH"   = var.raw_s3_path
    "--CLEAN_S3_PATH" = var.clean_s3_path
  }

  lifecycle {
    ignore_changes = all
  }
}


resource "aws_glue_catalog_database" "liquor_db" {
  name = "liquor_sales_database"

  lifecycle {
    prevent_destroy = true
    ignore_changes  = all
  }
}




# GLUE CRAWLER

resource "aws_glue_crawler" "cleaned_crawler" {
  name          = "liquor-cleaned-data-crawler"
  role          = data.aws_iam_role.glue_role.arn
  database_name = aws_glue_catalog_database.liquor_db.name


  s3_target {
    path = "s3://${var.clean_bucket_name}/"
  }

  schema_change_policy {
    update_behavior = "UPDATE_IN_DATABASE"
    delete_behavior = "LOG"
  }
}
