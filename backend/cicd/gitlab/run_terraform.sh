set -e

cd cicd/terraform/$1

wget -q "https://releases.hashicorp.com/terraform/0.14.5/terraform_0.14.5_linux_amd64.zip" -O terraform.zip
unzip -qq terraform.zip

./terraform init
./terraform apply -var="ami_name=$CUSTOMER-api-$CI_PIPELINE_ID" -auto-approve