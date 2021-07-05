variable "bucket_name" {
  type = string
}
variable "user_name" {
  type = string
}
variable "ssh_public_key" {
  type = string
}
variable "transfer_server_id" {
  type = string
}
variable default_tags {
  type = map
  default = {
    Terraform   = "true"
  }
}