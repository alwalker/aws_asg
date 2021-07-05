resource "aws_s3_bucket" "logs" {
  bucket = "${var.bucket_name}-logs"
  acl    = "log-delivery-write"

  tags = merge(map(
    "Name", "${var.bucket_name}-logs"),
    var.default_tags)
}
resource "aws_s3_bucket" "main" {
  bucket = var.bucket_name
  acl    = "private"

  logging {
    target_bucket = aws_s3_bucket.logs.id
  }

  tags = merge(map(
    "Name", var.bucket_name),
    var.default_tags)
}
resource "aws_iam_role" "transfer_user" {
  name = "${var.user_name}-transfer-user"

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
    "Name", "${var.user_name}-transfer-user"),
    var.default_tags)
}
resource "aws_iam_role_policy" "transfer_user" {
  name = "${var.user_name}-transfer-user"
  role = aws_iam_role.transfer_user.id

  policy = <<POLICY
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
            "s3:ListBucket",
            "s3:GetBucketLocation"
       ],
      "Resource": ["arn:aws:s3:::${var.bucket_name}"]
    },
    {
      "Effect": "Allow",
      "Action": [
        "s3:PutObject",
        "s3:GetObject",
        "s3:DeleteObject",              
        "s3:DeleteObjectVersion",
        "s3:GetObjectVersion",
        "s3:GetObjectACL",
        "s3:PutObjectACL"
      ],
      "Resource": ["arn:aws:s3:::${var.bucket_name}/*"]
    }
  ]
}    
POLICY
}
resource "aws_transfer_user" "main" {
  server_id = var.transfer_server_id
  user_name = var.user_name
  role      = aws_iam_role.transfer_user.arn

  home_directory = "/${aws_s3_bucket.main.id}/home"
}
resource "aws_transfer_ssh_key" "main" {
  server_id = var.transfer_server_id
  user_name = aws_transfer_user.main.user_name
  body      = var.ssh_public_key
}