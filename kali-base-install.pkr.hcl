packer {
  required_plugins {
    proxmox = {
      version = "= 1.2.1"
      source  = "github.com/hashicorp/proxmox"
    }
    git = {
      version = ">= 0.4.2"
      source  = "github.com/ethanmdavidson/git"
    }
    ansible = {
      version = ">= 1.1.0"
      source  = "github.com/hashicorp/ansible"
    }
  }
}

//  BLOCK: data
//  Defines the data sources.

data "git-repository" "cwd" {}

//  BLOCK: variable
//  The many variables defined for build.

variable "proxmox_host" {
    type = string
}

variable "proxmox_node" {
    type = string
}

variable "proxmox_user" {
    type = string
}

variable "proxmox_apikey" {
    type = string
}

variable "vlan_tag" {
    type = string
    default = ""
}

variable "ssh_user" {
    type = string
}

variable "ssh_private_key_file" {
    type = string
}  

variable "build_key" {
    type = string
}

variable "build_passwd_local" {
    type = string
}

variable "ansible_provisioner_playbook_path" {
    type = string
    default = "kali-packer-config.yml"
}

variable "kali_boot_iso_path" {
    type = string
    default = "local:iso/kali-linux-installer.iso"
}

locals {
  iso_path = "{{var.iso_path}}"
  data_source_content = {
    "/preseed.cfg" = templatefile("${abspath(path.root)}/preseed.cfg", {
      ssh_user                 = var.ssh_user
      build_key                = var.build_key
      build_passwd             = var.build_passwd_local
      }
    )
  }
  data_source_command = "preseed/url=http://{{ .HTTPIP }}:{{ .HTTPPort }}/preseed.cfg"
}

source "proxmox-iso" "kali-tpl" {

    proxmox_url = "https://${var.proxmox_host}:8006/api2/json"
    insecure_skip_tls_verify = true
    node = var.proxmox_node
    boot_iso {
      type = "scsi"
      iso_file = var.kali_boot_iso_path
      unmount = true
    }
    vm_name = "kali-base-image"
    vm_id = 997
    username = var.proxmox_user
    token = var.proxmox_apikey
    os = "l26"
    bios = "ovmf"
    efi_config {
      efi_storage_pool  = "local-lvm"
      pre_enrolled_keys = false
      efi_format        = "raw"
      efi_type          = "4m"
    }
    qemu_agent = true
    tpm_config {
      tpm_version 	    = "v2.0"
      tpm_storage_pool  = "local-lvm"
    }
    cpu_type = "host"
    cores = "2"
    memory = "4096"
    scsi_controller = "virtio-scsi-pci"
    disks {
      type              = "sata"
      disk_size         = "40G"
      storage_pool      = "local-lvm"
      format	        = "raw"
    }
    network_adapters {
      bridge            = "vmbr0"
      vlan_tag          = var.vlan_tag
      model             = "virtio"
    }
    communicator        = "ssh"
    ssh_username        = var.ssh_user
    ssh_password        = var.build_passwd_local
    ssh_timeout         = "30m"
    ssh_handshake_attempts = "100"
    boot_command = ["<wait15s>", "<e><bs><down><down><down><down>", "<bs><bs><bs><bs><bs><bs><bs><bs><bs><bs><bs><bs><bs><bs><bs><bs><bs><bs><bs><bs><bs><bs><bs><bs><bs><bs><bs><bs><bs><bs><bs><bs><bs><bs><bs><bs><bs><bs><bs><bs><bs><bs><bs><bs><bs><bs><bs><bs><bs><bs><bs><bs><bs><bs><bs><bs><bs><bs><bs><bs><bs><bs><bs><bs><bs><bs><bs><bs><bs><bs><bs><bs><bs><bs><bs><bs><bs><bs><bs><bs><bs><bs><bs><bs><bs><bs><bs><bs><bs><bs><bs><bs><bs><bs><bs><bs><bs><bs><bs><bs><bs><bs><bs><bs><bs><bs><bs><bs><bs><bs><bs><bs><bs><bs><bs>", " auto=true url=http://{{ .HTTPIP }}:{{ .HTTPPort }}/preseed.cfg priority=critical", "<enter>", "<leftCtrlOn>x<leftCtrlOff>"]
    http_content        = local.data_source_content
}

build {
    sources = ["source.proxmox-iso.kali-tpl"]

    provisioner "ansible" {
    user          = var.ssh_user
    playbook_file = "${path.cwd}/${var.ansible_provisioner_playbook_path}"
    extra_arguments = [
      "--scp-extra-args", "'-O'", // Added to include work around https://github.com/hashicorp/packer/issues/11783#issuecomment-1137052770
      "--extra-vars", "build_key='${var.build_key}'"
    ]
    ansible_env_vars = [
      "ANSIBLE_CONFIG=${path.cwd}/ansible.cfg",
      "ANSIBLE_PYTHON_INTERPRETER=/usr/bin/python3",
      "ANSIBLE_PASSWORD=${var.build_passwd_local}",
      "ANSIBLE_BECOME_PASS=${var.build_passwd_local}"
    ]
  }
}
