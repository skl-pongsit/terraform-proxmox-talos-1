# About

An example [Talos Linux](https://www.talos.dev) Kubernetes cluster in Proxmox QEMU/KVM Virtual Machines using terraform.

[Cilium](https://cilium.io) is used to augment the Networking (e.g. the [`LoadBalancer`](https://cilium.io/use-cases/load-balancer/) and [`Ingress`](https://docs.cilium.io/en/stable/network/servicemesh/ingress/) controllers), Observability (e.g. [Service Map](https://cilium.io/use-cases/service-map/)), and Security (e.g. [Network Policy](https://cilium.io/use-cases/network-policy/)).


# Usage (Ubuntu 22.04 host)

Install terraform:

```bash
# see https://github.com/hashicorp/terraform/releases
# renovate: datasource=github-releases depName=hashicorp/terraform
terraform_version='1.12.0'
wget "https://releases.hashicorp.com/terraform/$terraform_version/terraform_${terraform_version}_linux_amd64.zip"
unzip "terraform_${terraform_version}_linux_amd64.zip"
sudo install terraform /usr/local/bin
rm terraform terraform_*_linux_amd64.zip
```

Install cilium cli:

```bash
# see https://github.com/cilium/cilium-cli/releases
# renovate: datasource=github-releases depName=cilium/cilium-cli
cilium_version='0.18.3'
cilium_url="https://github.com/cilium/cilium-cli/releases/download/v$cilium_version/cilium-linux-amd64.tar.gz"
wget -O- "$cilium_url" | tar xzf - cilium
sudo install cilium /usr/local/bin/cilium
rm cilium
```

Install cilium hubble:

```bash
# see https://github.com/cilium/hubble/releases
# renovate: datasource=github-releases depName=cilium/hubble
hubble_version='1.17.3'
hubble_url="https://github.com/cilium/hubble/releases/download/v$hubble_version/hubble-linux-amd64.tar.gz"
wget -O- "$hubble_url" | tar xzf - hubble
sudo install hubble /usr/local/bin/hubble
rm hubble
```

Install talosctl:

```bash
# see https://github.com/siderolabs/talos/releases
# renovate: datasource=github-releases depName=siderolabs/talos
talos_version='1.10.3'
wget https://github.com/siderolabs/talos/releases/download/v$talos_version/talosctl-linux-amd64
sudo install talosctl-linux-amd64 /usr/local/bin/talosctl
rm talosctl-linux-amd64
```

# Talos Cluster Provisioning with Terraform

This guide describes how to:

- Build Talos images
- Deploy the infrastructure using Terraform
- Upgrade Talos Extensions
- Scale up your cluster with updated `.qcow2` images

---

## 1. Build Talos Image and Initialize Terraform

Run the following command to build the base Talos image and initialize the Terraform environment:

```bash
talos_version=1.10.3 ./do init
```
**Note:**  
`talos_version` should match a supported Talos release.  
Set `talos_version` using the `imageRef` from the official [SideroLabs Talos releases](https://github.com/siderolabs/talos/releases).

---

## 2. Create the Infrastructure

### Step 1: Preview changes

```bash
terraform plan
```

### Step 2: Apply changes and export Talos configuration

```bash
terraform apply -auto-approve -parallelism=3 && ./do export-config
```

> 🛠️ `-parallelism=3` is used to limit concurrent VM provisioning (adjust as needed).

---

## 3. Upgrade Talos Extensions

Build the Talos image and Docker-based installer with updated extensions:

```bash
talos_version=1.10.3 talos_image_tag=1.10.3-ext ./do upgrade-talos-extensions 
```

### Notes

- ✅ **Add `-ext`** when building the installer using the **previous Talos version** but with **updated extension versions**.  
  **Example:**  
  `talos_image_tag=1.10.x-ext`

- ❌ **Do not add `-ext`** if building the installer with both a **new Talos version** and **new extensions**.  
  **Example:**  
  `talos_image_tag=1.10.x`

### Manual Node Upgrade (Using `talosctl upgrade`)

If you need to manually upgrade Talos nodes with a new installer image (e.g., to apply updated extensions),
you can run the following commands **sequentially per node**.

Start with **controllers** (e.g., `c1`, `c2`, `c3`), followed by **workers** (e.g., `w1`, `w2`, `w3`).

#### Example:
```bash
# Controller Nodes
talosctl upgrade --nodes 192.xx.xx.xx --image docker.io/youruser/installer-talos-ext:v1.10.3-ext --preserve=true

# Worker Nodes
talosctl upgrade --nodes 192.xx.xx.xx --image docker.io/youruser/installer-talos-ext:v1.10.3-ext --preserve=true
```

---

## 4. Terraform Scale-Up Using Updated Talos `.qcow2` Image

You can scale up the cluster (e.g., increase worker count) using the updated `.qcow2` image built in the previous step.

### Example Use Case

Scale up **workers from 3 to 5 nodes** by:

- Updating the `worker_count` variable
- Assigning updated image tags in `worker_image_tags`

### `variables.tf` Example

```hcl
variable "worker_count" {
  type    = number
  default = 5
}

variable "worker_image_tags" {
  type        = map(string)
  default = {
    "0" = "1.10.3"       # worker-0
    "1" = "1.10.3"       # worker-1
    "2" = "1.10.3"       # worker-2
    "3" = "1.10.3-ext"   # worker-3 (new)
    "4" = "1.10.3-ext"   # worker-4 (new)
  }
}
```