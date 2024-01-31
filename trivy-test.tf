data "aws_iam_policy_document" "ntc_lambda_policy" {
  statement {
    effect = "Allow"
    actions = [
      "logs:CreateLogGroup",
      "logs:CreateLogStream",
      "logs:PutLogEvents",
    ]
    resources = ["arn:aws:logs:*:*:*"]
  }

  statement {
    sid    = "AllowStepFunctionTasks"
    effect = "Allow"
    actions = [
      "kms:Decrypt",
      "sts:AssumeRole",
      "ec2:DescribeRegions",
      "states:StartExecution",
      "lambda:InvokeAsync",
      "lambda:InvokeFunction",
      "organizations:DescribeAccount",
      "organizations:ListTagsForResource"
    ]
    resources = ["*"]
  }
}