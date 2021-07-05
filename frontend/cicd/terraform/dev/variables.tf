variable "basename" {
  type    = string
  default = "dev"
}
variable "default_tags" {
  type = map(any)
  default = {
    Terraform   = "true"
    Environment = "dev"
  }
}