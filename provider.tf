terraform {
  required_providers {
    http = {
      source = "hashicorp/http"
      version = "3.5.0"
    }
    aws = {
      source = "hashicorp/aws"
      version = "6.27.0"
    }
  }
}
provider "aws" {
  region = "us-nort-1"
}
