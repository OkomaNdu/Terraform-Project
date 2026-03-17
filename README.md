# 🚀 AWS Nginx Docker Deployment — Terraform Modules

> Modular Infrastructure as Code with Terraform — deploys a Dockerized Nginx web server on AWS EC2, structured using reusable Terraform modules.

![AWS](https://img.shields.io/badge/AWS-ca--central--1-FF9900?style=flat&logo=amazonaws&logoColor=white)
![Terraform](https://img.shields.io/badge/Terraform-Modules-7B42BC?style=flat&logo=terraform&logoColor=white)
![Docker](https://img.shields.io/badge/Docker-Nginx-2496ED?style=flat&logo=docker&logoColor=white)
![EC2](https://img.shields.io/badge/EC2-t2.micro-232F3E?style=flat&logo=amazonaws&logoColor=white)
![License](https://img.shields.io/badge/License-MIT-green?style=flat)

---

## 📋 Overview

This project provisions a complete AWS infrastructure using **Terraform modules** to deploy an **Nginx web server** running inside a **Docker container** on an Amazon EC2 instance.

The configuration is split into two reusable modules:

- **`subnet` module** — handles VPC networking: subnet, internet gateway, and route table
- **`webserver` module** — handles compute: security group, AMI lookup, key pair, and EC2 instance

Docker and Nginx are bootstrapped automatically on launch via a `user_data` script — no provisioners, no SSH dependency.

---

## 🏗️ Architecture

![AWS Architecture Diagram](./architecture.svg)

> **Left panel** shows the Dev Environment — Terraform config files (`*.tf`), the `entry-script.sh` bootstrap, Terraform core, and the generated `.tfstate` file.
> **Right panel** shows the AWS Cloud — nested boundaries from Region → VPC → Availability Zone → Public Subnet → Security Group → EC2 instance running Docker + Nginx, connected through an Internet Gateway and Route Table to end users.

---

## ✅ Deployment Screenshots

### Nginx running in the browser

![Nginx Welcome Page](./nginx-welcome.png)

### Docker confirmed running on the EC2 instance

![Docker PS Output](./docker-ps.png)

> Docker version 25.0.14 confirmed. Nginx container running on `0.0.0.0:8080->80/tcp`.

---

## 📁 Project Structure

```
.
├── main.tf                        # Root: provider, VPC, module calls
├── variables.tf                   # Root-level input variables
├── outputs.tf                     # Root-level outputs (EC2 public IP)
├── entry-script.sh                # Bootstrap: installs Docker + runs Nginx
│
└── modules/
    ├── subnet/
    │   ├── main.tf                # Subnet, Internet Gateway, Route Table
    │   ├── variables.tf           # Module input variables
    │   └── outputs.tf             # Exports subnet object
    │
    └── webserver/
        ├── main.tf                # Security Group, AMI lookup, Key Pair, EC2
        ├── variables.tf           # Module input variables
        └── outputs.tf             # Exports EC2 instance object
```

---

## ⚠️ Before You Start — Protect Sensitive Files

Add the following to your `.gitignore` to prevent accidentally committing sensitive state and lock files:

```gitignore
# Terraform
*.tfstate
*.tfstate.*
.terraform/
.terraform.lock.hcl
output.txt
```

---

## ✅ Prerequisites

| Tool | Version | Purpose |
|------|---------|---------|
| [Terraform](https://developer.hashicorp.com/terraform/downloads) | >= 1.3.0 | Infrastructure provisioning |
| [AWS CLI](https://aws.amazon.com/cli/) | >= 2.x | AWS authentication & credentials |
| SSH Key Pair | RSA / Ed25519 | Secure access to the EC2 instance |
| AWS Account | — | Target environment for all resources |

> **IAM permissions required:** EC2, VPC, Subnets, Internet Gateway, Route Tables, Security Groups, Key Pairs.

---

## ⚙️ Configuration Variables

Create a `terraform.tfvars` file in the root directory and populate it with your own values:

```hcl
vpc_cidr_blocks      = "10.0.0.0/16"
subnet_cidr_block    = "10.0.10.0/24"
avail_zone           = "eu-central-1a"
env_prefix           = "dev"
my_ip                = "YOUR.PUBLIC.IP.ADDRESS/32"
instance_type        = "t2.micro"
image_name           = "amzn2-ami-hvm-*-x86_64-gp2"
public_key_location  = "/path/to/your/.ssh/id_rsa.pub"
```

> **Tip:** Run `curl ifconfig.me` to get your current public IP for the `my_ip` field.

| Variable | Example Value | Description |
|----------|--------------|-------------|
| `vpc_cidr_blocks` | `10.0.0.0/16` | CIDR block for the VPC |
| `subnet_cidr_block` | `10.0.10.0/24` | CIDR block for the public subnet |
| `avail_zone` | `eu-central-1a` | AWS Availability Zone |
| `env_prefix` | `dev` | Prefix for all resource name tags |
| `my_ip` | `YOUR.PUBLIC.IP.ADDRESS/32` | Your IP — restricts SSH to your machine only |
| `instance_type` | `t2.micro` | EC2 instance size (free-tier eligible) |
| `image_name` | `amzn2-ami-hvm-*-x86_64-gp2` | AMI filter — always fetches latest Amazon Linux 2 |
| `public_key_location` | `/path/to/.ssh/id_rsa.pub` | Path to your SSH public key |

---

## 🧩 Module Breakdown

### Root — `main.tf`

The root module wires everything together. It creates the VPC directly and calls the two child modules, passing outputs between them.

```hcl
provider "aws" {
  region = "eu-central-1"
}

resource "aws_vpc" "myapp-vpc" { ... }

module "myapp-subnet" {
  source                 = "./modules/subnet"
  vpc_id                 = aws_vpc.myapp-vpc.id
  default_route_table_id = aws_vpc.myapp-vpc.default_route_table_id
  ...
}

module "myapp-server" {
  source    = "./modules/webserver"
  vpc_id    = aws_vpc.myapp-vpc.id
  subnet_id = module.myapp-subnet.subnet.id
  ...
}
```

---

### Module 1 — `modules/subnet`

Responsible for all **networking** resources inside the VPC.

| Resource | Name | Description |
|----------|------|-------------|
| `aws_subnet` | `dev-subnet-1` | Public subnet (`10.0.10.0/24`) |
| `aws_internet_gateway` | `dev-igw` | Attaches internet access to the VPC |
| `aws_default_route_table` | `dev-main-rtb` | Routes `0.0.0.0/0` traffic through the IGW |

**Input variables:**

| Variable | Description |
|----------|-------------|
| `vpc_id` | ID of the parent VPC |
| `default_route_table_id` | VPC's default route table to modify |
| `subnet_cidr_block` | CIDR for the subnet |
| `avail_zone` | Availability zone to deploy into |
| `env_prefix` | Tag prefix for resource names |

**Output:** `subnet` — the full subnet object (used by the webserver module to get `subnet.id`)

---

### Module 2 — `modules/webserver`

Responsible for all **compute** resources.

| Resource | Description |
|----------|-------------|
| `aws_default_security_group` | Firewall: SSH on :22 (your IP), HTTP on :8080 (open) |
| `data.aws_ami` | Dynamically fetches latest Amazon Linux 2 HVM AMI |
| `aws_key_pair` | Uploads your public key to AWS as `server-key` |
| `aws_instance` | EC2 t2.micro with public IP and `user_data` bootstrap |

**Security Group Rules:**

| Direction | Port | Source | Purpose |
|-----------|------|--------|---------|
| Inbound | `22` | Your IP only (`/32`) | SSH management |
| Inbound | `8080` | `0.0.0.0/0` | Public HTTP access |
| Outbound | All | `0.0.0.0/0` | Unrestricted egress |

**Input variables:**

| Variable | Description |
|----------|-------------|
| `vpc_id` | ID of the VPC |
| `subnet_id` | Subnet to launch the EC2 instance into |
| `avail_zone` | Availability zone |
| `my_ip` | Your public IP for SSH security group rule |
| `env_prefix` | Tag prefix |
| `image_name` | AMI name filter pattern |
| `instance_type` | EC2 instance type |
| `public_key_location` | Path to SSH public key on your machine |

**Output:** `instance` — the full EC2 instance object (used in root outputs to get `instance.public_ip`)

---

## 🛠️ Bootstrap Script — `entry-script.sh`

This script is passed as `user_data` and runs automatically on first boot — no SSH provisioners needed.

```bash
#!/bin/bash
sudo yum update -y && sudo yum install docker -y   # Install Docker
sudo systemctl start docker                         # Start Docker daemon
sudo systemctl enable docker                        # Enable Docker on reboot
sudo usermod -aG docker ec2-user                   # Grant ec2-user Docker access
sudo docker run -d -p 8080:80 nginx                 # Run Nginx (detached, port 8080)
```

> Using `user_data` instead of provisioners means the script runs via **cloud-init** — it's more reliable, has no SSH timing dependency, and re-runs automatically if `user_data_replace_on_change = true` is set.

---

## 🚀 Deployment Guide

### Step 1 — Clone the repository

```bash
git clone https://github.com/<your-username>/<your-repo>.git
cd <your-repo>
```

### Step 2 — Configure your variables

Create a `terraform.tfvars` file in the root directory:

```hcl
vpc_cidr_blocks      = "10.0.0.0/16"
subnet_cidr_block    = "10.0.10.0/24"
avail_zone           = "eu-central-1a"
env_prefix           = "dev"
my_ip                = "YOUR.PUBLIC.IP.ADDRESS/32"
instance_type        = "t2.micro"
image_name           = "amzn2-ami-hvm-*-x86_64-gp2"
public_key_location  = "/path/to/your/.ssh/id_rsa.pub"
```

### Step 3 — Initialise Terraform and download modules

```bash
terraform init
```

You should see Terraform initialising both local modules:

```
Initializing modules...
- myapp-subnet in modules/subnet
- myapp-server in modules/webserver
```

### Step 4 — Preview the execution plan

```bash
terraform plan
```

### Step 5 — Apply the configuration

```bash
terraform apply --auto-approve
```

Deployment takes approximately **1–2 minutes**. On completion you will see:

```
Apply complete! Resources: 7 added, 0 changed, 0 destroyed.

Outputs:
ec2_public_ip = "xx.xx.xx.xx"
```

### Step 6 — Access the application

```bash
# Open Nginx in your browser:
http://<ec2_public_ip>:8080

# SSH into the instance:
ssh -i /path/to/id_rsa ec2-user@<ec2_public_ip>

# Verify Docker and Nginx are running:
docker ps
docker -v
```

---

## 📤 Outputs

| Output | Source | Description |
|--------|--------|-------------|
| `ec2_public_ip` | `module.myapp-server.instance.public_ip` | Public IP of the deployed EC2 instance |

---

## 🗑️ Teardown

To destroy all provisioned resources and stop AWS charges:

```bash
terraform destroy
```

> ⚠️ **Warning:** This permanently deletes all resources — VPC, subnet, security group, and EC2 instance. This cannot be undone.

---

## 🔐 Security Notes

- **Never commit `terraform.tfstate`** — use a remote backend (S3 + DynamoDB) for team environments.
- SSH is locked to **your IP only** via a `/32` CIDR — rotate `my_ip` if your IP changes.
- Your **private key** must never be shared or committed.
- Port `8080` is open to the world. For production, place the server behind an **Application Load Balancer** with HTTPS.
- Consider migrating from **Amazon Linux 2** (EOL: 2026-06-30) to **Amazon Linux 2023** for long-running environments.

---

## 🔍 Troubleshooting

| Issue | Likely Cause | Fix |
|-------|-------------|-----|
| `terraform init` fails | Module path wrong | Confirm `source = "./modules/subnet"` paths match your folder names |
| SSH connection refused | `my_ip` outdated | Run `curl ifconfig.me`, update `my_ip`, re-apply |
| Port 8080 not responding | `user_data` still running | Wait 2–3 mins after apply then retry — cloud-init runs after boot |
| Docker not found on instance | `user_data` failed silently | Check logs: `sudo cat /var/log/cloud-init-output.log` |
| `subnet_id` error on apply | Module output not wired correctly | Confirm `subnet_id = module.myapp-subnet.subnet.id` in root `main.tf` |
| Key pair already exists | `server-key` already in AWS | Delete it in the AWS console or rename it in the config |
| AMI not found | `image_name` filter too strict | Use `amzn2-ami-hvm-*-x86_64-gp2` as the filter value |

---

## 🤝 Contributing

Contributions are welcome! To contribute:

1. Fork the repository and create a feature branch
2. Make your changes and validate with `terraform plan`
3. Open a pull request with a clear description of the change

---

## 📄 License

This project is licensed under the [MIT License](LICENSE).

---

<p align="center">Built with Terraform Modules &nbsp;•&nbsp; Deployed on AWS &nbsp;•&nbsp; Powered by Docker + Nginx</p>
