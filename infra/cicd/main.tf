provider "aws" {
  region     = "us-east-1"
}
terraform {
  backend "s3" {
    bucket  = "$CUSTOMER-terraform"
    key    = "cicd"
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

resource "aws_s3_bucket" "gitlab" {
  bucket = "$CUSTOMER-cicd"
  acl    = "private"

  server_side_encryption_configuration {
    rule {
      apply_server_side_encryption_by_default {
        sse_algorithm     = "AES256"
      }
    }
  }
}
resource "aws_iam_user" "gitlab" {
  name = "gitlabci"
  path = "/"
}
resource "aws_iam_user_policy_attachment" "gitlab" {
  user = aws_iam_user.gitlab.name
  policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess"
}

resource "aws_iam_role" "packer" {
  name = "packer"
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
}
data "template_file" "packer-policies" {
    template = file("packer_policy.json")

    vars = {
        bucket_name = aws_s3_bucket.gitlab.id
    }
}
resource "aws_iam_policy" "packer" {
  name = "packer"
  description = "Grant Packer permisions to do the things"
  policy = data.template_file.packer-policies.rendered
}
resource "aws_iam_role_policy_attachment" "packer" {
    role       = aws_iam_role.packer.name
    policy_arn = aws_iam_policy.packer.arn
}
resource "aws_iam_instance_profile" "packer" {
  name = "packer"
  role = aws_iam_role.packer.id
}