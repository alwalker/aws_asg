variable "basename" {
  type    = string
  default = "nonprod"
}
variable "app_db_password" {
  type = string
}
variable "dev_app_db_password" {
  type = string
}
variable "qa_app_db_password" {
  type = string
}
variable "superset_app_db_password" {
  type = string
}
variable "ssh_port" {
  type    = string
  default = "22"
}
variable "api_port" {
  type    = string
  default = "61000"
}
variable "hostedzone_id" {
  default = ""
}
variable "cert_arn" {
  type = string
  default = "arn:aws:acm:us-east-1::certificate/"
}
variable default_tags {
  type = map
  default = {
    Terraform   = "true"
    Environment = "nonprod"
  }
}