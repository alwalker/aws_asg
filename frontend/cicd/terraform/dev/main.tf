provider "aws" {
  region = "us-east-1"
}
terraform {
  backend "s3" {
    bucket = "$CUSTOMER-terraform"
    key    = "dev-frontend"
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

resource "aws_s3_bucket" "cloudfront_logs" {
  bucket = "$CUSTOMER-${var.basename}-cloudfront-logs"
  acl    = "log-delivery-write"

  tags = merge(map(
    "Name", "${var.basename}-cloudfront-logs"),
    var.default_tags)
}
resource "aws_s3_bucket" "main" {
  bucket = "$CUSTOMER-${var.basename}-frontend"
  acl = "public-read"
  force_destroy = true

  website {
    index_document = "index.html"
  }

  versioning {
    enabled = false
  }

  tags = merge(map(
    "Name", "${var.basename}-frontend"),
    var.default_tags)
}
resource "aws_s3_bucket_policy" "allow-frontend-get" {
  bucket = aws_s3_bucket.main.id
  policy = <<POLICY
{
  "Version": "2012-10-17",
  "Id": "front_staging_public_policy",
  "Statement": [
    {
      "Sid": "IPAllow",
      "Effect": "Allow",
      "Principal": "*",
      "Action": "s3:GetObject",
      "Resource": "${aws_s3_bucket.main.arn}/*"
    }
  ]
}
POLICY
}

locals {
  cloudfront_origin = "$CUSTOMERFRONTEND-${var.basename}"
}
resource "aws_cloudfront_distribution" "main" {
  origin {
    domain_name = aws_s3_bucket.main.bucket_regional_domain_name
    origin_id = local.cloudfront_origin
  }

  enabled = true
  is_ipv6_enabled = true
  comment = "$CUSTOMER ${var.basename} Frontend"
  default_root_object = "index.html"

  logging_config {
    include_cookies = false
    bucket = aws_s3_bucket.cloudfront_logs.bucket_domain_name
    prefix = "${var.basename}-"
  }

  aliases = ["${var.basename}.$CUSTOMER.com"]

  default_cache_behavior {
    allowed_methods = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
    cached_methods = ["GET", "HEAD"]
    target_origin_id = local.cloudfront_origin

    forwarded_values {
      query_string = false
      cookies {
        forward = "none"
      }
    }

    viewer_protocol_policy = "allow-all"
    min_ttl = 0
    default_ttl = 3600
    max_ttl = 86400
  }

  ordered_cache_behavior {
    path_pattern = "*"
    allowed_methods = ["GET", "HEAD", "OPTIONS"]
    cached_methods = ["GET", "HEAD", "OPTIONS"]
    target_origin_id = local.cloudfront_origin

    forwarded_values {
      query_string = false
      headers = ["Origin"]

      cookies {
        forward = "none"
      }
    }

    viewer_protocol_policy = "redirect-to-https"
  }

  # custom_error_response {
  #   error_code = 403
  #   response_code = 200
  #   response_page_path = "/index.html"
  # }

  # custom_error_response {
  #   error_code = 404
  #   response_code = 200
  #   response_page_path = "/index.html"
  # }

  price_class = "PriceClass_100"

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    acm_certificate_arn = data.terraform_remote_state.infra.outputs.cert_arn
    ssl_support_method = "sni-only"
  }

  tags = merge(map(
    "Name", "${var.basename}-frontend"),
    var.default_tags)
}
resource "aws_route53_record" "main" {
  zone_id = data.terraform_remote_state.infra.outputs.hostedzone_id
  name    = "${var.basename}.$CUSTOMER.com"
  type    = "A"

  alias {
    name                   = aws_cloudfront_distribution.main.domain_name
    zone_id                = aws_cloudfront_distribution.main.hosted_zone_id
    evaluate_target_health = false
  }
}
