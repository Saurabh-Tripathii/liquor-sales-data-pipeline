variable "raw_bucket_name" {
  type = string
}

variable "clean_bucket_name" {
  type = string
}

variable "glue_script_bucket" {
  type = string
}

variable "glue_job_name" {
  type    = string
  default = "liquor-sales-cleaning-job"
}
