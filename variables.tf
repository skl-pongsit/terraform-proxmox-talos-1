variable "proxmox_pve_node_name" {
  type    = string
  default = "proxmox-1"
}

variable "proxmox_api_url" {
  description = "The Proxmox API URL"
  type        = string
  default = "https://172.30.0.248:8006/api2/json"
}

variable "proxmox_api_token" {
  description = "The Proxmox API token (e.g., user@pam!token=secret)"
  type        = string
  default = "xxxxxx"
}

variable "proxmox_pve_node_address" {
  description = "The IP address of the PVE node"
  type        = string
  default = "172.30.0.248"
}
variable "proxmox_api_password" {
  description = "The Proxmox API Password"
  type        = string
  sensitive   = true
  default = "skilllaneterraform"
}

# see https://github.com/siderolabs/talos/releases
# see https://www.talos.dev/v1.9/introduction/support-matrix/
variable "talos_version" {
  type = string
  # renovate: datasource=github-releases depName=siderolabs/talos
  default = "1.10.3"
  description = "Talos image tag such as 1.10.3(upgrade talos+ext), 1.10.3-ext(upgrade ext only)"

  # Disable for custom name image
  # validation {
  #   condition     = can(regex("^\\d+(\\.\\d+)+", var.talos_version))
  #   error_message = "Must be a version number."
  # }
}

# see https://github.com/siderolabs/kubelet/pkgs/container/kubelet
# see https://www.talos.dev/v1.9/introduction/support-matrix/
variable "kubernetes_version" {
  type = string
  # renovate: datasource=github-releases depName=siderolabs/kubelet
  default = "1.33.1"
  validation {
    condition     = can(regex("^\\d+(\\.\\d+)+", var.kubernetes_version))
    error_message = "Must be a version number."
  }
}

variable "cluster_name" {
  description = "A name to provide for the Talos cluster"
  type        = string
  default     = "example"
}

variable "cluster_vip" {
  description = "The virtual IP (VIP) address of the Kubernetes API server. Ensure it is synchronized with the 'cluster_endpoint' variable."
  type        = string
  default     = "172.30.0.201"
}

variable "cluster_endpoint" {
  description = "The virtual IP (VIP) endpoint of the Kubernetes API server. Ensure it is synchronized with the 'cluster_vip' variable."
  type        = string
  default     = "https://172.30.0.201:6443"
}

variable "cluster_node_network_gateway" {
  description = "The IP network gateway of the cluster nodes"
  type        = string
  default     = "172.30.0.254"
}

variable "cluster_node_network" {
  description = "The IP network of the cluster nodes"
  type        = string
  default     = "172.30.0.0/24"
}

variable "cluster_node_network_first_controller_hostnum" {
  description = "The hostnum of the first controller host"
  type        = list(number)
  default     = [211, 212, 213, 214]
}

variable "cluster_node_network_first_worker_hostnum" {
  description = "The hostnum of the first worker host"
  type        = list(number)
  default     = [215, 216, 217, 218, 219, 220, 221, 222]
}

variable "cluster_node_network_load_balancer_first_hostnum" {
  description = "The hostnum of the first load balancer host"
  type        = number
  default     = 223
}

variable "cluster_node_network_load_balancer_last_hostnum" {
  description = "The hostnum of the last load balancer host"
  type        = number
  default     = 224
}

variable "ingress_domain" {
  description = "the DNS domain of the ingress resources"
  type        = string
  default     = "skilllane.net"
}

variable "controller_count" {
  type    = number
  default = 3
  validation {
    condition     = var.controller_count >= 1
    error_message = "Must be 1 or more."
  }
}

variable "worker_count" {
  type    = number
  default = 3
  validation {
    condition     = var.worker_count >= 1
    error_message = "Must be 1 or more."
  }
}

#  Map: controller_idx => image_tag
variable "controller_image_tags" {
  type        = map(string)
  description = "Define qcow2 image tag for each controller, index-based"
  default = {
    "0" = "1.10.3"  # controller-0 
    "1" = "1.10.3"  # controller-1 
    "2" = "1.10.3"  # controller-2
  }
}

# Map: worker_idx => image_tag
variable "worker_image_tags" {
  description = "Define qcow2 image tag for each worker, index-based"
  type        = map(string)
  default = {
    "0" = "1.10.3"      # worker-0 
    "1" = "1.10.3"      # worker-1 
    "2" = "1.10.3"      # worker-2
    # "3" = "1.10.3-ext"  # worker-3
    # "4" = "1.10.3-ext"  # worker-4 
  }
}

variable "prefix" {
  type    = string
  default = "talos-example"
}
