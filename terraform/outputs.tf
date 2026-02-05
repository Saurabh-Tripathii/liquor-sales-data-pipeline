output "raw_bucket" {
  value = coalesce(
    try(aws_s3_bucket.raw_bucket[0].bucket, null),
    data.aws_s3_bucket.raw_existing.bucket
  )
}

output "clean_bucket" {
  value = coalesce(
    try(aws_s3_bucket.clean_bucket[0].bucket, null),
    data.aws_s3_bucket.clean_existing.bucket
  )
}
