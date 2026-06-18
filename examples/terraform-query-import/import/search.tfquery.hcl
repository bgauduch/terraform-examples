# Query file for `terraform query` (Terraform 1.14+). Only files with the
# .tfquery.hcl extension may contain `list` blocks. Workflow:
#
#   terraform query                                    # print matching resources
#   terraform query -generate-config-out=generated.tf  # write resource + import blocks
#   terraform plan                                     # review the import plan
#   terraform apply                                    # import in bulk into state
#
# This list discovers EC2 instances created out-of-band (see bootstrap/) and tagged
# demo=clickops, so we can bring them under Terraform management.
list "aws_instance" "clickops" {
  provider = aws

  config {
    filter {
      name   = "tag:demo"
      values = ["clickops"]
    }

    filter {
      name   = "instance-state-name"
      values = ["running", "stopped"]
    }
  }
}
