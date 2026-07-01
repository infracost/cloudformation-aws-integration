.PHONY: lint security validate ci

lint:
	cfn-lint template.yaml
	# Region list is deliberately narrow: AWS::BCMDataExports::Export is only registered in a
	# handful of regions (see README#known-limitations). us-east-2/eu-west-1/etc are excluded
	# here because they'd fail on that alone, not because of anything wrong with the template.
	cfn-lint template.yaml --regions us-east-1 us-west-1 us-west-2 eu-west-2

security:
	checkov -f template.yaml --framework cloudformation --compact --config-file .checkov.yaml

validate:
	@echo "Requires AWS credentials - not run in CI. See scripts/validate.sh for details."
	aws cloudformation validate-template --template-body file://template.yaml

ci: lint security
