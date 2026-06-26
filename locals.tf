locals {
  common_tags = merge(
    { ManagedBy = "terraform", Module = "terraform-aws-security-group" },
    var.tags
  )
}
