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

variable "bucketName" {
  type        = string
  description = "DNS compliant S3 bucket name e.g. test.example.com"
}

variable "MFADeviceSerial" {
  description = "root user - MFA Device Serial Number"
}

variable "MFA_OTP" {
  description = "MFA OTP"
}


resource "aws_s3_bucket" "bucket" {
  bucket = var.bucketName
  object_lock_enabled = true
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

#variable "targetBucket" {
#	description = "Target Bucket where you want to store S3 bucket access logs"
#}

#resource "aws_s3_bucket_logging" "loggingBucket" {
#	bucket = aws_s3_bucket.bucket.id
#	target_bucket = var.targetBucket
#	target_prefix = "logs/${var.bucketName}"
#}

# Bucket Notifications and Lifecycle Configuration - Not required for my use-case
# to-do: add aws:SecureTransport in bucket policy
