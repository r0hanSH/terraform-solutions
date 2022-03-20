terraform {
  required_providers {
    aws = {
      source = "hashicorp/aws"
    }
  }
}

provider "aws" {
  profile = "test"
  region  = "ap-south-1" # home region for multi-region trail
  default_tags {
    tags = {
      security = "rohan"
    }
  }
}

variable "accountId" {
  description = "Your AWS accountId"
}

variable "MFADeviceSerial" {
  description = "root user - MFA Device Serial Number"
}

variable "MFA_OTP" {
  description = "MFA OTP"
}


resource "aws_cloudtrail" "trail" {
  name                       = "SecurityTrail"
  s3_bucket_name             = aws_s3_bucket.bucket.id
  kms_key_id                 = aws_kms_key.trailKey.arn
  enable_log_file_validation = true
  is_multi_region_trail      = true
}

resource "aws_s3_bucket" "bucket" {
  bucket_prefix       = "cloudtrail-logs-"
  object_lock_enabled = true
}

resource "aws_s3_bucket_policy" "bucketPolicy" {
  bucket = aws_s3_bucket.bucket.id
  policy = <<POLICY
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Sid": "AWSCloudTrailAclCheck",
            "Effect": "Allow",
            "Principal": {
              "Service": "cloudtrail.amazonaws.com"
            },
            "Action": "s3:GetBucketAcl",
            "Resource": "arn:aws:s3:::${aws_s3_bucket.bucket.id}"
        },
        {
            "Sid": "AWSCloudTrailWrite",
            "Effect": "Allow",
            "Principal": {
              "Service": "cloudtrail.amazonaws.com"
            },
            "Action": "s3:PutObject",
            "Resource": "arn:aws:s3:::${aws_s3_bucket.bucket.id}/AWSLogs/*",
            "Condition": {
                "StringEquals": {
                    "s3:x-amz-acl": "bucket-owner-full-control"
                }
            }
        }
    ]
}
POLICY
}

resource "aws_s3_bucket_public_access_block" "publicBlock" {
  bucket                  = aws_s3_bucket.bucket.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_acl" "privateBucket" {
  bucket = aws_s3_bucket.bucket.id
  acl    = "private"
}

resource "aws_s3_bucket_versioning" "bucketVersioningAndMFA" {
  bucket = aws_s3_bucket.bucket.id
  versioning_configuration {
    status     = "Enabled"
    mfa_delete = "Enabled"
  }

  # format: "MFA_device_serial_number MFA_OTP_value"
  mfa = "${var.MFADeviceSerial} ${var.MFA_OTP}"

}

resource "aws_kms_key" "trailKey" {
  policy = <<POLICY
  {
    "Version": "2012-10-17",
    "Id": "Key policy created by CloudTrail",
    "Statement": [
        {
            "Sid": "Enable IAM User Permissions",
            "Effect": "Allow",
            "Principal": {
                "AWS": [
                    "arn:aws:iam::${var.accountId}:root"
                ]
            },
            "Action": "kms:*",
            "Resource": "*"
        },
        {
            "Sid": "Allow CloudTrail to encrypt logs",
            "Effect": "Allow",
            "Principal": {
                "Service": "cloudtrail.amazonaws.com"
            },
            "Action": "kms:GenerateDataKey*",
            "Resource": "*",
            "Condition": {
                "StringLike": {
                    "kms:EncryptionContext:aws:cloudtrail:arn": "arn:aws:cloudtrail:*:${var.accountId}:trail/*"
                }
            }
        },
        {
            "Sid": "Allow CloudTrail to describe key",
            "Effect": "Allow",
            "Principal": {
                "Service": "cloudtrail.amazonaws.com"
            },
            "Action": "kms:DescribeKey",
            "Resource": "*"
        },
        {
            "Sid": "Allow principals in the account to decrypt log files",
            "Effect": "Allow",
            "Principal": {
                "AWS": "*"
            },
            "Action": [
                "kms:Decrypt",
                "kms:ReEncryptFrom"
            ],
            "Resource": "*",
            "Condition": {
                "StringEquals": {
                    "kms:CallerAccount": "${var.accountId}"
                },
                "StringLike": {
                    "kms:EncryptionContext:aws:cloudtrail:arn": "arn:aws:cloudtrail:*:${var.accountId}:trail/*"
                }
            }
        },
        {
            "Sid": "Allow alias creation during setup",
            "Effect": "Allow",
            "Principal": {
                "AWS": "*"
            },
            "Action": "kms:CreateAlias",
            "Resource": "*",
            "Condition": {
                "StringEquals": {
                    "kms:CallerAccount": "${var.accountId}",
                    "kms:ViaService": "ec2.ap-south-1.amazonaws.com"
                }
            }
        },
        {
            "Sid": "Enable cross account log decryption",
            "Effect": "Allow",
            "Principal": {
                "AWS": "*"
            },
            "Action": [
                "kms:Decrypt",
                "kms:ReEncryptFrom"
            ],
            "Resource": "*",
            "Condition": {
                "StringEquals": {
                    "kms:CallerAccount": "${var.accountId}"
                },
                "StringLike": {
                    "kms:EncryptionContext:aws:cloudtrail:arn": "arn:aws:cloudtrail:*:${var.accountId}:trail/*"
                }
            }
        }
    ]
}
POLICY
}

resource "aws_kms_key" "KMSKey" {
}

resource "aws_s3_bucket_server_side_encryption_configuration" "SSE" {
  bucket = aws_s3_bucket.bucket.id
  rule {
    apply_server_side_encryption_by_default {
      kms_master_key_id = aws_kms_key.KMSKey.arn
      sse_algorithm     = "aws:kms"
    }
    bucket_key_enabled = true
  }
}

# bucket access logs enable
