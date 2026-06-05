variable "proxmox_api_url" {
  default = "https://192.168.8.187:8006/"
}

variable "proxmox_token_id" {
  description = "Proxmox API token ID (e.g. root@pam!terraform)"
}

variable "proxmox_token_secret" {
  description = "Proxmox API token secret"
  sensitive   = true
}

variable "proxmox_node" {
  default = "proxmox"
}

variable "technitium_admin_password" {
  description = "Root password for Technitium LXC"
  sensitive   = true
}

variable "provisioning_root_password" {
  description = "Root password for Provisioning LXC"
  sensitive   = true
}