.PHONY: lint security validate ci

lint:
	cfn-lint template.yaml

security:
	checkov -f template.yaml --framework cloudformation --compact --config-file .checkov.yaml

validate:
	@echo "Requires AWS credentials - not run in CI. See scripts/validate.sh for details."
	aws cloudformation validate-template --template-body file://template.yaml

ci: lint security
