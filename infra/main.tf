terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = "us-east-1"
}

data "aws_caller_identity" "current" {}

# 1. BUCKET DE LOGS Y AUDITORIA (100% Privado + Cifrado AES256)
resource "aws_s3_bucket" "audit_logs" {
  bucket        = "techverde-audit-logs-${data.aws_caller_identity.current.account_id}"
  force_destroy = true
}

resource "aws_s3_bucket_server_side_encryption_configuration" "audit_logs_enc" {
  bucket = aws_s3_bucket.audit_logs.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "audit_logs_block" {
  bucket                  = aws_s3_bucket.audit_logs.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_ownership_controls" "audit_logs_ownership" {
  bucket = aws_s3_bucket.audit_logs.id
  rule {
    object_ownership = "BucketOwnerEnforced"
  }
}

resource "aws_s3_bucket_policy" "audit_logs_policy" {
  bucket     = aws_s3_bucket.audit_logs.id
  depends_on = [aws_s3_bucket_public_access_block.audit_logs_block]

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "AWSCloudTrailAclCheck"
        Effect    = "Allow"
        Principal = { Service = "cloudtrail.amazonaws.com" }
        Action    = "s3:GetBucketAcl"
        Resource  = aws_s3_bucket.audit_logs.arn
      },
      {
        Sid       = "AWSCloudTrailWrite"
        Effect    = "Allow"
        Principal = { Service = "cloudtrail.amazonaws.com" }
        Action    = "s3:PutObject"
        Resource  = "${aws_s3_bucket.audit_logs.arn}/AWSLogs/${data.aws_caller_identity.current.account_id}/*"
        Condition = {
          StringEquals = { "s3:x-amz-acl" = "bucket-owner-full-control" }
        }
      },
      {
        Sid       = "S3ServerAccessLogsPolicy"
        Effect    = "Allow"
        Principal = { Service = "logging.s3.amazonaws.com" }
        Action    = "s3:PutObject"
        Resource  = "${aws_s3_bucket.audit_logs.arn}/s3-access-logs/*"
        Condition = {
          StringEquals = { "aws:SourceAccount" = data.aws_caller_identity.current.account_id }
        }
      }
    ]
  })
}

# 2. BUCKET WEB ESTATICO (Solo lectura publica + Versionado + Cifrado + Logs)
resource "aws_s3_bucket" "web_hosting" {
  bucket        = "techverde-web-${data.aws_caller_identity.current.account_id}"
  force_destroy = true
}

resource "aws_s3_bucket_website_configuration" "web_config" {
  bucket = aws_s3_bucket.web_hosting.id
  index_document { suffix = "index.html" }
  error_document { key = "error.html" }
}

resource "aws_s3_bucket_versioning" "web_versioning" {
  bucket = aws_s3_bucket.web_hosting.id
  versioning_configuration { status = "Enabled" }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "web_enc" {
  bucket = aws_s3_bucket.web_hosting.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_logging" "web_logging" {
  bucket        = aws_s3_bucket.web_hosting.id
  target_bucket = aws_s3_bucket.audit_logs.id
  target_prefix = "s3-access-logs/"
  depends_on    = [aws_s3_bucket_policy.audit_logs_policy]
}

resource "aws_s3_bucket_metric" "web_metrics" {
  bucket = aws_s3_bucket.web_hosting.id
  name   = "EntireBucketMetrics"
}

resource "aws_s3_bucket_public_access_block" "web_block" {
  bucket                  = aws_s3_bucket.web_hosting.id
  block_public_acls       = true
  ignore_public_acls      = true
  block_public_policy     = false
  restrict_public_buckets = false
}

resource "aws_s3_bucket_policy" "web_policy" {
  bucket     = aws_s3_bucket.web_hosting.id
  depends_on = [aws_s3_bucket_public_access_block.web_block]

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "PublicReadOnlyGetObject"
        Effect    = "Allow"
        Principal = "*"
        Action    = "s3:GetObject"
        Resource  = "${aws_s3_bucket.web_hosting.arn}/*"
      }
    ]
  })
}

# 3. TRAZABILIDAD DE CUENTA (AWS CloudTrail)
resource "aws_cloudtrail" "account_trail" {
  name                          = "techverde-security-trail"
  s3_bucket_name                = aws_s3_bucket.audit_logs.id
  include_global_service_events = true
  is_multi_region_trail         = false
  depends_on                    = [aws_s3_bucket_policy.audit_logs_policy]
}

# 4. ALARMA TEMPRANA DE INCIDENTES (Amazon CloudWatch)
resource "aws_cloudwatch_metric_alarm" "http_4xx_alarm" {
  alarm_name          = "TechVerde-High-4xx-Errors"
  alarm_description   = "Alerta temprana cuando se detectan 3 o mas errores HTTP 4xx en 5 minutos"
  namespace           = "AWS/S3"
  metric_name         = "4xxErrors"
  statistic           = "Sum"
  period              = 300
  evaluation_periods  = 1
  threshold           = 3
  comparison_operator = "GreaterThanOrEqualToThreshold"
  treat_missing_data  = "notBreaching"

  dimensions = {
    BucketName = aws_s3_bucket.web_hosting.id
    FilterId   = "EntireBucketMetrics"
  }
}

output "website_url" {
  value = "http://${aws_s3_bucket_website_configuration.web_config.website_endpoint}"
}

output "web_bucket_name" {
  value = aws_s3_bucket.web_hosting.id
}

output "logs_bucket_name" {
  value = aws_s3_bucket.audit_logs.id
}
