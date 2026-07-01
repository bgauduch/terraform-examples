# Sandbox account: the "scene". A cheap EC2 instance stands in for the resource that burns
# money over the weekend, plus the break-glass role the SCPs spare.

# Latest Amazon Linux 2023 AMI, resolved from the public SSM parameter (no hardcoded AMI id).
data "aws_ssm_parameter" "al2023" {
  provider = aws.sandbox
  name     = "/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64"
}

# The runaway resource. Tagged so the remediation Lambda can find and terminate it.
resource "aws_instance" "runaway" {
  provider      = aws.sandbox
  ami           = data.aws_ssm_parameter.al2023.value
  instance_type = var.runaway_instance_type

  tags = {
    Name = "runaway-gpu-sim"
    demo = "runaway"
  }
}

# Break-glass admin role in the sandbox account, exempt from every cut-off SCP.
# Trust is intentionally narrow: the sandbox account root can assume it (tighten to a named
# principal in a real setup).
data "aws_iam_policy_document" "break_glass_assume" {
  provider = aws.sandbox
  statement {
    actions = ["sts:AssumeRole"]
    effect  = "Allow"
    principals {
      type        = "AWS"
      identifiers = ["arn:aws:iam::${var.sandbox_account_id}:root"]
    }
  }
}

resource "aws_iam_role" "break_glass" {
  provider           = aws.sandbox
  name               = var.break_glass_role_name
  assume_role_policy = data.aws_iam_policy_document.break_glass_assume.json
}

resource "aws_iam_role_policy_attachment" "break_glass_admin" {
  provider   = aws.sandbox
  role       = aws_iam_role.break_glass.name
  policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess"
}
