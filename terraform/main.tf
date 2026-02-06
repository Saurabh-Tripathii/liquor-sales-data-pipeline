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

# =====================================================
# INPUT VARIABLES (ONLY 2 — AS YOU WANTED)
# =====================================================
variable "raw_s3_path" {
  description = "RAW S3 path (example: s3://bucket/raw/)"
  type        = string
}

variable "clean_s3_path" {
  description = "CLEAN S3 path (example: s3://bucket/cleaned/)"
  type        = string
}

# =====================================================
# EXISTING GLUE IAM ROLE (USE, DON'T CREATE)
# =====================================================
data "aws_iam_role" "glue_role" {
  name = "AWSGlueServiceRole-liquor"
}

# =====================================================
# ALLOW GLUE TO READ SCRIPT FROM S3
# =====================================================
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

# =====================================================
# GLUE JOB (OVERWRITES EXISTING JOB IF SAME NAME)
# =====================================================
resource "aws_glue_job" "liquor_job" {
  name     = "liquor-sales-cleaning-job-copy"
  role_arn = data.aws_iam_role.glue_role.arn

  command {
    name            = "glueetl"
    python_version  = "3"
    script_location = "s3://liquor-glue-scripts-auto/scripts/liquor-sales-cleaning-job-copy"
  }

  default_arguments = {
    "--job-language" = "python"
    "--RAW_S3_PATH"  = var.raw_s3_path
    "--CLEAN_S3_PATH" = var.clean_s3_path
  }

  glue_version      = "4.0"
  worker_type       = "G.2X"
  number_of_workers = 5

  lifecycle {
    create_before_destroy = true
  }

  depends_on = [
    aws_iam_role_policy.glue_script_read
  ]
}

# =====================================================
# GLUE CRAWLER (USES EXISTING DATABASE & TABLE)
# =====================================================
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

# =====================================================
# RUN: GLUE JOB → WAIT → RUN CRAWLER
# =====================================================
resource "null_resource" "run_glue_then_crawler" {

  depends_on = [
    aws_glue_job.liquor_job,
    aws_glue_crawler.cleaned_crawler
  ]

  provisioner "local-exec" {
    command = <<EOT
set -e

echo "Starting Glue Job..."
JOB_RUN_ID=$(aws glue start-job-run \
  --job-name liquor-sales-cleaning-job-copy \
  --arguments "{\"--RAW_S3_PATH\":\"${var.raw_s3_path}\",\"--CLEAN_S3_PATH\":\"${var.clean_s3_path}\"}" \
  --query JobRunId --output text)

echo "JobRunId: $JOB_RUN_ID"

echo "Waiting for Glue Job to finish..."
while true; do
  STATUS=$(aws glue get-job-run \
    --job-name liquor-sales-cleaning-job-copy \
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
