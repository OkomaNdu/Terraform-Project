<div align="center">

# Terraform · AWS EC2 Deployment

**Provision a complete AWS network infrastructure and deploy a Dockerised Nginx server — fully automated with Terraform.**

![Terraform](https://img.shields.io/badge/Terraform-%3E%3D1.0-7B42BC?style=flat-square&logo=terraform)
![AWS](https://img.shields.io/badge/AWS-ca--central--1-FF9900?style=flat-square&logo=amazonaws)
![Docker](https://img.shields.io/badge/Docker-Nginx-2496ED?style=flat-square&logo=docker)
![License](https://img.shields.io/badge/License-MIT-green?style=flat-square)

</div>

---

## Table of Contents

- [Overview](#overview)
- [Architecture](#architecture)
- [Project Structure](#project-structure)
- [Prerequisites](#prerequisites)
- [Configuration](#configuration)
- [Getting Started](#getting-started)
- [Outputs](#outputs)
- [Accessing Nginx](#accessing-nginx)
- [Security Notes](#security-notes)

---

## Overview

This project is a practical Terraform demo that builds AWS cloud infrastructure from the ground up — no manual console clicks required. It covers the full lifecycle from networking to a live web server:

| Stage | What Was Built |
|---|---|
| **Networking** | Custom VPC, public subnet, Internet Gateway |
| **Routing** | Default Route Table configured for public internet access |
| **Security** | Default Security Group with locked-down SSH and open HTTP |
| **Compute** | EC2 instance (Amazon Linux 2) with dynamic AMI lookup |
| **Access** | Automated SSH key pair provisioning via Terraform |
| **Application** | Docker installed via user data; Nginx container running on port 8080 |

---

## Architecture

<p align="center">
<svg width="100%" viewBox="0 0 680 660" xmlns="http://www.w3.org/2000/svg" font-family="Arial, sans-serif">
  <defs>
    <marker id="arrow" viewBox="0 0 10 10" refX="8" refY="5" markerWidth="6" markerHeight="6" orient="auto-start-reverse">
      <path d="M2 1L8 5L2 9" fill="none" stroke="#378ADD" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round"/>
    </marker>
    <marker id="arrow-green" viewBox="0 0 10 10" refX="8" refY="5" markerWidth="6" markerHeight="6" orient="auto-start-reverse">
      <path d="M2 1L8 5L2 9" fill="none" stroke="#3B6D11" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round"/>
    </marker>
    <marker id="arrow-amber" viewBox="0 0 10 10" refX="8" refY="5" markerWidth="6" markerHeight="6" orient="auto-start-reverse">
      <path d="M2 1L8 5L2 9" fill="none" stroke="#BA7517" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round"/>
    </marker>
    <marker id="arrow-teal" viewBox="0 0 10 10" refX="8" refY="5" markerWidth="6" markerHeight="6" orient="auto-start-reverse">
      <path d="M2 1L8 5L2 9" fill="none" stroke="#1D9E75" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round"/>
    </marker>
  </defs>

  <!-- Internet -->
  <rect x="240" y="20" width="200" height="44" rx="22" fill="#E6F1FB" stroke="#185FA5" stroke-width="0.5"/>
  <text x="340" y="42" text-anchor="middle" dominant-baseline="central" font-size="14" font-weight="500" fill="#0C447C">&#127760;  Internet</text>

  <!-- Arrow: Internet to IGW -->
  <line x1="340" y1="64" x2="340" y2="102" stroke="#378ADD" stroke-width="1.5" marker-end="url(#arrow)"/>

  <!-- Internet Gateway -->
  <rect x="210" y="102" width="260" height="52" rx="8" fill="#E1F5EE" stroke="#0F6E56" stroke-width="0.5"/>
  <text x="340" y="122" text-anchor="middle" dominant-baseline="central" font-size="14" font-weight="500" fill="#085041">Internet Gateway</text>
  <text x="340" y="140" text-anchor="middle" dominant-baseline="central" font-size="12" fill="#0F6E56">dev-igw  &#183;  Routes 0.0.0.0/0</text>

  <!-- Arrow: IGW to Route Table -->
  <line x1="340" y1="154" x2="340" y2="188" stroke="#1D9E75" stroke-width="1.5" marker-end="url(#arrow-teal)"/>

  <!-- Route Table -->
  <rect x="210" y="188" width="260" height="52" rx="8" fill="#FAEEDA" stroke="#854F0B" stroke-width="0.5"/>
  <text x="340" y="208" text-anchor="middle" dominant-baseline="central" font-size="14" font-weight="500" fill="#633806">Default Route Table</text>
  <text x="340" y="226" text-anchor="middle" dominant-baseline="central" font-size="12" fill="#854F0B">dev-main-rtb  &#183;  0.0.0.0/0 &#8594; IGW</text>

  <!-- Arrow: Route Table to VPC -->
  <line x1="340" y1="240" x2="340" y2="274" stroke="#BA7517" stroke-width="1.5" marker-end="url(#arrow-amber)"/>

  <!-- VPC outer container -->
  <rect x="30" y="274" width="620" height="296" rx="16" fill="#EEEDFE" stroke="#534AB7" stroke-width="0.5"/>
  <text x="52" y="300" dominant-baseline="central" font-size="14" font-weight="500" fill="#3C3489">VPC  &#8212;  dev-vpc  &#183;  10.0.0.0/16</text>

  <!-- Subnet container -->
  <rect x="52" y="316" width="576" height="234" rx="12" fill="#E6F1FB" stroke="#185FA5" stroke-width="0.5"/>
  <text x="72" y="340" dominant-baseline="central" font-size="13" font-weight="500" fill="#0C447C">Public Subnet  &#8212;  dev-subnet-1  &#183;  10.0.10.0/24  &#183;  ca-central-1a</text>

  <!-- Security Group container -->
  <rect x="72" y="358" width="536" height="174" rx="10" fill="#FAECE7" stroke="#993C1D" stroke-width="0.5"/>
  <text x="92" y="380" dominant-baseline="central" font-size="14" font-weight="500" fill="#712B13">Security Group  &#8212;  dev-default-sg</text>

  <!-- SG rule: SSH -->
  <rect x="92" y="394" width="188" height="40" rx="8" fill="#FBEAF0" stroke="#993556" stroke-width="0.5"/>
  <text x="186" y="409" text-anchor="middle" dominant-baseline="central" font-size="13" font-weight="500" fill="#72243E">Inbound :22  TCP</text>
  <text x="186" y="425" text-anchor="middle" dominant-baseline="central" font-size="11" fill="#993556">Your IP only</text>

  <!-- SG rule: 8080 -->
  <rect x="294" y="394" width="188" height="40" rx="8" fill="#FAEEDA" stroke="#854F0B" stroke-width="0.5"/>
  <text x="388" y="409" text-anchor="middle" dominant-baseline="central" font-size="13" font-weight="500" fill="#633806">Inbound :8080  TCP</text>
  <text x="388" y="425" text-anchor="middle" dominant-baseline="central" font-size="11" fill="#854F0B">0.0.0.0/0  (public)</text>

  <!-- SG rule: outbound -->
  <rect x="496" y="394" width="100" height="40" rx="8" fill="#E1F5EE" stroke="#0F6E56" stroke-width="0.5"/>
  <text x="546" y="409" text-anchor="middle" dominant-baseline="central" font-size="13" font-weight="500" fill="#085041">Outbound</text>
  <text x="546" y="425" text-anchor="middle" dominant-baseline="central" font-size="11" fill="#0F6E56">All traffic</text>

  <!-- EC2 box -->
  <rect x="92" y="450" width="536" height="64" rx="10" fill="#EAF3DE" stroke="#3B6D11" stroke-width="0.5"/>
  <text x="340" y="472" text-anchor="middle" dominant-baseline="central" font-size="13" font-weight="500" fill="#27500A">EC2 Instance  &#8212;  dev-server  (t2.micro, Amazon Linux 2)</text>
  <text x="340" y="492" text-anchor="middle" dominant-baseline="central" font-size="11" fill="#3B6D11">AMI fetched dynamically  &#183;  SSH key pair automated  &#183;  Public IP enabled</text>

  <!-- Arrow: EC2 to Docker -->
  <line x1="340" y1="514" x2="340" y2="596" stroke="#3B6D11" stroke-width="1.5" marker-end="url(#arrow-green)"/>

  <!-- Docker + Nginx -->
  <rect x="170" y="596" width="340" height="52" rx="8" fill="#E6F1FB" stroke="#185FA5" stroke-width="0.5"/>
  <text x="340" y="616" text-anchor="middle" dominant-baseline="central" font-size="14" font-weight="500" fill="#0C447C">Docker  &#8594;  Nginx</text>
  <text x="340" y="634" text-anchor="middle" dominant-baseline="central" font-size="11" fill="#185FA5">entry-script.sh  &#183;  Port 8080:80  &#183;  via user_data</text>

  <!-- Region label -->
  <text x="650" y="650" text-anchor="end" dominant-baseline="central" font-size="11" fill="#888780">ca-central-1</text>
</svg>
</p>

---

## Project Structure

```
.
├── main.tf               # All infrastructure resources
├── providers.tf          # Provider & version constraints
├── entry-script.sh       # EC2 user data: Docker + Nginx bootstrap
├── terraform.tfvars      # ⚠️  Local variable values — NOT committed
└── README.md
```

> `terraform.tfvars` is excluded from version control. See [Security Notes](#security-notes).

---

## Prerequisites

| Requirement | Version | Notes |
|---|---|---|
| [Terraform](https://developer.hashicorp.com/terraform/install) | ≥ 1.0 | Run `terraform -version` to verify |
| [AWS CLI](https://docs.aws.amazon.com/cli/latest/userguide/install-cliv2.html) | v2+ | Must be configured with valid credentials |
| SSH key pair | — | Generate with `ssh-keygen -t rsa -b 4096` |
| AWS account | — | Permissions for VPC, EC2, and Security Groups |

---

## Configuration

All variables are defined in `main.tf` and supplied via a local `terraform.tfvars` file.

| Variable | Description | Example |
|---|---|---|
| `vpc_cidr_blocks` | CIDR block for the VPC | `"10.0.0.0/16"` |
| `subnet_cidr_block` | CIDR block for the public subnet | `"10.0.10.0/24"` |
| `avail_zone` | AWS availability zone | `"ca-central-1a"` |
| `env_prefix` | Prefix applied to all resource name tags | `"dev"` |
| `my_ip` | Your public IP for SSH access (CIDR notation) | `"x.x.x.x/32"` |
| `instance_type` | EC2 instance type | `"t2.micro"` |
| `public_key_location` | Absolute path to your local SSH public key | `"/home/<YOUR_USERNAME>/.ssh/id_rsa.pub"` |

Create `terraform.tfvars` in the project root — **do not commit this file**:

```hcl
vpc_cidr_blocks      = "10.0.0.0/16"
subnet_cidr_block    = "10.0.10.0/24"
avail_zone           = "ca-central-1a"
env_prefix           = "dev"
my_ip                = "<YOUR_PUBLIC_IP>/32"
instance_type        = "t2.micro"
public_key_location  = "/home/<YOUR_USERNAME>/.ssh/id_rsa.pub"
```

### Provider Versions (`providers.tf`)

```hcl
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
    linode = {
      source  = "linode/linode"
      version = "3.9.0"
    }
  }
}
```

---

## Getting Started

**1. Clone the repository**

```bash
git clone https://github.com/<your-username>/<your-repo>.git
cd <your-repo>
```

**2. Add your `terraform.tfvars`**

See the [Configuration](#configuration) section above and fill in your own values.

**3. Initialise Terraform**

```bash
terraform init
```

**4. Review the execution plan**

```bash
terraform plan
```

**5. Apply the configuration**

```bash
terraform apply
```

> Allow ~2 minutes after apply for the EC2 user data script to install Docker and start Nginx.

**6. SSH into the instance**

```bash
ssh -i ~/.ssh/id_rsa ec2-user@<ec2_public_ip>
```

**7. Destroy all resources when done**

```bash
terraform destroy
```

> ⚠️ Always destroy resources after the demo to avoid unexpected AWS charges.

---

## Outputs

After a successful `terraform apply`, Terraform prints the following values:

| Output | Description |
|---|---|
| `aws_ami_id` | ID of the latest Amazon Linux 2 AMI fetched dynamically |
| `ec2_public_ip` | Public IP address of the deployed EC2 instance |

Example:

```
Outputs:
  aws_ami_id    = "ami-xxxxxxxxxxxxxxxxx"
  ec2_public_ip = "35.183.x.x"
```

---

## Accessing Nginx

Once the instance is running, open your browser and navigate to:

```
http://<ec2_public_ip>:8080
```

A successful deployment serves the **Welcome to nginx!** default page — confirming that Docker and Nginx are running inside the EC2 instance.

---

## Security Notes

- **`terraform.tfvars` is gitignored.** It contains your IP address and local filesystem paths. Ensure your `.gitignore` includes:

  ```gitignore
  terraform.tfvars
  *.pem
  ```

- **Restrict `.pem` key file permissions** immediately after download:

  ```bash
  chmod 400 your-key.pem
  ```

- **SSH access is locked to your IP only.** Port 22 is restricted to `var.my_ip` in the Security Group. Port 8080 is open to the public for the purposes of this demo — restrict this for any production workloads.

- **AMI is resolved dynamically** at apply time, always using the latest Amazon Linux 2 HVM x86_64 image from Amazon's official owners list.
