terraform {
  backend "remote" {
    hostname     = "app.terraform.io"
    organization = "taxi-aymeric"

    workspaces {
      prefix = "network-"
    }
  }

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.11"
    }
  }
}

provider "aws" {
  region = "us-east-1"
}

provider "aws" {
  alias  = "us-east-1"
  region = "us-east-1"
}
