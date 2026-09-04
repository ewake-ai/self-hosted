# No static event rule — reactive creates a per-incident schedule when the bot joins the channel.
#
# lambda_queue_url is declared once for this submodule in release-watch.tf; this Lambda publishes
# its follow-up messages to the same queue for the reactive Lambda to prepare.

resource "aws_cloudwatch_log_group" "incident_follow_up" {
  name              = "/${var.ssm_path}/incident-follow-up"
  retention_in_days = 14
  tags              = local.scheduled_tags
}

resource "aws_lambda_function" "incident_follow_up" {
  function_name = "${var.arn_prefix}-incident-follow-up"
  description   = "\"incident-follow-up\" for ${var.arn_prefix}"
  role          = var.task_role_arn
  package_type  = "Image"
  image_uri     = var.lambda_bundle_image_uri
  timeout       = 300
  memory_size   = 1024

  # The bundled image has no CMD, so this is what makes the function run this Lambda.
  image_config {
    command = ["handlers/incident-follow-up.handler"]
  }

  environment {
    variables = merge(local.scheduled_lambda_env_common, {
      DD_SERVICE       = "incident-follow-up"
      LAMBDA_QUEUE_URL = var.lambda_queue_url
    })
  }

  logging_config {
    log_format = "Text"
    log_group  = aws_cloudwatch_log_group.incident_follow_up.name
  }

  vpc_config {
    subnet_ids         = var.private_subnets
    security_group_ids = local.vpc_security_group_ids
  }

  tags = merge(local.scheduled_tags, { Service = "incident-follow-up" })
}

resource "aws_cloudwatch_log_subscription_filter" "incident_follow_up_to_datadog" {
  count           = var.datadog_enabled ? 1 : 0
  name            = "${var.arn_prefix}-incident-follow-up-to-datadog"
  log_group_name  = aws_cloudwatch_log_group.incident_follow_up.name
  filter_pattern  = ""
  destination_arn = var.datadog_forwarder_arn
}
