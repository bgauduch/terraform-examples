# terraform-query-import

> **Type**: `lab`
> **Tags**: `aws` `query` `import` `tfquery` `v1.14`

Terraform **1.14** makes **search generally available**: `list` blocks in `.tfquery.hcl` files plus
the **`terraform query`** command let you **discover unmanaged infrastructure**, **generate its
configuration**, and **import it in bulk** - instead of writing `import` blocks and HCL by hand, one
resource at a time.

## The workflow

```
list block (.tfquery.hcl)  ->  terraform query  ->  -generate-config-out  ->  plan  ->  apply
   what to look for            what's out there       resource + import          review    bulk import
```

Each `list` block says which provider to use and how to filter. Stacking several blocks
**segments** the import - one fleet per block, grouped under `list.<type>.<label>`:

```hcl
list "aws_instance" "general" {
  provider = aws
  config {
    filter { name = "tag:demo"      values = ["clickops"] }
    filter { name = "instance-type" values = ["t3.micro"] }
  }
}

list "aws_instance" "compute" {
  provider = aws
  config {
    filter { name = "tag:demo"      values = ["clickops"] }
    filter { name = "instance-type" values = ["t3.small"] }
  }
}
```

## Layout

```
terraform-query-import/
├── bootstrap/                 # creates the "unmanaged" infra OUTSIDE Terraform (ClickOps)
│   ├── create-unmanaged.sh
│   └── destroy-unmanaged.sh
└── import/                    # the Terraform root module
    ├── providers.tf
    ├── variables.tf
    └── search.tfquery.hcl     # the list block(s); generated.tf lands here at demo time
```

`bootstrap/` has no `providers.tf` on purpose, so CI does not try to plan it.

## Prerequisites

- **Terraform `>= 1.14.0`** (pinned to `1.14.9` via `.terraform-version`; `terraform query` does not exist before 1.14).
- **AWS provider `6.41.0`** and the AWS CLI with valid credentials. Default region: `eu-west-1`.

## Run (live demo)

1. Create the unmanaged infrastructure (simulates someone clicking around the console):

   ```bash
   cd bootstrap
   ./create-unmanaged.sh          # 2 instances tagged demo=clickops: t3.micro (tier=general) + t3.small (tier=compute)
   ```

2. Discover it from the root module:

   ```bash
   cd ../import
   terraform init
   terraform query                # lists instances, grouped per list block (general / compute)
   ```

3. Generate configuration + `import` blocks for what was found:

   ```bash
   terraform query -generate-config-out=generated.tf
   # open generated.tf - it now holds resource blocks AND import blocks (with identities)
   ```

4. Review and fix the generated config. `-generate-config-out` emits **every** schema
   attribute and ignores the provider's `ConflictsWith` rules, so `plan` fails on mutually
   exclusive arguments. For `aws_instance` you must drop one side of each pair:

   ```bash
   terraform plan                 # FAILS: "Conflicting configuration arguments"
   ```

   In `generated.tf`, remove the `primary_network_interface {}` block (conflicts with
   `associate_public_ip_address`) and the `ipv6_addresses = []` line (conflicts with
   `ipv6_address_count`). Generation is a starting point, not plan-ready output.

5. Import in bulk:

   ```bash
   terraform plan                 # shows the imports, no resource changes
   terraform apply                # the instances are now managed by Terraform
   terraform plan                 # clean - nothing to change
   ```

6. Teardown - now that they are managed, let Terraform remove them:

   ```bash
   terraform destroy
   ```

   (If you stop before importing, run `../bootstrap/destroy-unmanaged.sh` instead.)

## Notes

- The generated `generated.tf` is git-ignored: it is a **live artifact** of the demo, regenerated
  each run. Always **review it** before applying - generation is a starting point, not a guarantee.
- `terraform validate` (CI) parses the root module's `.tf` files; the `.tfquery.hcl` is only loaded
  by the `query` command, so CI validates the example without any credentials.
- EC2 instances cost a few cents while running - run `terraform destroy` promptly after the demo.
