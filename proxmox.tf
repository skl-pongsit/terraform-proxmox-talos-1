#see https://registry.terraform.io/providers/bpg/proxmox/0.78.0/docs/resources/virtual_environment_file
locals {
  talos_image_path      = "tmp/talos-${var.talos_version}/talos-${var.talos_version}.qcow2"
  talos_image_file_name = "talos-${var.talos_version}.img"
}

# Set iamge path to worker and controller nodes
locals {
  worker_image_path = {
    for idx in range(var.worker_count) :
    idx => "tmp/talos-${var.worker_image_tags[tostring(idx)]}/talos-${var.worker_image_tags[tostring(idx)]}.qcow2"
  }
  worker_image_file_name = {
    for idx in range(var.worker_count) :
    idx => "talos-${var.worker_image_tags[tostring(idx)]}.img"
  }

  controller_image_path = {
    for idx in range(var.controller_count) :
    idx => "tmp/talos-${var.controller_image_tags[tostring(idx)]}/talos-${var.controller_image_tags[tostring(idx)]}.qcow2"
  }
  controller_image_file_name = {
    for idx in range(var.controller_count) :
    idx => "talos-${var.controller_image_tags[tostring(idx)]}.img"
  }
}

resource "proxmox_virtual_environment_file" "talos" {
  datastore_id = "local"
  node_name    = var.proxmox_pve_node_name
  content_type = "iso"
  source_file {
    path      = local.talos_image_path
    file_name = local.talos_image_file_name
  }
}

# Create image file resource on controller node
resource "proxmox_virtual_environment_file" "talos_controller" {
  count        = var.controller_count
  datastore_id = "local"
  node_name    = var.proxmox_pve_node_name
  content_type = "iso"
  source_file {
    path      = local.controller_image_path[count.index]
    file_name = local.controller_image_file_name[count.index]
  }
  lifecycle {
    create_before_destroy = true
  }
}

# Create image file resource on worker node
resource "proxmox_virtual_environment_file" "talos_worker" {
  count        = var.worker_count
  datastore_id = "local"
  node_name    = var.proxmox_pve_node_name
  content_type = "iso"
  source_file {
    path      = local.worker_image_path[count.index]
    file_name = local.worker_image_file_name[count.index]
  }
  lifecycle {
    create_before_destroy = true
  }
}


# see https://registry.terraform.io/providers/bpg/proxmox/0.78.0/docs/resources/virtual_environment_vm
resource "proxmox_virtual_environment_vm" "controller" {
  count           = var.controller_count
  name            = "${var.prefix}-${local.controller_nodes[count.index].name}"
  node_name       = var.proxmox_pve_node_name
  tags            = sort(["talos", "controller", "example", "terraform"])
  stop_on_destroy = true
  bios            = "ovmf"
  machine         = "q35"
  scsi_hardware   = "virtio-scsi-single"
  operating_system {
    type = "l26"
  }
  cpu {
    type  = "host"
    cores = 4
  }
  memory {
    dedicated = 4 * 1024
  }
  vga {
    type = "qxl"
  }
  network_device {
    bridge = "vmbr0"
  }
  tpm_state {
    version = "v2.0"
  }
  efi_disk {
    datastore_id = "local-lvm"
    file_format  = "raw"
    type         = "4m"
  }
  disk {
    datastore_id = "local-lvm"
    interface    = "scsi0"
    iothread     = true
    ssd          = true
    discard      = "on"
    size         = 60
    file_format  = "raw"
    file_id      = proxmox_virtual_environment_file.talos_controller[count.index].id 
  }
  disk {
    datastore_id = "local-lvm"
    interface    = "scsi1"
    iothread     = true
    ssd          = true
    discard      = "on"
    size         = 60
    file_format  = "raw"
  }
  agent {
    enabled = true
    trim    = true
  }
  initialization {
    ip_config {
      ipv4 {
        address = "${local.controller_nodes[count.index].address}/24"
        gateway = var.cluster_node_network_gateway
      }
    }
  }
  depends_on = [
    proxmox_virtual_environment_file.talos_controller
  ]
  lifecycle {
    ignore_changes = [
      disk[0].file_id
    ]
  }
}

# see https://registry.terraform.io/providers/bpg/proxmox/0.78.0/docs/resources/virtual_environment_vm
resource "proxmox_virtual_environment_vm" "worker" {
  count           = var.worker_count
  name            = "${var.prefix}-${local.worker_nodes[count.index].name}"
  node_name       = var.proxmox_pve_node_name
  tags            = sort(["talos", "worker", "example", "terraform"])
  stop_on_destroy = true
  bios            = "ovmf"
  machine         = "q35"
  scsi_hardware   = "virtio-scsi-single"
  operating_system {
    type = "l26"
  }
  cpu {
    type  = "host"
    cores = 4
  }
  memory {
    dedicated = 8 * 1024
  }
  vga {
    type = "qxl"
  }
  network_device {
    bridge = "vmbr0"
  }
  tpm_state {
    version = "v2.0"
  }
  efi_disk {
    datastore_id = "local-lvm"
    file_format  = "raw"
    type         = "4m"
  }
  disk {
    datastore_id = "local-lvm"
    interface    = "scsi0"
    iothread     = true
    ssd          = true
    discard      = "on"
    size         = 60
    file_format  = "raw"
    file_id      = proxmox_virtual_environment_file.talos_worker[count.index].id #Map each worker's disk to the image file id
  }
  disk {
    datastore_id = "local-lvm"
    interface    = "scsi1"
    iothread     = true
    ssd          = true
    discard      = "on"
    size         = 60
    file_format  = "raw"
  }
  agent {
    enabled = true
    trim    = true
  }
  initialization {
    ip_config {
      ipv4 {
        address = "${local.worker_nodes[count.index].address}/24"
        gateway = var.cluster_node_network_gateway
      }
    }
  }
  depends_on = [
    proxmox_virtual_environment_file.talos_worker
  ]
   lifecycle {
    ignore_changes = [
      disk[0].file_id
    ]
  }
}
