terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = "us-east-1"
}
# =========================
# EXISTING IAM ROLE
# =========================
data "aws_iam_role" "glue_role" {
  name = "AWSGlueServiceRole-liquor"
}

# =========================
# ALLOW GLUE TO READ SCRIPT
# =========================
resource "aws_iam_role_policy" "glue_script_read" {
  name = "glue-read-script-bucket"
  role = data.aws_iam_role.glue_role.name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = ["s3:GetObject", "s3:ListBucket"]
        Resource = [
          "arn:aws:s3:::liquor-glue-scripts-auto",
          "arn:aws:s3:::liquor-glue-scripts-auto/scripts/*"
        ]
      }
    ]
  })
}

# =========================
# GLUE JOB (DEFINE ONLY)
# =========================
resource "aws_glue_job" "liquor_job" {
  name     = "liquor-sales-cleaning-job"
  role_arn = data.aws_iam_role.glue_role.arn

  command {
    name            = "glueetl"
    script_location = "s3://liquor-glue-scripts-auto/scripts/liquor_cleaning_job.py"
    python_version  = "3"
  }

  default_arguments = {
    "--job-language" = "python"
  }

  glue_version      = "4.0"
  worker_type       = "G.2X"
  number_of_workers = 5
}

# =========================
# GLUE CRAWLER (DEFINE ONLY)
resource "aws_glue_crawler" "cleaned_crawler" {
  name          = "liquor-cleaned-crawler"
  role          = data.aws_iam_role.glue_role.arn
  database_name = "liquor_sales_database"

  s3_target {
    path = var.clean_s3_path
  }

  schema_change_policy {
    update_behavior = "UPDATE_IN_DATABASE"
    delete_behavior = "LOG"
  }

  lifecycle {
    create_before_destroy = true
  }
}
