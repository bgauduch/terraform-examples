# Changelog

## [2.1.0](https://github.com/bgauduch/terraform-examples/compare/v2.0.0...v2.1.0) (2026-06-14)


### Features

* **harden:** enable KMS rotation, S3 versioning and input validation ([#20](https://github.com/bgauduch/terraform-examples/issues/20)) ([02601ab](https://github.com/bgauduch/terraform-examples/commit/02601ab6c9f4f29ca13c177e4bfecf33600492f4)), closes [#16](https://github.com/bgauduch/terraform-examples/issues/16)


### CI

* **trivy:** single-scan with convert-driven report and gate ([#21](https://github.com/bgauduch/terraform-examples/issues/21)) ([e3a7ad0](https://github.com/bgauduch/terraform-examples/commit/e3a7ad0e41c87d4534c706764dc2f50c0b14a588)), closes [#17](https://github.com/bgauduch/terraform-examples/issues/17)

## [2.0.0](https://github.com/bgauduch/terraform-examples/compare/v1.0.1...v2.0.0) (2026-06-11)


### ⚠ BREAKING CHANGES

* restructure into a Terraform examples library ([#10](https://github.com/bgauduch/terraform-examples/issues/10))

### Features

* **deferred-actions:** implement KMS + S3 deferral example ([#12](https://github.com/bgauduch/terraform-examples/issues/12)) ([2c381ae](https://github.com/bgauduch/terraform-examples/commit/2c381ae0c6b5ea024feaecf2103a82ad31cfee33))


### Refactoring

* restructure into a Terraform examples library ([#10](https://github.com/bgauduch/terraform-examples/issues/10)) ([d706419](https://github.com/bgauduch/terraform-examples/commit/d706419ac01887df734fac91fdac9173f9bcf5c5))


### Documentation

* **deferred-actions:** correct that -allow-deferral is required ([#13](https://github.com/bgauduch/terraform-examples/issues/13)) ([ea93ffd](https://github.com/bgauduch/terraform-examples/commit/ea93ffd5178887f7b98b9b4df1470996d66c3ff7))


### CI

* **commitlint:** skip per-commit lint on bot branches ([#14](https://github.com/bgauduch/terraform-examples/issues/14)) ([95e6ca9](https://github.com/bgauduch/terraform-examples/commit/95e6ca9651ae9be5cf857be8876dcae7bdfafb0d))

## [1.0.1](https://github.com/bgauduch/demo-terraform-multi-env-aws/compare/v1.0.0...v1.0.1) (2026-04-20)


### Documentation

* **readme:** fix CI badge after workflow split ([#4](https://github.com/bgauduch/demo-terraform-multi-env-aws/issues/4)) ([4f5fc59](https://github.com/bgauduch/demo-terraform-multi-env-aws/commit/4f5fc599d2b66560756e7775fd1912954dcaabc0))

## 1.0.0 (2026-04-20)


### Features

* init repo with multi-env demos ([42a61bc](https://github.com/bgauduch/demo-terraform-multi-env-aws/commit/42a61bc72254efaad6d5a4a3253243ab1b59cb8a))


### Bug Fixes

* update default region to eu-west-1 ([9269dcc](https://github.com/bgauduch/demo-terraform-multi-env-aws/commit/9269dcc4b31f7ff5d2247be7f3adfdbc6a2a9aa5))


### Documentation

* **readme:** add production disclaimer and surface prerequisites ([350964c](https://github.com/bgauduch/demo-terraform-multi-env-aws/commit/350964ce9b42765d6046de9c87f59f5d1a77a290))
* **terraform:** clarify partial backend config comment ([0201871](https://github.com/bgauduch/demo-terraform-multi-env-aws/commit/020187122beca66621c16077fa2e0ee3e7546512))
* update readme in english ([6ed21ca](https://github.com/bgauduch/demo-terraform-multi-env-aws/commit/6ed21ca18e7b6bc920c2845deaed943d18b39592))


### CI

* add quality gate and release automation ([faa4110](https://github.com/bgauduch/demo-terraform-multi-env-aws/commit/faa4110d27b52b58605e364563becdd01c0f4a2d))
