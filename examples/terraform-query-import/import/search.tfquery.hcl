# Query file for `terraform query` (Terraform 1.14+). Only files with the
# .tfquery.hcl extension may contain `list` blocks. Workflow:
#
#   terraform query                                    # print matching resources
#   terraform query -generate-config-out=generated.tf  # write resource + import blocks
#   terraform plan                                     # review the import plan
#   terraform apply                                    # import in bulk into state
#
# These lists discover EC2 instances created out-of-band (see bootstrap/) and tagged
# demo=clickops. One list block per instance-type demonstrates *segmented* bulk import:
# each category is grouped under its own list.<type>.<label>, so you import a fleet at a
# time. In prod, swap the instance-type values (e.g. g5.* / p4d.* for a GPU fleet) or the
# resource type itself (aws_s3_object, aws_route53_record, ...) - same mechanic.

list "aws_instance" "general" {
  provider = aws

  config {
    filter {
      name   = "tag:demo"
      values = ["clickops"]
    }

    filter {
      name   = "instance-type"
      values = ["t3.micro"]
    }

    filter {
      name   = "instance-state-name"
      values = ["running", "stopped"]
    }
  }
}

list "aws_instance" "compute" {
  provider = aws

  config {
    filter {
      name   = "tag:demo"
      values = ["clickops"]
    }

    filter {
      name   = "instance-type"
      values = ["t3.small"]
    }

    filter {
      name   = "instance-state-name"
      values = ["running", "stopped"]
    }
  }
}
