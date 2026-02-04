provider "aws" {
  region = var.aws_region
}

# -------------------------
# IAM ROLE FOR GLUE
# -------------------------
resource "aws_iam_role" "glue_role" {
  name = var.glue_role_name

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

# -------------------------
# GLUE JOB
# -------------------------
resource "aws_glue_job" "liquor_job" {
  name     = "liquor-sales-cleaning-job"
  role_arn = aws_iam_role.glue_role.arn

  glue_version = "4.0"

  command {
    name            = "glueetl"
    python_version  = "3"
    script_location = var.glue_script_s3_path
  }

  default_arguments = {
    "--job-language" = "python"
  }
}

# -------------------------
# GLUE CRAWLER
# -------------------------
resource "aws_glue_crawler" "clean_crawler" {
  name          = "liquor-cleaned-crawler"
  role          = aws_iam_role.glue_role.arn
  database_name = aws_glue_catalog_database.athena_db.name

  s3_target {
    path = var.clean_s3_base_path
  }
}

# -------------------------
# ATHENA DATABASE
# -------------------------
resource "aws_glue_catalog_database" "athena_db" {
  name = var.athena_db_name
}

# -------------------------
# ATHENA VIEWS
# -------------------------
resource "aws_athena_named_query" "yearly_trend_view" {
  name      = "vw_yearly_trend"
  database  = aws_glue_catalog_database.athena_db.name
  query     = file("${path.module}/views/vw_yearly_trend.sql")
}
