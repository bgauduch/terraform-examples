# Repo lessons

Durable lessons learned while working in this repository. Append new entries; keep them short and actionable.

## Security hardening

- **KMS rotation (`AWS-0065`)** - `trivy config` flags `aws_kms_key` without `enable_key_rotation = true`. Always enable rotation on customer-managed keys; pair it with a deliberately short `deletion_window_in_days` (AWS minimum is 7) only in throwaway demos, with a comment explaining why.
- **S3 versioning (`AWS-0090`)** - an encrypted, private bucket still trips the scanner without an `aws_s3_bucket_versioning` resource set to `Enabled`. Versioning is a separate resource, not an inline block on `aws_s3_bucket`.
- **Variable validation** - mark required inputs `nullable = false` and add a `validation {}` block (region regex, `cidrhost()` for CIDRs, `contains()` allow-lists for enums). Failures then surface at plan time with a clear message instead of as opaque provider errors at apply.
- **Documented exceptions** - low-value scanner findings that would bloat a teaching example (S3 access logging `AWS-0089`, VPC flow logs `AWS-0178`) are documented in the example README rather than silenced with inline ignores.
