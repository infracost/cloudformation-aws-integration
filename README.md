# Infracost AWS Integration (CloudFormation)

A CloudFormation template to set up an AWS integration for Infracost Cloud, for
customers who standardize on CloudFormation or AWS Organizations StackSets
instead of Terraform. A Terraform module is also available:
[terraform-aws-integration](https://github.com/infracost/terraform-aws-integration).

See the [AWS Integration docs](https://www.infracost.io/docs/integrations/aws_integration/)
for more information.

> **Note:** this button assumes the template has been published to this
> repo's `main` branch on GitHub. If you're working from a local clone that
> hasn't been pushed yet, deploy with the AWS CLI instead (see below).

[![Launch Stack](https://s3.amazonaws.com/cloudformation-examples/cloudformation-launch-stack.png)](https://console.aws.amazon.com/cloudformation/home#/stacks/create/review?templateURL=https://raw.githubusercontent.com/infracost/cloudformation-aws-integration/main/template.yaml&stackName=infracost-aws-integration)

## What this creates

Always created:

- A cross-account IAM role (`infracost-readonly`) that Infracost Cloud assumes, scoped
  with an external ID condition.
- The AWS-managed `ViewOnlyAccess` policy, plus a small set of read-only actions
  it doesn't cover (tag-fetching APIs, a few EC2 describes).
- A role-introspection policy so Infracost can detect which features the role has access to.

Conditionally created:

| Feature | Parameter | Adds |
|---|---|---|
| Management-account access | `IsManagementAccount=true` | Cost Explorer, Pricing, Compute Optimizer, Cost Optimization Hub, Trusted Advisor read access |
| Extra S3 bucket access | `ExtraS3BucketArn1/2/3` | Read access to up to 3 buckets you already own (e.g. a CUR bucket) |
| BCM Data Exports + S3 Storage Lens | `EnableDataExports=true` | 2 S3 buckets, 2 BCM Data Exports (FOCUS 1.2 + Cost Optimization Hub), an S3 Storage Lens configuration |
| Cost Anomaly Detection | `EnableAnomalyMonitors=true` | A `SERVICE`-dimension Cost Anomaly Detection monitor |
| KMS encryption | `KmsKeyArn=<arn>` | SSE-KMS on the data-export buckets instead of the SSE-S3 default, plus a decrypt policy |

## Parameters

| Parameter | Required | Default | Notes |
|---|---|---|---|
| `InfracostExternalId` | Yes | — | Copy from the Infracost UI. |
| `InfracostAccountId` | No | `237144093413` | Infracost's AWS account ID. Don't change unless told to. |
| `IsManagementAccount` | No | `false` | `true` if this is your AWS Organizations management account. |
| `RoleSuffix` | No | `""` | Appended to all resource names; useful for deploying multiple test roles in one account. |
| `ExtraS3BucketArn1` / `2` / `3` | No | `""` | ARNs of extra buckets you want Infracost to read (e.g. a CUR bucket you already manage). Up to 3; contact Infracost if you need more. |
| `EnableDataExports` | No | `false` | Requires `IsManagementAccount=true`, `OrganizationArn`, and `TrustedServicePrincipals`. |
| `EnableAnomalyMonitors` | No | `false` | Requires `IsManagementAccount=true`. |
| `ExistingAnomalyMonitorArn` | No | `""` | ARN of an existing `SERVICE`-dimension Cost Anomaly Detection monitor, if your account already has one. See below. |
| `KmsKeyArn` | No | `""` | ARN (not alias) of a CMK for SSE-KMS on the export buckets. |
| `OrganizationArn` | Only with `EnableDataExports` | `""` | See below. |
| `TrustedServicePrincipals` | Only with `EnableDataExports` | `""` | See below. |

Stack creation fails fast (via the template's `Rules` section) if `EnableDataExports` or
`EnableAnomalyMonitors` is set without `IsManagementAccount`, or if `EnableDataExports` is
set without `OrganizationArn`/a valid `TrustedServicePrincipals` list — before any resource
is touched.

### Getting `OrganizationArn` and `TrustedServicePrincipals`

Terraform can read these live from AWS Organizations via a data source. CloudFormation has
no equivalent without a Lambda-backed custom resource — which we've deliberately avoided,
since it would require granting this stack's own deploy-time permissions
(`organizations:Describe*`/`List*`) that have nothing to do with the minimal, read-only role
this integration exists to create. Instead, run these two commands yourself and pass the
results as parameters:

```bash
aws organizations describe-organization --query 'Organization.Arn' --output text

aws organizations list-aws-service-access-for-organization \
  --query 'EnabledServicePrincipals[].ServicePrincipal' --output text
```

`TrustedServicePrincipals` must include `storage-lens.s3.amazonaws.com` — if it's missing,
enable [S3 Storage Lens trusted access](https://docs.aws.amazon.com/AmazonS3/latest/userguide/storage_lens_with_organizations_enabling_trusted_access.html)
for your organization first.

### Using an existing Cost Anomaly Detection monitor

AWS allows only one `SERVICE`-dimension, `DIMENSIONAL`-type Cost Anomaly Detection monitor per
account — many accounts already have one (for example, a `Default-Services-Monitor` created
via the Cost Explorer console). If yours does, setting `EnableAnomalyMonitors=true` without
`ExistingAnomalyMonitorArn` will fail with `HandlerErrorCode: AlreadyExists`. Check first:

```bash
aws ce get-anomaly-monitors --query \
  "AnomalyMonitors[?MonitorType=='DIMENSIONAL' && MonitorDimension=='SERVICE'].MonitorArn" \
  --output text
```

If that returns an ARN, pass it as `ExistingAnomalyMonitorArn` — the stack will use it as-is
instead of trying to create a new one. If it returns nothing, leave the parameter blank.

## Deploying with the AWS CLI

```bash
aws cloudformation deploy \
  --template-file template.yaml \
  --stack-name infracost-aws-integration \
  --parameter-overrides file://examples/member-account-minimal.json \
  --capabilities CAPABILITY_NAMED_IAM
```

See [`examples/`](examples/) for parameter-override files covering a minimal member-account
setup and a full management-account setup with every feature enabled.

## Known limitations

- **BCM Data Exports is a us-east-1-only service.** AWS Data Exports has exactly one service
  endpoint, in `us-east-1` (see [AWS Billing and Cost Management endpoints and
  quotas](https://docs.aws.amazon.com/general/latest/gr/billing.html#billing-data-export)) —
  this isn't a CloudFormation registration gap, it's a property of the underlying service, and
  it applies equally to the Terraform module. Deploy this stack with `EnableDataExports=true`
  in `us-east-1`; the template's `Rules` section fails fast if you don't. The exported
  cost/usage data itself still covers every AWS region in your account — this only restricts
  where the Export resources themselves can be created.
- **The BCM Data Exports service-linked role may already exist.** If your account has
  previously used BCM Data Exports (via this stack, the console, or another tool), stack
  creation can fail on `BcmDataExportsServiceLinkedRole` with an already-exists error —
  CloudFormation's `AWS::IAM::ServiceLinkedRole` resource is stricter about this than the AWS
  CLI. If you hit this, delete the failed stack, temporarily comment out that resource block,
  and redeploy — the export resources will attach to the existing service-linked role. The
  role is a shared thing AWS manages, not something a stack should ever delete, which is why
  it's created with `DeletionPolicy: Retain`.
- **Extra S3 bucket access is capped at 3 buckets** (`ExtraS3BucketArn1/2/3`), unlike the
  Terraform module's open-ended list. CloudFormation has no clean way to map a `/*` object-ARN
  suffix over an arbitrary-length parameter list, so this template uses a small number of
  fixed, independently-optional parameters instead. Contact Infracost if 3 isn't enough.
- **`s3:HeadObject`**, present in the Terraform module's S3 access policy, is omitted here —
  it isn't a real IAM action (the S3 `HeadObject` API is authorized by `s3:GetObject`), and
  `cfn-lint` flags it. This is a no-op removal, not a permissions change.

## Validating changes to this template

```bash
make lint      # cfn-lint
make security  # checkov, with documented suppressions in .checkov.yaml
make ci        # both of the above
```

Neither requires AWS credentials. See [CONTRIBUTING](scripts/validate.sh) for the additional
manual/local checks (`aws cloudformation validate-template`, a Rules/Conditions dry run via
`create-change-set`) that do require credentials and so aren't run in CI.

## License

Apache 2.0, see [LICENSE](LICENSE).
