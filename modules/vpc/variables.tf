variable "vpc_parameters" {
  description = "VPC parameters"
  type = map(object({
    cidr_block           = string
    enable_dns_support   = optional(bool, true)
    enable_dns_hostnames = optional(bool, true)
    tags                 = optional(map(string), {})
  }))
  default = {
    "main-vpc" = {
      cidr_block           = "10.0.0.0/16"
      enable_dns_support   = true
      enable_dns_hostnames = true
      tags = {
        "Environment" = "dev"
      }
    }
  }
}

variable "subnet_parameters" {
  description = "Subnet parameters"
  type = map(object({
    cidr_block = string
    vpc_name   = string
    tags       = optional(map(string), {})
  }))
  default = {
    "public-subnet-1" = {
      vpc_name   = "main-vpc"
      cidr_block = "10.0.1.0/24"
      tags = {
        "Type" = "public"
      }
    },
    "private-subnet-1" = {
      vpc_name   = "main-vpc"
      cidr_block = "10.0.2.0/24"
      tags = {
        "Type" = "private"
      }
    }
  }
}

variable "igw_parameters" {
  description = "IGW parameters"
  type = map(object({
    vpc_name = string
    tags     = optional(map(string), {})
  }))
  default = {
    "main-igw" = {
      vpc_name = "main-vpc"
      tags = {
        "Purpose" = "internet-access"
      }
    }
  }
}

variable "rt_parameters" {
  description = "RT parameters"
  type = map(object({
    vpc_name = string
    tags     = optional(map(string), {})
    routes = optional(list(object({
      cidr_block = string
      use_igw    = optional(bool, true)
      gateway_id = string
    })), [])
  }))
  default = {
    "public-rt" = {
      vpc_name = "main-vpc"
      tags = {
        "Access" = "public"
      }
      routes = [
        {
          cidr_block = "0.0.0.0/0"
          use_igw    = true
          gateway_id = "main-igw"
        }
      ]
    }
  }
}

variable "rt_association_parameters" {
  description = "RT association parameters"
  type = map(object({
    subnet_name = string
    rt_name     = string
  }))
  default = {
    "public-association" = {
      subnet_name = "public-subnet-1"
      rt_name     = "public-rt"
    }
  }
}

