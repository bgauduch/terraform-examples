output "website_url" {
  description = "HTTP URL of the S3 static website (the endpoint asserted by the check)"
  value       = "http://${aws_s3_bucket_website_configuration.site.website_endpoint}"
}

output "bucket_name" {
  description = "Name of the website bucket"
  value       = aws_s3_bucket.site.id
}
