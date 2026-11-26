#!/usr/bin/env bash
# cleanup.sh — delete everything setup_vpc_ec2.sh created, in dependency order.
# Run this after every lab session so nothing keeps billing.

set -euo pipefail

STATE_FILE=".lab-state"
[[ -f "$STATE_FILE" ]] || { echo "No $STATE_FILE found, nothing to clean up."; exit 0; }
# shellcheck source=/dev/null
source "$STATE_FILE"

aws() { command aws --region "$REGION" "$@"; }

echo "Terminating $INSTANCE_ID..."
aws ec2 terminate-instances --instance-ids "$INSTANCE_ID" > /dev/null
aws ec2 wait instance-terminated --instance-ids "$INSTANCE_ID"

aws ec2 delete-security-group --group-id "$SG_ID"
aws ec2 detach-internet-gateway --internet-gateway-id "$IGW_ID" --vpc-id "$VPC_ID"
aws ec2 delete-internet-gateway --internet-gateway-id "$IGW_ID"
aws ec2 delete-subnet --subnet-id "$SUBNET_ID"
aws ec2 delete-route-table --route-table-id "$RTB_ID"
aws ec2 delete-vpc --vpc-id "$VPC_ID"

rm -f "$STATE_FILE"
echo "All lab resources deleted."
