data "aws_iam_policy_document" "ntc_trivy" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["*"]
    }
  }
}

resource "aws_iam_role" "ntc_trivy" {
  name               = "trivy_test"
  path               = "/"
  assume_role_policy = data.aws_iam_policy_document.ntc_trivy.json
}