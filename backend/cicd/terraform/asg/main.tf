resource "aws_key_pair" "main" {
  key_name   = "${var.basename}-api-key"
  public_key = var.public_key

  tags = var.default_tags
}
data "aws_ami" "api" {
  most_recent = true

  filter {
    name   = "name"
    values = [var.aminame]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  owners = [""]
}
resource "aws_placement_group" "api" {
  name     = "${var.basename}-api"
  strategy = "spread"

  tags = merge(map(
    "Name", "${var.basename}-api"),
  var.default_tags)
}
data "template_file" "cw_agent_setup_script" {
  template = file("../asg/setup_cw_agent.sh")

  vars = {
    env = var.basename
  }
}
resource "aws_launch_template" "api" {
  name                    = "${var.basename}-api"
  disable_api_termination = false
  ebs_optimized           = true
  image_id                = data.aws_ami.api.id
  instance_type           = var.instance_size
  key_name                = aws_key_pair.main.id
  vpc_security_group_ids  = var.security_group_ids
  user_data = base64encode(data.template_file.cw_agent_setup_script.rendered)

  block_device_mappings {
    device_name = "/dev/sda1"
    ebs {
      delete_on_termination = true
      encrypted             = true
      volume_type           = "gp3"
      volume_size           = var.root_volume_size
    }
  }

  iam_instance_profile {
    arn = var.iam_profile_arn
  }

  placement {
    group_name = aws_placement_group.api.id
  }

  tag_specifications {
    resource_type = "instance"
    tags = merge(map(
      "Name", "${var.basename}-api"),
    var.default_tags)
  }

  tags = merge(map(
    "Name", "${var.basename}-api"),
  var.default_tags)
}
resource "aws_autoscaling_group" "api" {
  name                      = "${var.basename}-api-asg-${aws_launch_template.api.latest_version}"
  max_size                  = var.max_instance_count
  min_size                  = var.min_instance_count
  health_check_grace_period = var.health_check_grace_period
  health_check_type         = "ELB"
  wait_for_elb_capacity     = 1
  desired_capacity          = var.base_instance_count
  force_delete              = false
  placement_group           = aws_placement_group.api.id
  vpc_zone_identifier       = var.private_subnets
  target_group_arns         = var.target_groups

  launch_template {
    id      = aws_launch_template.api.id
    version = "$Latest"
  }

  depends_on = [aws_cloudwatch_log_group.api-logs]
  lifecycle {
    create_before_destroy = true
    ignore_changes        = [desired_capacity]
  }
}

resource "aws_cloudwatch_log_group" "api-logs" {
  name              = "${var.basename}-api"
  retention_in_days = "30"
  kms_key_id = var.cw_kms_key_id

  tags = merge(map(
    "Name", "${var.basename}-api"),
  var.default_tags)
}

resource "aws_cloudwatch_metric_alarm" "asg_cpu_utilization_high" {
  alarm_name          = "${var.basename}-CPU-Utilization-High-${var.asg_cpu_max_threshold}"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = "1"
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = "120"
  statistic           = "Average"
  threshold           = var.asg_cpu_max_threshold

  dimensions = {
    AutoScalingGroupName = aws_autoscaling_group.api.name
  }

  alarm_actions = [aws_autoscaling_policy.asg_scale_up.arn]

  tags = merge(map(
    "Name", "${var.basename}-CPU-Utilization-High-${var.asg_cpu_max_threshold}"),
  var.default_tags)
}
resource "aws_cloudwatch_metric_alarm" "asg_cpu_utilization_low" {
  alarm_name          = "${var.basename}-CPU-Utilization-Low-${var.asg_cpu_min_threshold}"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = "1"
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = "120"
  statistic           = "Average"
  threshold           = var.asg_cpu_min_threshold

  dimensions = {
    AutoScalingGroupName = aws_autoscaling_group.api.name
  }

  alarm_actions = [aws_autoscaling_policy.asg_scale_down.arn]

  tags = merge(map(
    "Name", "${var.basename}-CPU-Utilization-Low-${var.asg_cpu_min_threshold}"),
  var.default_tags)
}
resource "aws_autoscaling_policy" "asg_scale_up" {
  name                   = "${var.basename}-scale-up"
  scaling_adjustment     = 1
  adjustment_type        = "ChangeInCapacity"
  cooldown               = 120
  autoscaling_group_name = aws_autoscaling_group.api.name
}
resource "aws_autoscaling_policy" "asg_scale_down" {
  name                   = "${var.basename}-scale-down"
  scaling_adjustment     = -1
  adjustment_type        = "ChangeInCapacity"
  cooldown               = 300
  autoscaling_group_name = aws_autoscaling_group.api.name
}
