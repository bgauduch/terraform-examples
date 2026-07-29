output "cloudfront_url" {
  description = "HTTPS URL of the CloudFront distribution serving the page"
  value       = "https://${aws_cloudfront_distribution.site.domain_name}"
}

output "distribution_id" {
  description = "CloudFront distribution ID - the target of the invalidation action"
  value       = aws_cloudfront_distribution.site.id
}

output "bucket_name" {
  description = "Name of the private origin bucket"
  value       = aws_s3_bucket.site.id
}
