# 🚀 AWS EKS Cluster — Terraform Infrastructure

![Terraform](https://img.shields.io/badge/Terraform-v1.x-7B42BC?logo=terraform&logoColor=white)
![AWS](https://img.shields.io/badge/AWS-EKS%201.34-FF9900?logo=amazon-aws&logoColor=white)
![Kubernetes](https://img.shields.io/badge/Kubernetes-1.34-326CE5?logo=kubernetes&logoColor=white)
![License](https://img.shields.io/badge/License-MIT-green)

A production-ready **Amazon EKS cluster** provisioned entirely with Terraform, deployed across three Availability Zones in `ca-central-1`. This project provisions a fully networked VPC, managed node groups, KMS encryption, CloudWatch logging, and essential EKS add-ons — following AWS and Kubernetes best practices.

---

## 📐 Architecture Overview

![Architecture Diagram](./docs/architecture.svg)

> Save [`docs/architecture.svg`](./docs/architecture.svg) from this repo for a full-resolution view.

The infrastructure is deployed across **3 Availability Zones** (`ca-central-1a`, `ca-central-1b`, `ca-central-1d`) inside a single VPC (`10.0.0.0/16`). Traffic enters via the Internet Gateway, is routed through the VPC Router to the Network Load Balancer in the public subnets, and forwarded over HTTPS 443 to the EKS cluster and Ingress Controller in the private subnets. Worker nodes across all three AZs communicate directly with the control plane. Private subnet egress uses a single NAT Gateway in AZ-A. Supporting platform services — KMS, CloudWatch, OIDC/IRSA, and EKS add-ons — are attached to the cluster.

| Tier | Subnets | CIDR range | Key components |
|------|---------|------------|----------------|
| Public | 3 (one per AZ) | `10.0.4–6.0/24` | Internet Gateway, NAT Gateway, Network Load Balancer |
| Private | 3 (one per AZ) | `10.0.1–3.0/24` | EKS Cluster, Worker Nodes, Ingress Controller, EBS, Aurora RDS |

---

## ✅ Features

- **Amazon EKS 1.34** — Managed Kubernetes control plane with public + private endpoint access
- **Managed Node Groups** — AL2023 x86_64 worker nodes with auto-scaling (1–3 nodes)
- **Custom VPC** — Isolated network with public/private subnets across 3 AZs
- **NAT Gateway** — Single NAT for private subnet egress
- **KMS Encryption** — CMK encryption for Kubernetes secrets at rest
- **CloudWatch Logging** — API, audit, and authenticator logs retained for 90 days
- **EKS Add-ons** — CoreDNS, kube-proxy, VPC CNI, and EKS Pod Identity Agent
- **IRSA Support** — IAM Roles for Service Accounts via OIDC provider
- **IMDSv2 Enforced** — Hardened instance metadata access on all nodes
- **Kubernetes subnet tags** — Correct ELB and internal-ELB tags for load balancer integration

---

## 🗂️ Project Structure

```
.
├── vpc.tf                  # VPC, subnets, NAT gateway, routing
├── eks-cluster.tf          # EKS cluster, node groups, add-ons
├── terraform.tfvars        # Variable values
└── README.md
```

---

## 📋 Prerequisites

Before deploying, ensure the following are installed and configured:

| Tool | Version | Purpose |
|------|---------|---------|
| [Terraform](https://developer.hashicorp.com/terraform/install) | >= 1.3.0 | Infrastructure provisioning |
| [AWS CLI](https://aws.amazon.com/cli/) | >= 2.x | AWS authentication |
| [kubectl](https://kubernetes.io/docs/tasks/tools/) | >= 1.34 | Cluster interaction |
| [helm](https://helm.sh/docs/intro/install/) | >= 3.x | Kubernetes package manager |

You must also have an **AWS IAM user or role** with sufficient permissions to create EKS, VPC, IAM, KMS, and CloudWatch resources.

---

## ⚙️ Configuration

### Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `vpc_cidr_block` | CIDR block for the VPC | `10.0.0.0/16` |
| `private_subnet_cidr_blocks` | List of private subnet CIDRs | `["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]` |
| `public_subnet_cidr_blocks` | List of public subnet CIDRs | `["10.0.4.0/24", "10.0.5.0/24", "10.0.6.0/24"]` |

### `terraform.tfvars`

Create a `terraform.tfvars` file in the `Terraform/` directory and populate it with your own values:

```hcl
vpc_cidr_block             = "<your-vpc-cidr>"
private_subnet_cidr_blocks = ["<az-a-private>", "<az-b-private>", "<az-c-private>"]
public_subnet_cidr_blocks  = ["<az-a-public>",  "<az-b-public>",  "<az-c-public>"]
```

> **Security note:** `terraform.tfvars` is listed in `.gitignore` and must never be committed to source control, as it may contain environment-specific network values.

---

## 🚀 Deployment

### 1. Clone the repository

```bash
git clone https://github.com/<your-username>/<your-repo>.git
cd <your-repo>/Terraform
```

### 2. Configure AWS credentials

```bash
aws configure
# or export environment variables
export AWS_ACCESS_KEY_ID=<your-key>
export AWS_SECRET_ACCESS_KEY=<your-secret>
export AWS_DEFAULT_REGION=ca-central-1
```

### 3. Initialise Terraform

```bash
terraform init
```

### 4. Preview the execution plan

```bash
terraform plan
```

### 5. Apply the configuration

```bash
terraform apply --auto-approve
```

> ⏱️ **Note:** Full deployment typically takes **12–18 minutes** due to EKS control plane provisioning and NAT gateway creation.

### 6. Configure kubectl

Once `terraform apply` completes, register the cluster with your local kubeconfig:

```bash
aws eks update-kubeconfig --name myapp-eks-cluster --region ca-central-1
```

Expected output:

```
Added new context arn:aws:eks:ca-central-1:099597654282:cluster/myapp-eks-cluster to /home/<user>/.kube/config
```

### 7. Verify all three nodes are Ready

```bash
kubectl get nodes
```

Expected output — one node per Availability Zone (AZ-A, AZ-B, AZ-C), all in `Ready` state:

```
NAME                                          STATUS   ROLES    AGE   VERSION
ip-10-0-1-117.ca-central-1.compute.internal   Ready    <none>   15m   v1.34.4-eks-f69f56f
ip-10-0-2-195.ca-central-1.compute.internal   Ready    <none>   15m   v1.34.4-eks-f69f56f
ip-10-0-3-137.ca-central-1.compute.internal   Ready    <none>   15m   v1.34.4-eks-f69f56f
```

### 8. Deploy a workload

Apply your Kubernetes manifests. The example below deploys an Nginx workload with a `LoadBalancer` service:

```bash
kubectl apply -f ~/DevOps-Project/Terraform-Project/nginx-config.yaml
```

Expected output:

```
deployment.apps/nginx-deployment created
service/nginx-service created
```

### 9. Verify the pod is running

```bash
kubectl get pods
```

Expected output:

```
NAME                                READY   STATUS    RESTARTS   AGE
nginx-deployment-6f9664446b-4n24g   1/1     Running   0          11s
```

### 10. Retrieve the external Load Balancer URL

```bash
kubectl get svc
```

Expected output:

```
NAME            TYPE           CLUSTER-IP      EXTERNAL-IP                                                                 PORT(S)        AGE
kubernetes      ClusterIP      172.20.0.1      <none>                                                                      443/TCP        30m
nginx-service   LoadBalancer   172.20.246.64   ac2b1c912aba7468f95f19de982a1529-117595377.ca-central-1.elb.amazonaws.com   80:31011/TCP   29s
```

The `EXTERNAL-IP` value is the AWS Classic Load Balancer DNS name automatically provisioned by the cloud controller manager. Copy that hostname and open it in your browser — or test it with curl:

```bash
curl http://ac2b1c912aba7468f95f19de982a1529-117595377.ca-central-1.elb.amazonaws.com
```

> ⏱️ **Note:** It may take 1–2 minutes for the Load Balancer DNS to propagate and become reachable after the service is created.

---

## 🔌 EKS Add-ons

| Add-on | Description | Installed Before Compute? |
|--------|-------------|--------------------------|
| `vpc-cni` | AWS VPC CNI for pod networking | ✅ Yes |
| `eks-pod-identity-agent` | Pod identity for IAM integration | ✅ Yes |
| `coredns` | Cluster DNS resolution | No |
| `kube-proxy` | Network rule management on nodes | No |

---

## 🧱 Infrastructure Resources Created

| Resource | Count | Notes |
|----------|-------|-------|
| VPC | 1 | `10.0.0.0/16` |
| Public Subnets | 3 | One per AZ |
| Private Subnets | 3 | One per AZ |
| NAT Gateway | 1 | Single, in AZ-A public subnet |
| Internet Gateway | 1 | — |
| EKS Cluster | 1 | Version 1.34 |
| Managed Node Group | 1 | `dev`, 1–3 × `t2.small` (AL2023) |
| KMS Key | 1 | For secrets encryption |
| CloudWatch Log Group | 1 | 90-day retention |
| IAM Roles | 2 | Cluster role + Node group role |
| Security Groups | 2 | Cluster SG + Node SG |
| OIDC Provider | 1 | For IRSA |

---

## 🔒 Security Highlights

- **Private worker nodes** — EC2 instances are never directly exposed to the internet
- **KMS-encrypted secrets** — All Kubernetes secrets encrypted with a customer-managed key
- **IMDSv2 enforced** — Instance Metadata Service v2 required on all nodes (`http_tokens = "required"`)
- **Least-privilege IAM** — Separate IAM roles for control plane and worker nodes with only required managed policies
- **Cluster endpoint** — Both public and private access enabled; restrict `public_access_cidrs` for hardened environments
- **CloudWatch audit logging** — API, audit, and authenticator logs captured for compliance

---

## 🧹 Teardown

To destroy all provisioned resources:

```bash
terraform destroy --auto-approve
```

> ⚠️ **Warning:** This will permanently delete the EKS cluster, all worker nodes, the VPC, and all associated resources. Ensure any persistent volumes or load balancers created by Kubernetes are removed first, as they may not be cleaned up by Terraform.

---

## 🛠️ Troubleshooting

### Security group not associated with VPC
Ensure `vpc_id` in `eks-cluster.tf` references `module.myapp-vpc.vpc_id` — **not** `module.myapp-vpc.default_vpc_id`.

```hcl
# ✅ Correct
vpc_id = module.myapp-vpc.vpc_id

# ❌ Wrong — points to the AWS account default VPC
vpc_id = module.myapp-vpc.default_vpc_id
```

### kubectl connection refused
Re-run the `update-kubeconfig` command and confirm your IAM identity matches the cluster creator:

```bash
aws sts get-caller-identity
aws eks update-kubeconfig --region ca-central-1 --name myapp-eks-cluster
```

### Nodes not joining the cluster
Verify the node IAM role has the required policies attached: `AmazonEKSWorkerNodePolicy`, `AmazonEKS_CNI_Policy`, and `AmazonEC2ContainerRegistryReadOnly`.

---

## 📚 References

- [Terraform AWS EKS Module](https://registry.terraform.io/modules/terraform-aws-modules/eks/aws/latest)
- [Terraform AWS VPC Module](https://registry.terraform.io/modules/terraform-aws-modules/vpc/aws/latest)
- [Amazon EKS Best Practices Guide](https://aws.github.io/aws-eks-best-practices/)
- [AWS EKS Documentation](https://docs.aws.amazon.com/eks/latest/userguide/what-is-eks.html)

---

## 📄 License

This project is licensed under the [MIT License](LICENSE).

---

> Built with ❤️ using Terraform and AWS EKS
