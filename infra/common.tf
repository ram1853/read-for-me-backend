data "aws_caller_identity" "current" {}
data "aws_region" "current" {}
data "aws_partition" "current" {}

data "aws_iam_policy_document" "assume_role_lambda" {
    statement {
      effect = "Allow"

      principals {
        type        = "Service"
        identifiers = ["lambda.amazonaws.com"]
      }

      actions = ["sts:AssumeRole"]
    }
}

data "aws_iam_policy_document" "assume_role_state_machine" {
    statement {
      effect = "Allow"

      principals {
        type        = "Service"
        identifiers = ["states.amazonaws.com"]
      }

      actions = ["sts:AssumeRole"]
    }
}

data "aws_iam_policy_document" "assume_role_events" {
    statement {
      effect = "Allow"

      principals {
        type        = "Service"
        identifiers = ["events.amazonaws.com"]
      }

      actions = ["sts:AssumeRole"]
    }
}

variable "s3-bucket-name" {
  type = string
  default = "read-for-me"
}

variable "function_name_text_extractor" {
  type    = string
  default = "text-extractor"
}

variable "function_name_upload_url_generator" {
  type    = string
  default = "upload-url-generator"
}

variable "function_name_download_url_generator" {
  type    = string
  default = "download-url-generator"
}

variable "function_name_language_detector" {
  type    = string
  default = "language-detector"
}

variable "function_name_text_translator" {
  type    = string
  default = "text-translator"
}

variable "function_name_audio_generator" {
  type = string
  default = "audio-generator"
}