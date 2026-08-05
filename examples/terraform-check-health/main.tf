# Cross-cutting locals shared by s3.tf and checks.tf.

locals {
  index_html = "${path.module}/content/index.html"

  # One expectation, asserted by all three blocks at three different moments.
  health_marker = "Status: healthy"

  common_tags = {
    Project   = var.project
    ManagedBy = "terraform"
  }
}

resource "random_id" "suffix" {
  byte_length = 4
}
