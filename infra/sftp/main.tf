provider "aws" {
  region     = "us-east-1"
}
terraform {
  backend "s3" {
    bucket  = "$CUSTOMER-terraform"
    key    = "sftp"
    region = "us-east-1"
  }
}
data "terraform_remote_state" "infra" {
  backend = "s3"

  config = {
    bucket = "$CUSTOMER-terraform"
    key    = "nonprod-infra"
    region = "us-east-1"
  }
}

resource "aws_transfer_server" "main" {
  identity_provider_type = "SERVICE_MANAGED"
  logging_role           = aws_iam_role.awstransfer.arn

  tags = merge(map(
    "Name", "ftp"),
    var.default_tags)
}
resource "aws_iam_role" "awstransfer" {
  name = "ftp"

  assume_role_policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
        "Effect": "Allow",
        "Principal": {
            "Service": "transfer.amazonaws.com"
        },
        "Action": "sts:AssumeRole"
        }
    ]
}
EOF

  tags = merge(map(
    "Name", "ftp"),
    var.default_tags)
}
resource "aws_iam_role_policy" "awstransfer" {
  name = "awstransfer"
  role = aws_iam_role.awstransfer.id

  policy = <<POLICY
{
    "Version": "2012-10-17",
    "Statement": [
        {
        "Sid": "AllowFullAccesstoCloudWatchLogs",
        "Effect": "Allow",
        "Action": [
            "logs:*"
        ],
        "Resource": "*"
        }
    ]
}
POLICY
}
resource "aws_route53_record" "main" {
  zone_id = data.terraform_remote_state.infra.outputs.hostedzone_id
  name    = "ftp"
  type    = "CNAME"
  ttl     = "5"
  records        = [aws_transfer_server.main.endpoint]
}

module "dev_user" {
  source = "./user"

  bucket_name = "$CUSTOMER-ftp-dev"
  user_name = "dev"
  ssh_public_key = ""
  transfer_server_id = aws_transfer_server.main.id
}