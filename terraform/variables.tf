variable "aws_region" {
  default = "us-east-1"
}

variable "raw_bucket_name" {}
variable "clean_bucket_name" {}

variable "glue_job_name" {
  default = "liquor-sales-cleaning-job"
}

variable "glue_script_bucket" {
  default = "liquor-glue-scripts-auto"
}
variable "raw_s3_path" {
  description = "S3 path where raw data is present (input for Glue job)"
  type        = string
}

variable "clean_s3_path" {
  description = "S3 path where cleaned data will be written by Glue job"
  type        = string
}
