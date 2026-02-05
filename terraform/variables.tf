variable "glue_script_bucket" {
  description = "Bucket where glue script already exists"
  type        = string
}

variable "clean_s3_path" {
  description = "Cleaned data S3 path"
  type        = string
}
