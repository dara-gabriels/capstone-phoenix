output "terraform_ci_role_arn" {
  description = "Paste this into the infrastructure repo's AWS_TERRAFORM_ROLE_ARN secret"
  value       = aws_iam_role.terraform_ci.arn
}

output "github_oidc_provider_arn" {
  value = aws_iam_openid_connect_provider.github.arn
}
