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

For a [StackSet deployment](../README.md#deploying-org-wide-with-stacksets) (rolling this out to
every account in your Organization at once), use these instead:

- **`stackset-member.json`** — for the StackSet's member-account OU, via
  `aws cloudformation create-stack-instances --deployment-targets OrganizationalUnitIds=...
  --parameters file://stackset-member.json` (`IsManagementAccount` explicitly `false`).
- **`stackset-management.json`** — for the management account, which service-managed StackSets
  can't target at all, so this is deployed as an ordinary `aws cloudformation deploy` stack
  alongside the StackSet rather than a stack instance within it (`IsManagementAccount` set to
  `true`).
