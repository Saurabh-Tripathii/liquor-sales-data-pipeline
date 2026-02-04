variable "raw_bucket_name" {
  description = "Raw S3 bucket name"
  type        = string
}

variable "clean_bucket_name" {
  description = "Cleaned S3 bucket name"
  type        = string
}

variable "glue_script_bucket" {
  description = "S3 bucket for Glue scripts"
  type        = string
}

variable "glue_job_name" {
  description = "Glue Job Name"
  type        = string
  default     = "liquor-sales-cleaning-job"
}
