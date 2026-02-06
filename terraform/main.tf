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
# INPUT VARIABLES
# =========================
variable "raw_s3_path" {
  type        = string
  description = "Raw S3 path"
}

variable "clean_s3_path" {
  type        = string
  description = "Cleaned S3 path"
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
        Action = [
          "s3:GetObject",
          "s3:ListBucket"
        ]
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
    "--RAW_S3_PATH"   = var.raw_s3_path
    "--CLEAN_S3_PATH" = var.clean_s3_path
    "--job-language" = "python"
  }

  glue_version      = "4.0"
  worker_type       = "G.2X"
  number_of_workers = 5

  lifecycle {
    ignore_changes = [default_arguments]
  }
}

# =========================
# GLUE CRAWLER (DEFINE ONLY)
# =========================
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
}

# =========================
# RUN GLUE → WAIT → RUN CRAWLER
# =========================
resource "null_resource" "run_glue_then_crawler" {

  depends_on = [
    aws_glue_job.liquor_job,
    aws_glue_crawler.cleaned_crawler,
    aws_iam_role_policy.glue_script_read
  ]

  provisioner "local-exec" {
    command = <<EOT
set -e

echo "Starting Glue Job..."
JOB_RUN_ID=$(aws glue start-job-run \
  --job-name liquor-sales-cleaning-job \
  --arguments "{\"--RAW_S3_PATH\":\"${var.raw_s3_path}\",\"--CLEAN_S3_PATH\":\"${var.clean_s3_path}\"}" \
  --query JobRunId --output text)

echo "JobRunId: $JOB_RUN_ID"

echo "Waiting for Glue Job to finish..."
while true; do
  STATUS=$(aws glue get-job-run \
    --job-name liquor-sales-cleaning-job \
    --run-id $JOB_RUN_ID \
    --query JobRun.JobRunState \
    --output text)

  echo "Current status: $STATUS"

  if [ "$STATUS" = "SUCCEEDED" ]; then
    echo "Glue Job completed successfully"
    break
  elif [ "$STATUS" = "FAILED" ] || [ "$STATUS" = "STOPPED" ] || [ "$STATUS" = "TIMEOUT" ]; then
    echo "Glue Job failed"
    exit 1
  fi

  sleep 30
done

echo "Starting Glue Crawler..."
aws glue start-crawler --name liquor-cleaned-crawler

echo "Pipeline completed successfully"
EOT
  }
}
