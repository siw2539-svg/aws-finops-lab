#!/usr/bin/env bash
# create_budget.sh — monthly cost budget with email alerts at 80% actual and 100% forecast.
#
# Usage: ALERT_EMAIL=you@example.com LIMIT_USD=10 ./create_budget.sh

set -euo pipefail

ALERT_EMAIL="${ALERT_EMAIL:?set ALERT_EMAIL}"
LIMIT_USD="${LIMIT_USD:-10}"
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
DIR="$(cd "$(dirname "$0")/.." && pwd)"

budget=$(sed "s/__LIMIT__/$LIMIT_USD/" "$DIR/budget/budget.json")
notifications=$(sed "s/__EMAIL__/$ALERT_EMAIL/g" "$DIR/budget/notifications.json")

aws budgets create-budget \
  --account-id "$ACCOUNT_ID" \
  --budget "$budget" \
  --notifications-with-subscribers "$notifications"

echo "Budget 'finops-lab-monthly' created: \$$LIMIT_USD/month, alerts to $ALERT_EMAIL"
