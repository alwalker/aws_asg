variable "basename" {
  type = string
}
variable "aminame" {
  type = string
}
variable "asg_cpu_min_threshold" {
  type = string
}
variable "asg_cpu_max_threshold" {
  type = string
}
variable "default_tags" {
  type = map(any)
}
variable "public_key" {
  type = string
}
variable "instance_size" {
  type = string
}
variable "security_group_ids" {
  type = list(any)
}
variable "root_volume_size" {
  type = string
}
variable "iam_profile_arn" {
  type = string
}
variable "max_instance_count" {
  type = string
}
variable "min_instance_count" {
  type = string
}
variable "health_check_grace_period" {
  type = string
}
variable "base_instance_count" {
  type = string
}
variable "private_subnets" {
  type = list(any)
}
variable "target_groups" {
  type = list(any)
}
variable "cw_kms_key_id" {
  type = string
}
