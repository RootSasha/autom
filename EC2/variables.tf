variable "key_name" {
  description = "Ім'я вашого ключа SSH"
  type        = string
  default     = "key" # Замініть на ваш ключ
}

variable "ami_owner" {
  description = "Власник AMI Ubuntu"
  type        = list(string)
  default     = ["099720109477"]
}

variable "instance_type" {
  description = "Тип інстансу EC2"
  type        = string
  default     = "t3.medium"
}

variable "volume_size" {
  description = "Розмір EBS тому в ГБ"
  type        = number
  default     = 50
}