provider "aws" {
  region = "us-east-1"
}

terraform {
  backend "s3" {
    bucket = "$CUSTOMER-terraform"
    key    = "nonprod-infra"
    region = "us-east-1"
  }
}

module "vpc" {
  source = "terraform-aws-modules/vpc/aws"

  name = var.basename
  cidr = "10.0.0.0/16"

  azs              = ["us-east-1a", "us-east-1b", "us-east-1c", "us-east-1d", "us-east-1e", "us-east-1f"]
  private_subnets  = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24", "10.0.4.0/24", "10.0.5.0/24", "10.0.6.0/24"]
  database_subnets = ["10.0.51.0/24", "10.0.52.0/24", "10.0.53.0/24", "10.0.54.0/24", "10.0.55.0/24", "10.0.56.0/24"]
  public_subnets   = ["10.0.101.0/24", "10.0.102.0/24", "10.0.103.0/24", "10.0.104.0/24", "10.0.105.0/24", "10.0.106.0/24"]

  enable_nat_gateway = false
  # single_nat_gateway = true
  # one_nat_gateway_per_az = false
  enable_vpn_gateway = false

  enable_dns_hostnames = true
  enable_dns_support   = true

  enable_s3_endpoint = true

  enable_ec2_endpoint              = true
  ec2_endpoint_private_dns_enabled = true
  ec2_endpoint_security_group_ids  = [aws_security_group.ec2_endpoint.id]

  enable_logs_endpoint = true 
  logs_endpoint_private_dns_enabled  = true
  logs_endpoint_security_group_ids = [aws_security_group.logs_endpoint.id]

  tags = var.default_tags
}

module "cloudwatch_kms_key" {
  source = "dod-iac/cloudwatch-kms-key/aws"

  tags = merge(map(
    "Name", "cw-logs"),
    var.default_tags)
}

###############################################################################
#                                  ALB                                        #
###############################################################################
resource "aws_security_group" "alb" {
  name        = "${var.basename}-alb"
  vpc_id      = module.vpc.vpc_id
  description = "Allow HTTPS in from the world"

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(map(
    "Name", "${var.basename}-alb"),
    var.default_tags)
}
resource "aws_lb" "main" {
  name                       = var.basename
  internal                   = false
  load_balancer_type         = "application"
  security_groups            = [aws_security_group.alb.id]
  subnets                    = module.vpc.public_subnets
  enable_deletion_protection = false

  tags = merge(map(
    "Name", var.basename),
    var.default_tags)
}
resource "aws_lb_listener" "https" {
  load_balancer_arn = aws_lb.main.arn
  port = 443
  protocol = "HTTPS"
  certificate_arn = var.cert_arn
  default_action {
     type = "fixed-response"

    fixed_response {
      content_type = "text/plain"
      message_body = "HEALTHY"
      status_code  = "200"
    }
  }
}
resource "aws_lb_listener" "http_redirect" {
  load_balancer_arn = aws_lb.main.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type = "redirect"

    redirect {
      port        = "443"
      protocol    = "HTTPS"
      status_code = "HTTP_301"
    }
  }
}

###############################################################################
#                               SSH Bastion                                   #
###############################################################################
resource "aws_security_group" "bastion" {
  name        = "${var.basename}-bastion"
  vpc_id      = module.vpc.vpc_id
  description = "Allow SSH in from the world"

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = var.ssh_port
    to_port     = var.ssh_port
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(map(
    "Name", "${var.basename}-bastion"),
    var.default_tags)
}
resource "aws_key_pair" "bastion" {
  key_name   = "${var.basename}-bastion-key"
  public_key = ""

  tags = var.default_tags
}
data "aws_ami" "centos-8-stream" {
  most_recent = true

  filter {
    name   = "name"
    values = ["CentOS Stream *"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  filter {
    name   = "architecture"
    values = ["x86_64"]
  }

  owners = ["125523088429"]
}
resource "aws_instance" "bastion" {
  ami                         = data.aws_ami.centos-8-stream.id
  instance_type               = "t3a.nano"
  vpc_security_group_ids      = [aws_security_group.bastion.id]
  subnet_id                   = module.vpc.public_subnets[0]
  key_name                    = aws_key_pair.bastion.key_name
  associate_public_ip_address = true
  user_data                   = <<EOF
#!/usr/bin/bash -xe
dnf install -y epel-release
dnf install -y atop screen postgresql tree nc bind-utils curl wget lsof zip unzip
EOF

  root_block_device {
    volume_type = "gp3"
    encrypted = true
  }

  lifecycle {
    ignore_changes = [ami]
  }

  tags = merge(map(
    "Name", "${var.basename}-bastion"),
    var.default_tags)
}
resource "aws_route53_record" "bastion" {
  zone_id = var.hostedzone_id
  name    = "${var.basename}-bastion.$CUSTOMER.com"
  type    = "A"
  ttl     = "300"
  records = [aws_instance.bastion.public_ip]
}

###############################################################################
#                            AMI Test Instance                                #
###############################################################################
# resource "aws_iam_role" "amitest" {
#   name        = "${var.basename}-amitest"
#   description = "Allows EC2 tasks to do the things"

#   assume_role_policy = <<EOF
# {
#   "Version": "2008-10-17",
#   "Statement": [
#     {
#       "Effect": "Allow",
#       "Principal": {
#         "Service": "ec2.amazonaws.com"
#       },
#       "Action": "sts:AssumeRole"
#     }
#   ]
# }
# EOF
# }
# resource "aws_iam_policy" "amitest" {
#   name   = "${var.basename}-amitest"
#   policy = <<EOF
# {
#     "Version": "2012-10-17",
#     "Statement": [
#         {
#             "Sid": "VisualEditor0",
#             "Effect": "Allow",
#             "Action": [
#                 "s3:*"
#             ],
#             "Resource": [
#                 "arn:aws:s3:::$CUSTOMER-cicd",
#                 "arn:aws:s3:::$CUSTOMER-cicd/*"
#             ]
#         },
#         {
#             "Sid": "VisualEditor1",
#             "Effect": "Allow",
#             "Action": "ec2:DescribeTags",
#             "Resource": "*"
#         }
#     ]
# }
# EOF
# }
# resource "aws_iam_role_policy_attachment" "amitest" {
#   role       = aws_iam_role.amitest.name
#   policy_arn = aws_iam_policy.amitest.arn
# }
# resource "aws_iam_instance_profile" "amitest" {
#   name = "${var.basename}-amitest"
#   role = aws_iam_role.amitest.id
# }
# resource "aws_instance" "amitest" {
#   ami                         = "ami-"
#   instance_type               = "t3a.nano"
#   vpc_security_group_ids      = [aws_security_group.bastion.id]
#   subnet_id                   = module.vpc.public_subnets[0]
#   key_name                    = aws_key_pair.bastion.key_name
#   associate_public_ip_address = true
#   iam_instance_profile        = aws_iam_instance_profile.amitest.id

#   root_block_device {
#     volume_type = "gp3"
#     encrypted = true
#   }

#   tags = {
#     Name        = "${var.basename}-amitest"
#     Terraform   = "true"
#     Environment = "nonprod"
#     Env         = "dev"
#   }
# }

###############################################################################
#                              Security Groups                                #
###############################################################################
resource "aws_security_group" "dev_api" {
  name        = "${var.basename}-dev-api"
  vpc_id      = module.vpc.vpc_id
  description = "Allow HTTPS in from load balancer"

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port       = var.api_port
    to_port         = var.api_port
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
  }
  ingress {
    from_port       = var.ssh_port
    to_port         = var.ssh_port
    protocol        = "tcp"
    security_groups = [aws_security_group.bastion.id]
  }

  tags = merge(map(
    "Name", "dev-api"),
    var.default_tags)
}
resource "aws_security_group" "qa_api" {
  name        = "${var.basename}-qa-api"
  vpc_id      = module.vpc.vpc_id
  description = "Allow HTTPS in from load balancer"

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port       = var.api_port
    to_port         = var.api_port
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
  }
  ingress {
    from_port       = var.ssh_port
    to_port         = var.ssh_port
    protocol        = "tcp"
    security_groups = [aws_security_group.bastion.id]
  }

  tags = merge(map(
    "Name", "qa-api"),
    var.default_tags)
}
resource "aws_security_group" "packer" {
  name        = "packer"
  vpc_id      = module.vpc.vpc_id
  description = "Allow SSH in from the world"

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(map(
    "Name", "packer"),
    var.default_tags)
}
resource "aws_security_group" "ec2_endpoint" {
  name        = "ec2-endpoint"
  vpc_id      = module.vpc.vpc_id
  description = "Allow All in from the private subnets"

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = module.vpc.private_subnets_cidr_blocks
  }

  tags = merge(map(
    "Name", "${var.basename}-ec2-endpoint"),
    var.default_tags)
}
resource "aws_security_group" "logs_endpoint" {
  name        = "logs-endpoint"
  vpc_id      = module.vpc.vpc_id
  description = "Allow All in from the private subnets"

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = module.vpc.private_subnets_cidr_blocks
  }

  tags = merge(map(
    "Name", "${var.basename}-logs-endpoint"),
    var.default_tags)
}

###############################################################################
#                                    RDS                                      #
###############################################################################
resource "aws_security_group" "dev_app_db" {
  name        = "${var.basename}-dev-appdb"
  vpc_id      = module.vpc.vpc_id
  description = "Allow Postgres in from API"

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.dev_api.id, aws_security_group.qa_api.id, aws_security_group.bastion.id, aws_security_group.superset.id]
  }

  tags = merge(map(
    "Name", "${var.basename}-db-application"),
    var.default_tags)
}
resource "aws_db_instance" "app" {
  allocated_storage           = 20
  allow_major_version_upgrade = false
  apply_immediately           = false
  auto_minor_version_upgrade  = true
  backup_retention_period     = 14
  backup_window               = "05:00-06:00"
  db_subnet_group_name        = module.vpc.database_subnet_group
  delete_automated_backups    = true
  engine                      = "postgres"
  engine_version              = "11"
  identifier                  = "${var.basename}-application"
  instance_class              = "db.t3.small"
  maintenance_window          = "Mon:06:01-Mon:10:00"
  password                    = var.app_db_password
  publicly_accessible         = false
  skip_final_snapshot         = true
  storage_encrypted           = true
  storage_type                = "gp2"
  username                    = "nonprodadmin"
  vpc_security_group_ids      = [aws_security_group.dev_app_db.id]

  tags = merge(map(
    "Name", "${var.basename}-application"),
    var.default_tags)
}
# resource "aws_db_instance" "reporting" {
#   allocated_storage           = 20
#   allow_major_version_upgrade = false
#   apply_immediately           = false
#   auto_minor_version_upgrade  = true
#   backup_retention_period     = 0
#   backup_window               = "05:00-06:00"
#   delete_automated_backups    = true
#   engine                      = "postgres"
#   engine_version              = "11"
#   identifier                  = "${var.basename}-reporting"
#   instance_class              = "db.t3.small"
#   maintenance_window          = "Mon:06:01-Mon:10:00"
#   publicly_accessible         = false
#   replicate_source_db         = aws_db_instance.app.id
#   skip_final_snapshot         = true
#   storage_encrypted           = true
#   storage_type                = "gp2"
#   vpc_security_group_ids      = [aws_security_group.dev_app_db.id]

#   tags = merge(map(
    # "Name", "${var.basename}-reporting"),
    # var.default_tags)
# }

#Dev Setup
data "template_file" "dev_db_destroy_script" {
  template = file("scripts/db_destroy.sql")

  vars = {
    db   = "dev$CUSTOMER"
    user = "devapi"
  }
}
data "template_file" "dev_db_setup_script" {
  template = file("scripts/db_setup.sql")

  vars = {
    password = var.dev_app_db_password
    db       = "dev$CUSTOMER"
    user     = "devapi"
  }
}
resource "null_resource" "dev_db_setup" {
  provisioner "file" {
    content     = data.template_file.dev_db_setup_script.rendered
    destination = "/tmp/dev_db_setup.sql"

    connection {
      type        = "ssh"
      user        = "centos"
      port        = var.ssh_port
      private_key = file(".secrets/id_$CUSTOMER_nonprod")
      host        = aws_instance.bastion.public_ip
    }
  }
  provisioner "remote-exec" {
    inline = [
      "date >> /tmp/tftest",
      "PGPASSWORD=${var.app_db_password} psql -a -h ${aws_db_instance.app.address} -U nonprodadmin postgres -f /tmp/dev_db_setup.sql"
    ]

    connection {
      type        = "ssh"
      user        = "centos"
      port        = var.ssh_port
      private_key = file(".secrets/id_$CUSTOMER_nonprod")
      host        = aws_instance.bastion.public_ip
    }
  }
}
# resource "null_resource" "dev_db_destroy" {
#   provisioner "file" {
#     content     = data.template_file.dev_db_destroy_script.rendered
#     destination = "/tmp/dev_db_destroy.sql"

#     connection {
#       type        = "ssh"
#       user        = "centos"
#       port        = var.ssh_port
#       private_key = file(".secrets/id_$CUSTOMER_nonprod")
#       host        = aws_instance.bastion.public_ip
#     }
#   }
#   provisioner "remote-exec" {
#     inline = [
#       "date >> /tmp/tftest",
#       "PGPASSWORD=${var.app_db_password} psql -a -h ${aws_db_instance.app.address} -U nonprodadmin postgres -f /tmp/dev_db_destroy.sql"
#     ]

#     connection {
#       type        = "ssh"
#       user        = "centos"
#       port        = var.ssh_port
#       private_key = file(".secrets/id_$CUSTOMER_nonprod")
#       host        = aws_instance.bastion.public_ip
#     }
#   }
# }
#QA Setup
data "template_file" "qa_db_setup_script" {
  template = file("scripts/db_setup.sql")

  vars = {
    password = var.qa_app_db_password
    db       = "qa$CUSTOMER"
    user     = "qaapi"
  }
}
resource "null_resource" "qa_db_setup" {
  depends_on = [ null_resource.dev_db_setup ]

  provisioner "file" {
    content     = data.template_file.qa_db_setup_script.rendered
    destination = "/tmp/qa_db_setup.sql"

    connection {
      type        = "ssh"
      user        = "centos"
      port        = var.ssh_port
      private_key = file(".secrets/id_$CUSTOMER_nonprod")
      host        = aws_instance.bastion.public_ip
    }
  }
  provisioner "remote-exec" {
    inline = [
      "date >> /tmp/tftest",
      "PGPASSWORD=${var.app_db_password} psql -a -h ${aws_db_instance.app.address} -U nonprodadmin postgres -f /tmp/qa_db_setup.sql"
    ]

    connection {
      type        = "ssh"
      user        = "centos"
      port        = var.ssh_port
      private_key = file(".secrets/id_$CUSTOMER_nonprod")
      host        = aws_instance.bastion.public_ip
    }
  }
}
#Superset Setup
data "template_file" "supeset_db_setup_script" {
  template = file("scripts/db_setup_superset.sql")

  vars = {
    password = var.superset_app_db_password
    db       = "dev$CUSTOMER"
    user     = "superset"
  }
}
resource "null_resource" "superset_db_setup" {
  depends_on = [ null_resource.qa_db_setup ]

  provisioner "file" {
    content     = data.template_file.supeset_db_setup_script.rendered
    destination = "/tmp/superset_db_setup.sql"

    connection {
      type        = "ssh"
      user        = "centos"
      port        = var.ssh_port
      private_key = file(".secrets/id_$CUSTOMER_nonprod")
      host        = aws_instance.bastion.public_ip
    }
  }
  provisioner "remote-exec" {
    inline = [
      "PGPASSWORD=${var.app_db_password} psql -a -h ${aws_db_instance.app.address} -U nonprodadmin postgres -f /tmp/superset_db_setup.sql"
    ]

    connection {
      type        = "ssh"
      user        = "centos"
      port        = var.ssh_port
      private_key = file(".secrets/id_$CUSTOMER_nonprod")
      host        = aws_instance.bastion.public_ip
    }
  }
}
