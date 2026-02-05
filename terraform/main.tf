provider "aws" {
  region = "us-east-1"
}

# -----------------------
# S3 BUCKETS (AUTO)
# -----------------------

resource "aws_s3_bucket" "raw_bucket" {
  bucket        = var.raw_bucket_name
  force_destroy = true
}

resource "aws_s3_bucket" "clean_bucket" {
  bucket        = var.clean_bucket_name
  force_destroy = true
}

resource "aws_s3_bucket" "glue_script_bucket" {
  bucket        = var.glue_script_bucket
  force_destroy = true
}

resource "aws_s3_object" "glue_script_upload" {
  bucket = aws_s3_bucket.glue_script_bucket.bucket
  key    = "scripts/liquor_cleaning_job.py"
  source = "../glue/liquor_cleaning_job.py"
}

# -----------------------
# IAM ROLE (AUTO)
# -----------------------

resource "aws_iam_role" "glue_role" {
  name = "AWSGlueServiceRole-liquor"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = { Service = "glue.amazonaws.com" }
      Action = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "glue_policy" {
  role       = aws_iam_role.glue_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSGlueServiceRole"
}

# -----------------------
# GLUE JOB
# -----------------------

resource "aws_glue_job" "liquor_job" {
  name     = "liquor-sales-cleaning-job"
  role_arn = aws_iam_role.glue_role.arn

  glue_version      = "4.0"
  worker_type       = "G.1X"
  number_of_workers = 2
  timeout           = 30

  command {
    name            = "glueetl"
    python_version  = "3"
    script_location = "s3://${aws_s3_bucket.glue_script_bucket.bucket}/scripts/liquor_cleaning_job.py"
  }

  default_arguments = {
    "--job-language" = "python"
  }
}

# -----------------------
# EXISTING DATABASE (USE)
# -----------------------

data "aws_glue_catalog_database" "liquor_db" {
  name = "liquor_sales_database"
}

# -----------------------
# GLUE CRAWLER
# -----------------------

resource "aws_glue_crawler" "cleaned_crawler" {
  name          = "liquor-cleaned-data-crawler"
  role          = aws_iam_role.glue_role.arn
  database_name = data.aws_glue_catalog_database.liquor_db.name

  s3_target {
    path = var.clean_s3_path
  }

  schema_change_policy {
    update_behavior = "UPDATE_IN_DATABASE"
    delete_behavior = "LOG"
  }
}
