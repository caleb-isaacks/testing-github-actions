# Secure Hub-and-Spoke Network on Azure (Terraform)

![Terraform](https://img.shields.io/badge/IaC-Terraform-7B42BC) ![Azure](https://img.shields.io/badge/Cloud-Azure-0078D4) ![CI](https://img.shields.io/badge/CI-GitHub_Actions-2088FF)

## The Problem (Plain English)

A small business needs a secure network in the cloud that it can rebuild the same way every time. Building it by hand through the Azure portal is slow, easy to get wrong, and hard to repeat.

**This project solves that.** One command builds a complete, locked-down network. All admin access goes through a secure gateway, and all traffic is filtered through a central firewall. The whole environment can be torn down and rebuilt identically in minutes.

## Architecture
<img width="1229" height="634" alt="image" src="https://github.com/user-attachments/assets/5d8a1b0a-4a77-4d3f-aaa8-daaeb8f1f7a8" />

| Component | Purpose |
|---|---|
| **Hub VNet** | Central network holding shared security services |
| **Spoke VNet(s)** | Isolated networks for workloads, peered to the hub |
| **Azure Firewall** | Inspects and filters traffic between spokes and to the internet |
| **Azure Bastion** | Secure browser-based admin access to VMs, with no public IPs on VMs |
| **Network Security Groups** | Subnet-level least-privilege traffic rules |
| **Route Tables (UDRs)** | Force spoke traffic through the firewall |

## Security & Governance

- **No public IPs on workload VMs.** Admin access goes only through Bastion.
- **Least-privilege NSG rules.** Deny by default, allow only required ports.
- **Centralized traffic inspection.** All spoke-to-spoke and outbound traffic routes through Azure Firewall.
- **No secrets in code.** Sensitive values come from variables / environment, and `.tfvars` files are git-ignored.


## CI/CD

Every pull request runs a GitHub Actions workflow that:
1. Terraform init (`terraform init`)
2. Validates configuration (`terraform validate`)
3. Scans with Checkov

<img width="1886" height="937" alt="image" src="https://github.com/user-attachments/assets/95336b6d-3ce3-4097-9f8b-1e993df5f66a" />


## Proof It Works
<img width="1907" height="946" alt="image" src="https://github.com/user-attachments/assets/b878901d-a512-42ae-adcd-3711b2d772c3" />

Azure portal with resources

<img width="1395" height="794" alt="image" src="https://github.com/user-attachments/assets/29ca0def-9f1c-400a-9fe5-f9705a25909c" />

Linux Connection via Bastion

<img width="509" height="246" alt="image" src="https://github.com/user-attachments/assets/c67f01e5-5161-4712-824d-1673567841fe" />

Curl going to example.com to test internet connectivity

## Troubleshooting & Lessons Learned
One lesson learned was adding allow_forwarded_traffic = true in the azure virtual network peering resources. 
<!--
