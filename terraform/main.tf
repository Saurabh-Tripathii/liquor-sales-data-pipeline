provider "aws" {
  region = "us-east-1"
}

# =========================
# EXISTING IAM ROLE
# =========================
data "aws_iam_role" "glue_role" {
  name = "AWSGlueServiceRole-liquor"
}
# Allow Glue to read script from S3
resource "aws_iam_role_policy" "glue_s3_script_access" {
  name = "glue-s3-script-access"
  role = data.aws_iam_role.glue_role.name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject"
        ]
        Resource = "arn:aws:s3:::liquor-glue-scripts-auto/scripts/*"
      }
    ]
  })
}



# =========================
# GLUE JOB (ONLY DEFINE)
resource "aws_glue_job" "liquor_job" {
  name     = "liquor-sales-cleaning-job"   # SAME NAME
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
    ignore_changes = [
      default_arguments
    ]
  }
}


