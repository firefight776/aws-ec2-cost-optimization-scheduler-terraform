variable "aws_region" {
  description = "AWS region for deployment"
  type        = string
  default     = "us-east-2"
}

variable "project_name" {
  description = "Project name prefix"
  type        = string
  default     = "ec2-cost-scheduler"
}

variable "tag_key_1" {
  type    = string
  default = "AutoSchedule"
}

variable "tag_value_1" {
  type    = string
  default = "true"
}

variable "tag_key_2" {
  type    = string
  default = "Environment"
}

variable "tag_value_2" {
  type    = string
  default = "dev"
}

variable "notification_email" {
  description = "Email address for SNS notifications"
  type        = string
}