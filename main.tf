terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# 1. Updated to N. Virginia
provider "aws" {
  region = "us-east-1"
}

resource "aws_instance" "dev_server" {
  # 2. Updated to a valid Ubuntu AMI for us-east-1
  ami           = "ami-080e1f13689e07408" 
  instance_type = "t2.micro"             

  tags = {
    Name        = "Development-Server"
    Environment = "Dev"
    AutoStop    = "true"
  }
}
# 1. Zip up our Python file because AWS Lambda requires code to be uploaded as a .zip file
data "archive_file" "lambda_zip" {
  type        = "zip"
  source_file = "${path.module}/lambda/stop_instances.py"
  output_path = "${path.module}/lambda/stop_instances.zip"
}

# 2. Create an IAM Role (An ID badge that gives Lambda permission to run)
resource "aws_iam_role" "lambda_role" {
  name = "cost_saver_lambda_role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
    }]
  })
}

# 3. Attach a policy to the badge so Lambda is allowed to Stop EC2 instances
resource "aws_iam_role_policy" "lambda_policy" {
  name = "cost_saver_lambda_policy"
  role = aws_iam_role.lambda_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "arn:aws:logs:*:*:*"
      },
      {
        Effect   = "Allow"
        Action   = [
          "ec2:DescribeInstances",
          "ec2:StopInstances"
        ]
        Resource = "*"
      }
    ]
  })
}

# 4. Create the actual AWS Lambda Function
resource "aws_lambda_function" "stop_ec2_lambda" {
  filename         = data.archive_file.lambda_zip.output_path
  function_name    = "StopDevInstancesFunction"
  role             = aws_iam_role.lambda_role.arn
  handler          = "stop_instances.lambda_handler" # Pointing to filename.function_name
  runtime          = "python3.11"
  source_code_hash = data.archive_file.lambda_zip.output_base64sha256

  timeout = 10
}
# 1. Create the "Alarm Clock" rule (Set to trigger Monday through Friday at 5:00 PM EST)
resource "aws_cloudwatch_event_rule" "every_day_5pm" {
  name                = "stop-instances-every-day-5pm"
  description         = "Triggers our Lambda function every weekday at 5 PM to save money"
  schedule_expression = "cron(0 22 ? * MON-FRI *)" # 22:00 UTC is 5:00 PM EST
}

# 2. Tell the alarm clock WHAT to do when it rings (Trigger our Lambda function)
resource "aws_cloudwatch_event_target" "stop_instances_target" {
  rule      = aws_cloudwatch_event_rule.every_day_5pm.name
  target_id = "TriggerStopInstancesLambda"
  arn       = aws_lambda_function.stop_ec2_lambda.arn
}

# 3. Give EventBridge explicit permission to wake up and run our Lambda function
resource "aws_lambda_permission" "allow_eventbridge" {
  statement_id  = "AllowExecutionFromEventBridge"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.stop_ec2_lambda.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.every_day_5pm.arn
}