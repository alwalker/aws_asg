provider "aws" {
  region = "us-east-1"
}
terraform {
  backend "s3" {
    bucket = "$CUSTOMER-terraform"
    key    = "dev-api"
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

module "IAM" {
  source = "../iam"

  basename     = var.basename
  default_tags = var.default_tags
}

module "ALB" {
  source = "../alb"

  basename     = var.basename
  default_tags = var.default_tags

  api_port = 61000
  vpc_id   = data.terraform_remote_state.infra.outputs.vpc_id

  listener_arn = data.terraform_remote_state.infra.outputs.alb_listener
  priority     = 101
  host_headers = [var.dns_name]

  hostedzone_id = data.terraform_remote_state.infra.outputs.hostedzone_id
  dns_name      = var.dns_name
  alb_dns_name  = data.terraform_remote_state.infra.outputs.alb_dns_name
  alb_dns_zone  = data.terraform_remote_state.infra.outputs.alb_dns_zone
}

module "ASG" {
  source = "../asg"

  basename     = var.basename
  default_tags = var.default_tags

  public_key                = ""
  aminame                   = var.ami_name
  instance_size             = "t3a.micro"
  base_instance_count       = 1
  min_instance_count        = 1
  max_instance_count        = 2
  security_group_ids        = [data.terraform_remote_state.infra.outputs.dev_api_securitygroup_id]
  health_check_grace_period = 360
  root_volume_size          = 10
  iam_profile_arn           = module.IAM.iam_profile_arn
  private_subnets           = data.terraform_remote_state.infra.outputs.private_subnets
  target_groups             = [module.ALB.api_target_group]
  asg_cpu_max_threshold     = 75
  asg_cpu_min_threshold     = 25
  cw_kms_key_id = data.terraform_remote_state.infra.outputs.cw_kms_key_arn
}