#!/usr/bin/env bash
# setup_vpc_ec2.sh — create a small VPC with one public subnet and one tagged EC2 instance.
# Every resource gets cost-allocation tags (Project, Owner, Environment) for FinOps reporting.
#
# Usage: MY_IP=203.0.113.10 KEY_NAME=my-key ./setup_vpc_ec2.sh
# Writes created resource IDs to .lab-state so cleanup.sh can delete them.

set -euo pipefail

REGION="${AWS_REGION:-ap-southeast-1}"
PROJECT="finops-lab"
OWNER="${OWNER:-sim}"
MY_IP="${MY_IP:?set MY_IP to your public IP for SSH access}"
KEY_NAME="${KEY_NAME:?set KEY_NAME to an existing EC2 key pair}"
STATE_FILE=".lab-state"

TAGS="{Key=Project,Value=$PROJECT},{Key=Owner,Value=$OWNER},{Key=Environment,Value=lab}"
tag_spec() { echo "ResourceType=$1,Tags=[{Key=Name,Value=$PROJECT-$1},$TAGS]"; }

aws() { command aws --region "$REGION" "$@"; }

echo "Creating VPC..."
VPC_ID=$(aws ec2 create-vpc --cidr-block 10.0.0.0/16 \
  --tag-specifications "$(tag_spec vpc)" --query Vpc.VpcId --output text)

SUBNET_ID=$(aws ec2 create-subnet --vpc-id "$VPC_ID" --cidr-block 10.0.1.0/24 \
  --tag-specifications "$(tag_spec subnet)" --query Subnet.SubnetId --output text)

IGW_ID=$(aws ec2 create-internet-gateway \
  --tag-specifications "$(tag_spec internet-gateway)" --query InternetGateway.InternetGatewayId --output text)
aws ec2 attach-internet-gateway --vpc-id "$VPC_ID" --internet-gateway-id "$IGW_ID"

RTB_ID=$(aws ec2 create-route-table --vpc-id "$VPC_ID" \
  --tag-specifications "$(tag_spec route-table)" --query RouteTable.RouteTableId --output text)
aws ec2 create-route --route-table-id "$RTB_ID" --destination-cidr-block 0.0.0.0/0 --gateway-id "$IGW_ID" > /dev/null
aws ec2 associate-route-table --route-table-id "$RTB_ID" --subnet-id "$SUBNET_ID" > /dev/null
aws ec2 modify-subnet-attribute --subnet-id "$SUBNET_ID" --map-public-ip-on-launch

echo "Creating security group (SSH from $MY_IP only)..."
SG_ID=$(aws ec2 create-security-group --group-name "$PROJECT-sg" --description "SSH from admin IP only" \
  --vpc-id "$VPC_ID" --tag-specifications "$(tag_spec security-group)" --query GroupId --output text)
aws ec2 authorize-security-group-ingress --group-id "$SG_ID" --protocol tcp --port 22 --cidr "$MY_IP/32" > /dev/null

echo "Launching t3.micro (free-tier eligible in most regions)..."
AMI_ID=$(aws ssm get-parameter --name /aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64 \
  --query Parameter.Value --output text)
INSTANCE_ID=$(aws ec2 run-instances --image-id "$AMI_ID" --instance-type t3.micro \
  --key-name "$KEY_NAME" --subnet-id "$SUBNET_ID" --security-group-ids "$SG_ID" \
  --metadata-options HttpTokens=required \
  --tag-specifications "$(tag_spec instance)" "$(tag_spec volume)" \
  --query 'Instances[0].InstanceId' --output text)

cat > "$STATE_FILE" <<EOF
REGION=$REGION
VPC_ID=$VPC_ID
SUBNET_ID=$SUBNET_ID
IGW_ID=$IGW_ID
RTB_ID=$RTB_ID
SG_ID=$SG_ID
INSTANCE_ID=$INSTANCE_ID
EOF

echo "Done. Resources saved to $STATE_FILE"
cat "$STATE_FILE"
