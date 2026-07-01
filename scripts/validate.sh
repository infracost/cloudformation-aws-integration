#!/usr/bin/env bash
# Local reproduction of the CI checks, plus the manual/AWS-credential-requiring checks that
# aren't run in CI (see README#validating-changes-to-this-template for why).
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."

echo "==> cfn-lint"
cfn-lint template.yaml
# Narrow region list: AWS::BCMDataExports::Export isn't registered in every region (see
# README#known-limitations) - us-east-2/eu-west-1/etc would fail here regardless of the
# template's correctness, so they're excluded from this check.
cfn-lint template.yaml --regions us-east-1 us-west-1 us-west-2 eu-west-2

echo "==> checkov"
checkov -f template.yaml --framework cloudformation --compact --config-file .checkov.yaml

if ! command -v aws >/dev/null 2>&1; then
  echo "==> aws CLI not found, skipping credentialed checks"
  exit 0
fi

if ! aws sts get-caller-identity >/dev/null 2>&1; then
  echo "==> no AWS credentials configured, skipping credentialed checks"
  echo "    (aws cloudformation validate-template, and the Rules/Conditions dry run below)"
  exit 0
fi

echo "==> aws cloudformation validate-template (shallow schema check only - does not evaluate Rules/Conditions)"
aws cloudformation validate-template --template-body file://template.yaml >/dev/null

echo "==> Rules/Conditions dry run via create-change-set (creates zero resources)"
echo "    This is the closest CloudFormation equivalent to 'terraform plan' for the Rules section."
echo "    Run manually against a sandbox account/parameters, e.g.:"
echo "    aws cloudformation create-change-set --stack-name infracost-test \\"
echo "      --template-body file://template.yaml --change-set-type CREATE \\"
echo "      --capabilities CAPABILITY_NAMED_IAM \\"
echo "      --parameters file://examples/member-account-minimal.json"
