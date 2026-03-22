data "archive_file" "lambda_zip" {
  type        = "zip"
  source_file = "${path.module}/../lambda/lambda_function.py"
  output_path = "${path.module}/lambda_function.zip"
}

resource "aws_iam_role" "lambda_role" {
  name = "${var.project_name}-lambda-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_policy" "lambda_policy" {
  name = "${var.project_name}-lambda-policy"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "DescribeInstances"
        Effect = "Allow"
        Action = [
          "ec2:DescribeInstances"
        ]
        Resource = "*"
      },
      {
        Sid    = "StartStopTaggedInstances"
        Effect = "Allow"
        Action = [
          "ec2:StartInstances",
          "ec2:StopInstances"
        ]
        Resource = "*"
        Condition = {
          StringEquals = {
            "ec2:ResourceTag/AutoSchedule" = "true"
          }
        }
      },
      {
        Sid    = "WriteLambdaLogs"
        Effect = "Allow"
        Action = [
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "${aws_cloudwatch_log_group.lambda_logs.arn}:*"
      },
      {
        Sid    = "PublishToSnsTopic"
        Effect = "Allow"
        Action = [
          "sns:Publish"
        ]
        Resource = aws_sns_topic.scheduler_notifications.arn
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_policy_attach" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = aws_iam_policy.lambda_policy.arn
}

resource "aws_iam_role" "scheduler_role" {
  name = "${var.project_name}-scheduler-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = "sts:AssumeRole"
        Principal = {
          Service = "scheduler.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_policy" "scheduler_invoke_lambda_policy" {
  name = "${var.project_name}-scheduler-invoke-lambda-policy"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "lambda:InvokeFunction"
        ]
        Resource = aws_lambda_function.scheduler.arn
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "scheduler_invoke_lambda_attach" {
  role       = aws_iam_role.scheduler_role.name
  policy_arn = aws_iam_policy.scheduler_invoke_lambda_policy.arn
}

resource "aws_cloudwatch_log_group" "lambda_logs" {
  name              = "/aws/lambda/${var.project_name}-scheduler-function"
  retention_in_days = 14
}

resource "aws_lambda_function" "scheduler" {
  function_name    = "${var.project_name}-scheduler-function"
  role             = aws_iam_role.lambda_role.arn
  handler          = "lambda_function.lambda_handler"
  runtime          = "python3.12"
  filename         = data.archive_file.lambda_zip.output_path
  source_code_hash = data.archive_file.lambda_zip.output_base64sha256
  timeout          = 30

  depends_on = [
    aws_cloudwatch_log_group.lambda_logs
  ]

  environment {
    variables = {
      TAG_KEY_1     = var.tag_key_1
      TAG_VALUE_1   = var.tag_value_1
      TAG_KEY_2     = var.tag_key_2
      TAG_VALUE_2   = var.tag_value_2
      SNS_TOPIC_ARN = aws_sns_topic.scheduler_notifications.arn
    }
  }
}

resource "aws_scheduler_schedule" "start_schedule" {
  name                         = "${var.project_name}-start-schedule"
  description                  = "Start tagged EC2 instances on Atlanta business schedule"
  schedule_expression          = "cron(0 8 ? * MON-FRI *)"
  schedule_expression_timezone = "America/New_York"

  flexible_time_window {
    mode = "OFF"
  }

  target {
    arn      = aws_lambda_function.scheduler.arn
    role_arn = aws_iam_role.scheduler_role.arn

    input = jsonencode({
      action = "start"
    })
  }
}

resource "aws_scheduler_schedule" "stop_schedule" {
  name                         = "${var.project_name}-stop-schedule"
  description                  = "Stop tagged EC2 instances on Atlanta business schedule"
  schedule_expression          = "cron(0 19 ? * MON-FRI *)"
  schedule_expression_timezone = "America/New_York"

  flexible_time_window {
    mode = "OFF"
  }

  target {
    arn      = aws_lambda_function.scheduler.arn
    role_arn = aws_iam_role.scheduler_role.arn

    input = jsonencode({
      action = "stop"
    })
  }
}

resource "aws_lambda_permission" "allow_start_schedule" {
  statement_id  = "AllowExecutionFromStartSchedule"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.scheduler.function_name
  principal     = "scheduler.amazonaws.com"
  source_arn    = aws_scheduler_schedule.start_schedule.arn
}

resource "aws_lambda_permission" "allow_stop_schedule" {
  statement_id  = "AllowExecutionFromStopSchedule"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.scheduler.function_name
  principal     = "scheduler.amazonaws.com"
  source_arn    = aws_scheduler_schedule.stop_schedule.arn
}

resource "aws_instance" "cost_saver_test" {
  ami           = "ami-043e339d258770711"
  instance_type = "t2.micro"

  tags = {
    Name         = "cost-saver-test"
    Environment  = "dev"
    AutoSchedule = "true"
    ManagedBy    = "terraform"
  }
}

resource "aws_sns_topic" "scheduler_notifications" {
  name = "${var.project_name}-notifications"
}

resource "aws_sns_topic_subscription" "email_alerts" {
  topic_arn = aws_sns_topic.scheduler_notifications.arn
  protocol  = "email"
  endpoint  = var.notification_email
}