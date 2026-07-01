# Example parameter files

Replace the placeholder values, then deploy with:

```bash
aws cloudformation deploy \
  --template-file ../template.yaml \
  --stack-name infracost-aws-integration \
  --parameter-overrides file://member-account-minimal.json \
  --capabilities CAPABILITY_NAMED_IAM
```

- **`member-account-minimal.json`** — the smallest valid deployment: just the external ID,
  everything else defaulted off. Use this for any AWS account that isn't your Organizations
  management account.
- **`management-account-full.json`** — every optional feature enabled, for your Organizations
  management account. Fill in `OrganizationArn` and `TrustedServicePrincipals` per the
  commands in the main [README](../README.md#getting-organizationarn-and-trustedserviceprincipals).
