#!/usr/bin/bash -xe
aws s3 cp s3://$CUSTOMER-cicd/cloudwatch.${env}.json /opt/configs/cloudwatch.json
/opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl -a fetch-config -m ec2 -c file:/opt/configs/cloudwatch.json -s
systemctl enable amazon-cloudwatch-agent