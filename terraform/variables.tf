variable "instance_type" {
  default = {
    t2_micro = "t2.micro"
    t2_medium = "t2.medium"
    t3_medium = "t3.medium"
    t3_large = "t3.large"
  }
}

variable "sgr_rules" {
  default = {
    ports_in = [
      80,
      22,
      8080
    ]
  }
}

variable "keypair" {
  default = "ec2-keypair"
}