# The chain documents the full history of the resource. A consumer coming from
# v1 replays config -> app_config -> this in a single plan; a consumer coming
# from v2 replays only the second hop. This is why a published module KEEPS its
# moved blocks: drop the first hop and every v1 consumer breaks.

moved {
  from = aws_ssm_parameter.config
  to   = aws_ssm_parameter.app_config
}

moved {
  from = aws_ssm_parameter.app_config
  to   = aws_ssm_parameter.this
}
