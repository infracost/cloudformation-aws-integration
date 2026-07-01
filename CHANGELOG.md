# Changelog

All notable changes to this project will be documented in this file. The format is based on
[Keep a Changelog](https://keepachangelog.com/en/1.0.0/).

This repo has its own release cadence, independent of
[terraform-aws-integration](https://github.com/infracost/terraform-aws-integration)'s module
version — don't compare the two version numbers directly.

## [0.1.0] - Unreleased

### Added

- Initial CloudFormation port of `terraform-aws-integration` v0.3.1: cross-account read-only
  IAM role, management/member account policies, role introspection policy, optional KMS
  decrypt policy, optional extra S3 bucket access (capped at 3 buckets, see README), optional
  BCM Data Exports (FOCUS 1.2 + Cost Optimization Hub) and S3 Storage Lens provisioning,
  optional Cost Anomaly Detection monitor.

### Changed from the Terraform module

- `OrganizationArn` and `TrustedServicePrincipals` are now explicit parameters instead of
  being read live via a Terraform data source — see the README for why.
- `s3:HeadObject` was dropped from the S3 read-only policy; it isn't a real IAM action.
