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
