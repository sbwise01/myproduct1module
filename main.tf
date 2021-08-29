locals {
  service_account_roles = [
    "service1",
    "service2",
    "service3"
  ]
}

data "aws_iam_policy_document" "service-account-eks-assume-role" {
  for_each = toset(local.service_account_roles)

  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]
    principals {
      type        = "Federated"
      identifiers = [var.eks_oidc_provider_arn]
    }
    condition {
      test     = "StringEquals"
      variable = "${replace(var.eks_oidc_provider_arn, "/arn:aws:iam::[0-9]{12}:oidc-provider\\//", "")}:sub"
      values   = ["system:serviceaccount:default:${each.value}"]
    }
  }
}

resource "aws_iam_role" "service_account_role" {
  for_each = toset(local.service_account_roles)

  name               = each.key
  assume_role_policy = data.aws_iam_policy_document.service-account-eks-assume-role[each.key].json
}

resource "kubernetes_service_account" "service_accounts" {
  for_each = toset(local.service_account_roles)

  automount_service_account_token = true
  metadata {
    namespace = "default"
    name      = each.key
    annotations = {
      "eks.amazonaws.com/role-arn" = aws_iam_role.service_account_role[each.key].arn
    }
  }
}
