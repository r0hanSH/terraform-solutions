terraform {
  required_providers {
    aws = {
      source = "hashicorp/aws"
    }
  }
}

provider "aws" {
  profile = "test"
  region  = "us-east-1"
  default_tags {
    tags = {
      security = "rohan"
    }
  }
}

variable "users" {
  default = ["rohan.1", "rohan.2"]
}


resource "aws_iam_policy" "MFA_restrictions" {
  name        = "MFA_restrictions"
  description = "Imposing MFA restrictions on our users"
  policy      = file("MFA-restriction-policy.json")
}

resource "aws_iam_user_policy_attachment" "policy_attach" {
  user       = var.users[count.index]
  count      = length(var.users)
  policy_arn = aws_iam_policy.MFA_restrictions.arn
}