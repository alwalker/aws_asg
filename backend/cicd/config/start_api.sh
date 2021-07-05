#!/usr/bin/bash
set -e

INSTANCE_ID="`wget -qO- http://instance-data/latest/meta-data/instance-id`"
REGION="`wget -qO- http://instance-data/latest/meta-data/placement/availability-zone | sed -e 's:\([0-9][0-9]*\)[a-z]*\$:\\1:'`"
TAG_VALUE="`aws ec2 describe-tags --filters "Name=resource-id,Values=$INSTANCE_ID" "Name=key,Values=Environment" --region $REGION --output=text | cut -f5`"

aws s3 cp s3://$CUSTOMER-cicd/$TAG_VALUE.config_api.sh /opt/configs/api.sh
source /opt/configs/api.sh

cd /opt/api
dotnet Api.dll