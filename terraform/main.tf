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


