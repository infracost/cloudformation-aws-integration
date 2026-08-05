# Changelog

All notable changes to this project will be documented in this file. The format is based on
[Keep a Changelog](https://keepachangelog.com/en/1.0.0/).

This repo has its own release cadence, independent of
[terraform-aws-integration](https://github.com/infracost/terraform-aws-integration)'s module
version — don't compare the two version numbers directly.

## [0.1.0] - Unreleased

### Added

- Initial release: cross-account read-only IAM role, management/member account policies,
  role introspection policy, optional KMS decrypt policy, optional extra S3 bucket access
  (capped at 3 buckets, see README), optional BCM Data Exports (FOCUS 1.2 + Cost
  Optimization Hub) and S3 Storage Lens provisioning, optional Cost Anomaly Detection monitor.

### Changed from the Terraform module

- `OrganizationArn` and `TrustedServicePrincipals` are now explicit parameters instead of
  being read live via a Terraform data source — see the README for why.
- `s3:HeadObject` was dropped from the S3 read-only policy; it isn't a real IAM action.

### Fixed

- Added a `Rules` check (`DataExportsRequiresUsEast1Region`) that fails fast unless
  `EnableDataExports=true` is deployed in `us-east-1`. AWS Data Exports has exactly one
  service endpoint, in `us-east-1` — the README previously and incorrectly listed
  `us-west-1`/`us-west-2`/`eu-west-2`/`me-south-1` as also "confirmed" supported, based on
  `cfn-lint`'s multi-region resource-schema check rather than actual service availability.
  That misleading CI check has been removed along with the corrected README claim.
- Added an `ExistingAnomalyMonitorArn` parameter. AWS allows only one `SERVICE`-dimension
  Cost Anomaly Detection monitor per account, so `EnableAnomalyMonitors=true` previously
  failed with `HandlerErrorCode: AlreadyExists` on any account that already had one (common,
  since many accounts get a `Default-Services-Monitor` via the Cost Explorer console).
  `CostAnomalyServicesMonitor` now only gets created when no existing ARN is supplied; found
  via a live test deploy against a real AWS Organization. This affects the Terraform module
  too — worth a matching fix there.
- Removed the empty-string `Prefix` from `S3StorageLensConfig`'s `S3BucketDestination`.
  `AWS::S3::StorageLens` sent it through to the underlying `PutStorageLensConfiguration` API
  as a literal empty XML element, which the service rejects with `MalformedXML` — confirmed
  by reproducing the identical error via a direct `aws s3control put-storage-lens-configuration`
  call and bisecting the request body field-by-field. `Prefix` is optional and omitting it
  is behaviorally identical to an empty one, so this is a pure fix with no behavior change.
  Found via the same live test deploy; `S3Prefix` on the two `AWS::BCMDataExports::Export`
  resources is unaffected — that field is required there (a different resource type, and
  apparently not hit by the same bug), so those keep their empty-string value.
