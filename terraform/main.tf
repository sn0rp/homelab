# LXC PROVISIONING NOTE
# These resources track existing LXCs in Terraform state.
# On disaster recovery, LXCs are created by the proxmox-homelab
# PXE firstboot script (templates/proxmox-homelab-firstboot in
# the provisioning.snorp.dev repo), which runs the community scripts
# and then imports into Terraform automatically.
#
# Manual recovery (if PXE is unavailable):
#   bash -c "$(curl -fsSL https://raw.githubusercontent.com/community-scripts/ProxmoxVE/main/ct/technitiumdns.sh)"
#   bash -c "$(curl -fsSL https://raw.githubusercontent.com/community-scripts/ProxmoxVE/main/ct/netboot-xyz.sh)"
#   terraform import proxmox_virtual_environment_container.technitium proxmox/100
#   terraform import proxmox_virtual_environment_container.provisioning proxmox/101
#   make configure

provider "proxmox" {
  endpoint  = "https://192.168.8.187:8006/"
  api_token = "${var.proxmox_token_id}=${var.proxmox_token_secret}"
  insecure  = true
  ssh {
    agent    = true
    username = "root"
  }
}

resource "proxmox_virtual_environment_container" "technitium" {
  node_name     = var.proxmox_node
  vm_id         = 100
  description   = "Technitium DNS Server"
  started       = true
  start_on_boot = true
  unprivileged  = true

  initialization {
    hostname = "technitium.snorp.dev"
    ip_config {
      ipv4 {
        address = "dhcp"
      }
    }
    user_account {
      password = var.technitium_admin_password
    }
  }

  cpu {
    cores = 1
  }

  memory {
    dedicated = 512
    swap      = 512
  }

  disk {
    datastore_id = "local"
    size         = 2
  }

  network_interface {
    name        = "eth0"
    bridge      = "vmbr0"
    mac_address = "BC:24:11:85:CE:A4"
  }

  operating_system {
    template_file_id = "local:vztmpl/debian-13-standard_13.1-2_amd64.tar.zst"
    type             = "debian"
  }

  features {
    nesting = true
    keyctl  = true
  }

  lifecycle {
    ignore_changes = [
      initialization[0].user_account,
      initialization[0].ip_config,
      operating_system[0].template_file_id,
      description,
    ]
  }

  provisioner "local-exec" {
    command = <<-EOT
      sleep 30
      ansible-playbook -i ${path.module}/../ansible/inventory.yml \
        ${path.module}/../ansible/site.yml \
        --limit technitium \
        --vault-password-file ${path.module}/../ansible/.vault_pass
    EOT
  }
}

resource "proxmox_virtual_environment_container" "provisioning" {
  node_name     = var.proxmox_node
  vm_id         = 101
  description   = "PXE Provisioning Server"
  started       = true
  start_on_boot = true
  unprivileged  = true

  initialization {
    hostname = "provisioning.snorp.dev"
    ip_config {
      ipv4 {
        address = "dhcp"
      }
    }
    user_account {
      password = var.provisioning_root_password
    }
  }

  cpu {
    cores = 1
  }

  memory {
    dedicated = 512
    swap      = 512
  }

  disk {
    datastore_id = "local"
    size         = 64
  }

  network_interface {
    name        = "eth0"
    bridge      = "vmbr0"
    mac_address = "BC:24:11:65:83:4B"
  }

  operating_system {
    template_file_id = "local:vztmpl/debian-13-standard_13.1-2_amd64.tar.zst"
    type             = "debian"
  }

  features {
    nesting = true
    keyctl  = true
  }

  lifecycle {
    ignore_changes = [
      initialization[0].user_account,
      initialization[0].ip_config,
      operating_system[0].template_file_id,
      description,
    ]
  }

  provisioner "local-exec" {
    command = <<-EOT
      sleep 30
      ansible-playbook -i ${path.module}/../ansible/inventory.yml \
        ${path.module}/../ansible/site.yml \
        --limit provisioning \
        --vault-password-file ${path.module}/../ansible/.vault_pass
    EOT
  }
}

resource "proxmox_virtual_environment_container" "searxng" {
  node_name     = var.proxmox_node
  vm_id         = 102
  description   = "SearXNG - self-hosted search engine"
  started       = true
  start_on_boot = true
  unprivileged  = true

  initialization {
    hostname = "searx.snorp.dev"
    ip_config {
      ipv4 {
        address = "dhcp"
      }
    }
    user_account {
      password = var.searxng_root_password
    }
  }

  cpu {
    cores = 1
  }

  memory {
    dedicated = 1024
    swap      = 512
  }

  disk {
    datastore_id = "local"
    size         = 4
  }

  network_interface {
    name   = "eth0"
    bridge = "vmbr0"
  }

  operating_system {
    template_file_id = "local:vztmpl/debian-13-standard_13.1-2_amd64.tar.zst"
    type             = "debian"
  }

  features {
    nesting = true
  }

  lifecycle {
    ignore_changes = [
      initialization[0].user_account,
      initialization[0].ip_config,
      operating_system[0].template_file_id,
      description,
    ]
  }

  provisioner "local-exec" {
    command = <<-EOT
      sleep 30
      ansible-playbook -i ${path.module}/../ansible/inventory.yml \
        ${path.module}/../ansible/site.yml \
        --limit searxng \
        --vault-password-file ${path.module}/../ansible/.vault_pass
    EOT
  }
}