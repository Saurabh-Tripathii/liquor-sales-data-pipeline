variable "raw_bucket_name" {
  description = "S3 bucket for raw liquor sales data"
  type        = string
}

variable "clean_bucket_name" {
  description = "S3 bucket for cleaned liquor sales data"
  type        = string
}

variable "glue_script_bucket" {
  description = "S3 bucket where glue scripts are stored"
  type        = string
}
