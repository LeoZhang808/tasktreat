###############################################################################
# Remote state backend.
#
# The bucket and lock table are created once by `infra/terraform/bootstrap`.
# After running `terraform apply` in bootstrap, edit the `bucket` value below
# (or pass `-backend-config=...` to `terraform init`) so it matches the
# bucket name printed by the bootstrap stack:
#
#   tasktreat-tfstate-<aws-account-id>
#
# Then run, from this directory:
#   terraform init -reconfigure \
#     -backend-config="bucket=tasktreat-tfstate-<account-id>"
###############################################################################

terraform {
  backend "s3" {
    bucket         = "tasktreat-tfstate-066263929068"
    key            = "tasktreat/dev/terraform.tfstate"
    region         = "us-west-2"
    dynamodb_table = "tasktreat-tf-locks"
    encrypt        = true
  }
}
