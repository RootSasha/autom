variable "jenkins_password" {
  type        = string
  description = "Jenkins password"
  sensitive   = true
}

variable "github_token" {
  type        = string
  description = "GitHub token"
  sensitive   = true
}

variable "dockerhub_password" {
  type        = string
  description = "DockerHub password"
  sensitive   = true
}

variable "aws_access_key_id" {
  type        = string
  description = "AWS access key ID"
  sensitive   = true
}

variable "aws_secret_access_key" {
  type        = string
  description = "AWS secret access key"
  sensitive   = true
}

variable "github_email" {
  type        = string
  description = "Gmail"
  sensitive   = true
}

