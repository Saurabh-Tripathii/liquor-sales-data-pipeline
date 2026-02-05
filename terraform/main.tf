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
# =========================
resource "aws_glue_job" "liquor_job" {
  name     = "liquor-sales-cleaning-job"
  role_arn = data.aws_iam_role.glue_role.arn

  glue_version = "4.0"
  worker_type  = "G.2X"
  number_of_workers = 5

  command {
    name            = "glueetl"
    script_location = "s3://my-glue-scripts-s/scripts/liquor_cleaning_job.py"
    python_version  = "3"
  }

  default_arguments = {
    "--job-language" = "python"
  }

  max_retries = 0
  timeout     = 10
}

# =========================
# GLUE CRAWLER (EXISTING DB)
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
