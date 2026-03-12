terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
    linode = { 
      source = "linode/linode" 
      version = "3.9.0"
    }  
  }
}

