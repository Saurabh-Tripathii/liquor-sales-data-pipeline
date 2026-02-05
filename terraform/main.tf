provider "aws" {
  region = "us-east-1"
}

# S3 BUCKETS

# RAW BUCKET (USE OR CREATE)

data "aws_s3_bucket" "raw_existing" {
  bucket = var.raw_bucket_name
}

resource "aws_s3_bucket" "raw_bucket" {
  count         = length(data.aws_s3_bucket.raw_existing.id) == 0 ? 1 : 0
  bucket        = var.raw_bucket_name
  force_destroy = true
}

# CLEAN BUCKET (USE OR CREATE)

data "aws_s3_bucket" "clean_existing" {
  bucket = var.clean_bucket_name
}

resource "aws_s3_bucket" "clean_bucket" {
  count         = length(data.aws_s3_bucket.clean_existing.id) == 0 ? 1 : 0
  bucket        = var.clean_bucket_name
  force_destroy = true
}

# GLUE SCRIPT BUCKET (USE OR CREATE)

data "aws_s3_bucket" "script_existing" {
  bucket = var.glue_script_bucket
}

resource "aws_s3_bucket" "glue_script_bucket" {
  count         = length(data.aws_s3_bucket.script_existing.id) == 0 ? 1 : 0
  bucket        = var.glue_script_bucket
  force_destroy = true
}




# IAM ROLE FOR GLUE


resource "aws_iam_role" "glue_role" {
  name = "AWSGlueServiceRole-liquor"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "glue.amazonaws.com"
      }
      Action = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "glue_policy_attach" {
  role       = aws_iam_role.glue_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSGlueServiceRole"
}

# GLUE JOB

resource "aws_glue_job" "liquor_job" {
  name     = "liquor-sales-cleaning-job"
  role_arn = aws_iam_role.glue_role.arn

  glue_version      = "4.0"
  worker_type       = "G.2X"
  number_of_workers = 5
  timeout           = 480

  command {
    name            = "glueetl"
    python_version  = "3"
    script_location = "s3://${aws_s3_bucket.glue_script_bucket.bucket}/scripts/liquor_cleaning_job.py"
  }

  default_arguments = {
    "--job-language" = "python"
  }
}


# GLUE CRAWLER

resource "aws_glue_crawler" "cleaned_crawler" {
  name          = "liquor-cleaned-data-crawler"
  role          = aws_iam_role.glue_role.arn
  database_name = "liquor_sales_database"

  s3_target {
    path = var.clean_s3_path
  }

  schema_change_policy {
    update_behavior = "UPDATE_IN_DATABASE"
    delete_behavior = "LOG"
  }
}
