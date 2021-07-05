resource "aws_iam_role" "api" {
  name        = "${var.basename}-api"
  description = "Allows EC2 tasks to do the things"

  assume_role_policy = <<EOF
{
  "Version": "2008-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "ec2.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF

  tags = merge(map(
    "Name", "${var.basename}-api"),
  var.default_tags)
}
data "template_file" "api-policies" {
  template = file("../iam/policies/api.json")

  vars = {
    bucket_name = "$CUSTOMER-cicd"
  }
}
resource "aws_iam_policy" "api" {
  name        = "${var.basename}-api"
  description = "Grant api permisions to do the things"
  policy      = data.template_file.api-policies.rendered
}
resource "aws_iam_role_policy_attachment" "api" {
  role       = aws_iam_role.api.name
  policy_arn = aws_iam_policy.api.arn
}
resource "aws_iam_role_policy_attachment" "cloudwatchagent" {
  role       = aws_iam_role.api.name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
}
resource "aws_iam_instance_profile" "api" {
  name = "${var.basename}-api"
  role = aws_iam_role.api.id
}