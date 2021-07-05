variable "basename" {
  type    = string
  default = "dev"
}
variable "ami_name" {
  type = string
}
variable "dns_name" {
  default = "dev-api.customer.com"
}
variable "default_tags" {
  type = map(any)
  default = {
    Terraform   = "true"
    Environment = "dev"
  }
}