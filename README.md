# Infracost AWS Integration (CloudFormation)

A CloudFormation template to set up an AWS integration for Infracost Cloud, for
customers who standardize on CloudFormation or AWS Organizations StackSets
instead of Terraform. A Terraform module is also available:
[terraform-aws-integration](https://github.com/infracost/terraform-aws-integration).

See the [AWS Integration docs](https://www.infracost.io/docs/integrations/aws_integration/)
for more information.

## Quick start

Click a button below to launch the stack in the AWS Console with `IsManagementAccount`
pre-filled. You'll still need to paste in your **Infracost External ID** on the next screen —
see [Deploying with the AWS CLI](#deploying-with-the-aws-cli) below for where to find it. Deploy
to your **management account** first, then repeat with the member-account button for every other
account (or use [StackSets](#deploying-org-wide-with-stacksets) to roll it out to many member
accounts at once).

[![Launch Stack (Management Account)](https://s3.amazonaws.com/cloudformation-examples/cloudformation-launch-stack.png)](https://console.aws.amazon.com/cloudformation/home?region=us-east-1#/stacks/quickcreate?templateURL=https://infracost-public-templates.s3.us-east-2.amazonaws.com/cloudformation-aws-integration/latest/template.yaml&stackName=infracost-aws-integration&param_IsManagementAccount=true)
&nbsp;&nbsp;**Management account** (region locked to `us-east-1`, required for data exports)

[![Launch Stack (Member Account)](https://s3.amazonaws.com/cloudformation-examples/cloudformation-launch-stack.png)](https://console.aws.amazon.com/cloudformation/home?region=us-east-1#/stacks/quickcreate?templateURL=https://infracost-public-templates.s3.us-east-2.amazonaws.com/cloudformation-aws-integration/latest/template.yaml&stackName=infracost-aws-integration&param_IsManagementAccount=false)
&nbsp;&nbsp;**Member account** (you can switch region after launching — the role itself is global)

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

## Deploying org-wide with StackSets

If you want this role deployed to every account in your AWS Organization (rather than one
account at a time), deploy `template.yaml` as a
[CloudFormation StackSet](https://docs.aws.amazon.com/AWSCloudFormation/latest/UserGuide/what-is-cfnstacksets.html)
from your management account instead of a single stack. It's the same template — StackSets just
roll it out to a list of accounts/OUs and keep new accounts in sync automatically.

0. One-time setup: enable trusted access for StackSets, both at the Organizations level and the
   CloudFormation level (these are two separate flags — enabling one does not enable the other,
   and `create-stack-set` fails with `You must enable organizations access to operate a service
   managed stack set` until both are on):

   ```bash
   aws organizations enable-aws-service-access \
     --service-principal member.org.stacksets.cloudformation.amazonaws.com
   aws cloudformation activate-organizations-access
   ```

1. Create the StackSet with service-managed permissions (AWS creates the admin/execution roles
   for you):

   ```bash
   aws cloudformation create-stack-set \
     --stack-set-name infracost-aws-integration \
     --template-body file://template.yaml \
     --permission-model SERVICE_MANAGED \
     --auto-deployment Enabled=true,RetainStacksOnAccountRemoval=false \
     --capabilities CAPABILITY_NAMED_IAM \
     --parameters file://examples/stackset-member.json
   ```

2. Deploy stack instances to your member-account OU(s) using the same member parameters. Note
   that service-managed StackSets only accept **OU** targets, not an `--accounts` list, and this
   `create-stack-set`/`create-stack-instances` pair must run in `us-east-1` even if you never
   enable `EnableDataExports` — the template references `AWS::BCMDataExports::Export`, which
   StackSets validates against the target region's resource-type registry, and that type is only
   registered in `us-east-1`:

   ```bash
   aws cloudformation create-stack-instances \
     --stack-set-name infracost-aws-integration \
     --deployment-targets OrganizationalUnitIds=<your-ou-id> \
     --regions us-east-1
   ```

3. Deploy the management account **separately, as a normal stack** (not a StackSet instance).
   AWS's service-managed permission model can't target the organization's management account at
   all — a `create-stack-instances` call scoped to it "succeeds" but silently creates zero
   instances, so this isn't optional:

   ```bash
   aws cloudformation deploy \
     --template-file template.yaml \
     --stack-name infracost-aws-integration \
     --parameter-overrides file://examples/stackset-management.json \
     --capabilities CAPABILITY_NAMED_IAM \
     --region us-east-1
   ```

New accounts added to the target OU(s) later will automatically get the stack instance created
for them, since `auto-deployment` is enabled.

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

## Validating changes to this template

```bash
make lint      # cfn-lint
make security  # checkov, with documented suppressions in .checkov.yaml
make ci        # both of the above
```

Neither requires AWS credentials. See [CONTRIBUTING](scripts/validate.sh) for the additional
manual/local checks (`aws cloudformation validate-template`, a Rules/Conditions dry run via
`create-change-set`) that do require credentials and so aren't run in CI.

## Release process

Releases are automated from [Conventional Commits](https://www.conventionalcommits.org/)
using [release-please](https://github.com/googleapis/release-please): merging a PR whose
commits follow that convention opens (or updates) a release PR with an auto-generated
changelog; merging that PR cuts a semantically-versioned GitHub Release and git tag
(`vX.Y.Z`).

See the [Releases page](https://github.com/infracost/cloudformation-aws-integration/releases)
or [CHANGELOG.md](CHANGELOG.md) for what changed in each version. We recommend pinning to a
specific released version rather than tracking `main` directly, since `main` can contain
unreleased, in-progress changes.

## License

Apache 2.0, see [LICENSE](LICENSE).
