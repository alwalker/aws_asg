variable "basename" {
  type = string
}
variable "api_port" {
  type = string
}
variable "vpc_id" {
  type = string
}
variable "listener_arn" {
  type = string
}
variable "priority" {
  type = string
}
variable "host_headers" {
  type = list(any)
}
variable "hostedzone_id" {
  type = string
}
variable "dns_name" {
  type = string
}
variable "alb_dns_name" {
  type = string
}
variable "alb_dns_zone" {
  type = string
}
variable "default_tags" {
  type = map(any)
}