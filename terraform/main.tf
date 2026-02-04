
provider "aws" {
  region = "us-east-1"
}

resource "aws_s3_bucket" "raw_bucket" {
  bucket        = var.raw_bucket_name
  force_destroy = true
}


resource "aws_s3_bucket" "clean_bucket" {
  bucket        = var.clean_bucket_name
  force_destroy = true
}


# GLUE SCRIPT BUCKET (USER INPUT)

resource "aws_s3_bucket" "glue_script_bucket" {
  bucket        = var.glue_script_bucket
  force_destroy = true
}


# UPLOAD GLUE SCRIPT TO S3

resource "aws_s3_object" "glue_script_upload" {
  bucket = aws_s3_bucket.glue_script_bucket.bucket
  key    = "scripts/liquor_cleaning_job.py"
  source = "../glue/liquor_cleaning_job.py"
}

# IAM ROLE FOR GLUE

resource "aws_iam_role" "glue_role" {
  name = "AWSGlueServiceRole-liquor"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect    = "Allow"
        Principal = { Service = "glue.amazonaws.com" }
        Action    = "sts:AssumeRole"
      }
    ]
  })
}


# ATTACH AWS MANAGED GLUE POLICY

resource "aws_iam_role_policy_attachment" "glue_policy_attach" {
  role       = aws_iam_role.glue_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSGlueServiceRole"
}


# CREATE AWS GLUE JOB

resource "aws_glue_job" "liquor_cleaning_job" {
  name     = var.glue_job_name
  role_arn = aws_iam_role.glue_role.arn

  glue_version        = "4.0"
  worker_type         = "G.2X"
  number_of_workers   = 5
  timeout             = 480

  command {
    name            = "glueetl"
    python_version  = "3"
    script_location = "s3://${aws_s3_bucket.glue_script_bucket.bucket}/scripts/liquor_cleaning_job.py"
  }

  default_arguments = {
    "--job-language"            = "python"
    "--enable-continuous-cloudwatch-log" = "true"
    "--enable-metrics"          = "true"
  }
}


# ATHENA / GLUE DATABASE

resource "aws_glue_catalog_database" "liquor_db" {
  name = "liquor_db"
}


#GLUE CRAWLER FOR CLEANED DATA

resource "aws_glue_crawler" "clean_data_crawler" {
  name          = "liquor-cleaned-data-crawler"
  role          = aws_iam_role.glue_role.arn
  database_name = "liquor_db"

  table_prefix = "cleaned_"

  s3_target {
    path = "s3://${var.clean_bucket_name}/"
  }

  schema_change_policy {
    update_behavior = "UPDATE_IN_DATABASE"
    delete_behavior = "DEPRECATE_IN_DATABASE"
  }
}
