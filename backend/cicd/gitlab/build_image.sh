set -e

cd cicd/packer/

wget -q "https://releases.hashicorp.com/packer/1.6.5/packer_1.6.5_linux_amd64.zip" -O packer.zip
unzip -qq packer.zip

./packer build packer_app.json