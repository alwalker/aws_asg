output "vpc_id" {
  value = module.vpc.vpc_id
}
output "a_public_subnet" {
  value = module.vpc.public_subnets[0]
}
output "bastion_ip" {
  value = aws_instance.bastion.public_ip
}
output "rds_host_name" {
  value = aws_db_instance.app.address
}
# output "rds_reporting_host_name" {
#   value = aws_db_instance.reporting.address
# }
output "alb_arn" {
  value = aws_lb.main.arn
}
output "alb_dns_zone" {
  value = aws_lb.main.zone_id
}
output "alb_dns_name" {
  value = aws_lb.main.dns_name
}
output "alb_listener" {
  value = aws_lb_listener.https.id
}
output "api_securitygroup_id" {
  value = aws_security_group.api.id
}
output "private_subnets" {
  value = module.vpc.private_subnets
}
output "api_port" {
  value = var.api_port
}
output "cert_arn" {
  value = var.cert_arn
}
output "hostedzone_id" {
  value = var.hostedzone_id
}
output "cw_kms_key_arn" {
  value = module.cloudwatch_kms_key.aws_kms_key_arn
}