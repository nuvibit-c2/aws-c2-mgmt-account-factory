data "aws_iam_policy_document" "ntc_trivy_assume" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["*"]
    }
  }
}

data "aws_iam_policy_document" "ntc_trivy_policy" {
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

resource "aws_iam_role" "ntc_trivy_role" {
  name               = "trivy_test"
  path               = "/"
  assume_role_policy = data.aws_iam_policy_document.ntc_trivy_assume.json
}

resource "aws_iam_role_policy" "ntc_trivy_role" {
  name = "trivy_test"
  role = aws_iam_role.ntc_trivy_role.id

  policy = data.aws_iam_policy_document.ntc_trivy_policy.json
}