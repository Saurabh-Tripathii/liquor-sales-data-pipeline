provider "aws" {
  region = "us-east-1"
}

# =========================
# EXISTING RESOURCES (DATA)
# =========================

data "aws_iam_role" "glue_role" {
  name = "AWSGlueServiceRole-liquor"
}

data "aws_glue_catalog_database" "liquor_db" {
  name = "liquor_sales_database"
}

# =========================
# GLUE JOB (CREATE)
# =========================

resource "aws_glue_job" "liquor_cleaning_job" {
  name     = "liquor-sales-cleaning-job"
  role_arn = data.aws_iam_role.glue_role.arn

  glue_version      = "4.0"
  worker_type       = "G.1X"
  number_of_workers = 2
  timeout           = 30

  command {
    name            = "glueetl"
    python_version  = "3"
    script_location = "s3://${var.glue_script_bucket}/scripts/liquor_cleaning_job.py"
  }

  default_arguments = {
    "--job-language" = "python"
  }
}

# =========================
# GLUE CRAWLER (CREATE)
# =========================

resource "aws_glue_crawler" "cleaned_data_crawler" {
  name          = "liquor-cleaned-data-crawler"
  role          = data.aws_iam_role.glue_role.arn
  database_name = data.aws_glue_catalog_database.liquor_db.name

  s3_target {
    path = var.clean_s3_path
  }

  schema_change_policy {
    update_behavior = "UPDATE_IN_DATABASE"
    delete_behavior = "LOG"
  }
}
