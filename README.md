# Terraform Modules - VPC and S3 Bucket with Backend Storage

The aim for this project is to use Terraform to create modularized configurations for building an Amazon Virtual Private Cloud (VPC) and an Amazon bucket. I also configured terraform to use amazon s3 as the backend storage for storing the Terraform state.

Directory: ![git](./img/1%20git.jpg)

## First Step

The first thing I did was create the module directory for:

- VPC Configuration
- S3 Configuration

### VPC Configuration, Variables and Output File

I created a list of variables that I wanted to use in my vpc configuration. The variables I created are flexible. They can handle multiple vpcs or a single vpc. The variables I created include variables for:

- VPC Parameters - containing vpc information
- subnet parameters - public and private
- Internet Gateway parameters
- Route Table parameters
- Route Table Association parameters

See below:

```
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

```

I then proceeded to configure my main.tf file for my vpc, specifying information on the following:

- AWS VPC
- AWS SUBNET
- AWS INTERNET GATEWAY
- AWS ROUTE TABLE
- AWS ROUTE TABLE ASSOCIATION

See below:

```
resource "aws_vpc" "darey-vpc" {
  for_each             = var.vpc_parameters
  cidr_block           = each.value.cidr_block
  enable_dns_support   = each.value.enable_dns_support
  enable_dns_hostnames = each.value.enable_dns_hostnames
  tags = merge(each.value.tags, {
    Name : each.key
  })
}

resource "aws_subnet" "darey-subnet" {
  for_each   = var.subnet_parameters
  vpc_id     = aws_vpc.darey-vpc[each.value.vpc_name].id
  cidr_block = each.value.cidr_block
  tags = merge(each.value.tags, {
    Name : each.key
  })
}

resource "aws_internet_gateway" "darey-igw" {
  for_each = var.igw_parameters
  vpc_id   = aws_vpc.darey-vpc[each.value.vpc_name].id
  tags = merge(each.value.tags, {
    Name : each.key
  })
}

resource "aws_route_table" "darey-rt" {
  for_each = var.rt_parameters
  vpc_id   = aws_vpc.darey-vpc[each.value.vpc_name].id
  tags = merge(each.value.tags, {
    Name : each.key
  })

  dynamic "route" {
    for_each = each.value.routes
    content {
      cidr_block = route.value.cidr_block
      gateway_id = route.value.use_igw ? aws_internet_gateway.darey-igw[route.value.gateway_id].id : route.value.gateway_id
    }
  }
}

resource "aws_route_table_association" "darey-rta" {
  for_each       = var.rt_association_parameters
  subnet_id      = aws_subnet.darey-subnet[each.value.subnet_name].id
  route_table_id = aws_route_table.darey-rt[each.value.rt_name].id
}
```

Next, I worked on the configuration for the output.tf file. See below:

```
output "vpcs" {
  description = "VPC Outputs"
  value       = { for vpc in aws_vpc.darey-vpc : vpc.tags.Name => { "cidr_block" : vpc.cidr_block, "id" : vpc.id } }
}
```

This output exposes information after terraform runs. The for loop loops over all vpcs created(aws_vpc.darey-vpc) and builds a map where:

- The key is the VPC's Name tag (e.g., "my-vpc")
- The value is a map with the vpcs cidr_block and id.

### Amazon S3 Configuration

S3 would enable me store my state file object. To do this successfully, you need to also lock the state file so that only one person has access to change the terraform state at a time. To do this you need DynamoDB.
Next, I worked on the s3 module configuration by creating the configuration for the following:

1. s3 bucket config
2. s3 bucket versioning config
3. s3 bucket encryption config
4. s3 bucket public access block
5. AWS DynamoDB Table with lock enabled

See below:

```
resource "aws_s3_bucket" "darey-s3" {
  bucket = "darey-s3"

  # Prevent accidental deletion of this s3 bucket
  lifecycle {
    prevent_destroy = false
  }
}

# Enable versioning so you can see the full revision history of your
# state files

resource "aws_s3_bucket_versioning" "enabled" {
  bucket = aws_s3_bucket.darey-s3.id
  versioning_configuration {
    status = "Enabled"
  }
}

# Enable server-side encryption by default
resource "aws_s3_bucket_server_side_encryption_configuration" "default" {
  bucket = aws_s3_bucket.darey-s3.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# Explicitly block all public access to the s3 bucket
resource "aws_s3_bucket_public_access_block" "public_access" {
  bucket = aws_s3_bucket.darey-s3.id
  block_public_acls = true
  block_public_policy = true
  ignore_public_acls = true
  restrict_public_buckets = true
}

# Create DynamoDB table for locking

resource "aws_dynamodb_table" "terraform_locks" {
  name = "darey-locks"
  billing_mode = "PAY_PER_REQUEST"
  hash_key = "LockID"

  attribute {
    name = "LockID"
    type = "S"
  }
}
```

Before storing the state file on the cloud, you need to first store it in your local environment. To do this, cd out to your main folder (out of the module directories). I then created a new main.tf file in my root directory to call the configurations from my modules.

See below:

```
provider "aws" {
  region = "us-east-1"
}



module "vpc" {
  source = "./modules/vpc"
}

module "s3_bucket" {
  source = "./modules/s3"
}
```

After putting in my provider and module configuration for vpc and s3 bucket in my main.tf directory in my root directory, I ran `terraform init` and `terraform plan` to create the state file locally and see the plan for my terraform configuration. Then I ran `terraform apply`. 

After my configuration was set up (s3 bucket created successfully and VPCs), I proceeded to complete the final step of moving it to the cloud. To do this, I added the following configuration:

```
terraform {
  backend "s3" {
    bucket = "darey-s3"
    key = "terraform.tfstate"
    region = "us-east-1"
    encrypt = true
    dynamodb_table = "darey-locks"

  }
}
```

This moves the state file to the cloud.

