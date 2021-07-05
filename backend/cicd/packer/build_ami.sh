set -e

#update base image
dnf update -y --refresh

#install helpful tools
dnf install -y epel-release
dnf install -y vim screen atop tree nc bind-utils curl jq lsof unzip wget

#setup awscli
curl -s "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip -q awscliv2.zip
./aws/install
ln -s /usr/local/bin/aws /usr/bin/aws

#setup dotnet
dnf install -y aspnetcore-runtime-3.1

#setup api user
useradd -c "$CUSTOMER API User" -s /bin/bash -m $CUSTOMER

#setup api directories
mkdir /opt/api
aws s3 cp s3://$CUSTOMER-cicd/api.$CI_PIPELINE_ID.tar.gz /tmp/api.tar.gz
tar -xzf /tmp/api.tar.gz -C /opt/api
chown -R $CUSTOMER:$CUSTOMER /opt/api

mkdir /opt/configs
chown $CUSTOMER:$CUSTOMER /opt/configs

#setup api systemd unit 
cat << EOF > /lib/systemd/system/$CUSTOMER-api.service
[Unit]
Description=$CUSTOMER API

[Service]
User=$CUSTOMER
WorkingDirectory=/opt/api
ExecStart=/usr/local/src/start_api.sh
Restart=on-failure
RestartSec=30
Type=simple

[Install]
WantedBy=multi-user.target
EOF
systemctl daemon-reload

#setup app
aws s3 cp s3://$CUSTOMER-cicd/start_api.sh /usr/local/src/start_api.sh
chown $CUSTOMER:$CUSTOMER /usr/local/src/start_api.sh
chmod 700 /usr/local/src/start_api.sh
systemctl enable $CUSTOMER-api

#setup cloudwatch agent
wget --quiet "https://s3.amazonaws.com/amazoncloudwatch-agent/amazon_linux/amd64/latest/amazon-cloudwatch-agent.rpm"
rpm -U amazon-cloudwatch-agent.rpm
rm amazon-cloudwatch-agent.rpm
