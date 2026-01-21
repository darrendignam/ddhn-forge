packer {
  required_plugins {
    qemu = {
      version = ">= 1.0.0"
      source  = "github.com/hashicorp/qemu"
    }
    ansible = {
      version = ">= 1.1.0"
      source  = "github.com/hashicorp/ansible"
    }
  }
}

variable "vm_name" {
  type    = string
  default = "viper-v1.2-alpha-arm64"
}

variable "cpus" {
  type    = number
  default = 2
}

variable "memory" {
  type    = number
  default = 4096
}

variable "disk_size" {
  type    = string
  default = "25G"
}

variable "headless" {
  type    = bool
  default = false
}

variable "accelerator" {
  type    = string
  default = "tcg"
  description = "QEMU accelerator (tcg for cross-architecture emulation)"
}

variable "output_directory" {
  type    = string
  default = "output-qemu-arm64"
}

variable "cloud_image_url" {
  type    = string
  default = "https://cloud.debian.org/images/cloud/bookworm/latest/debian-12-generic-arm64.qcow2"
}

variable "cloud_image_checksum" {
  type    = string
  default = "sha256:bd8a96db1f1ac2f47269e1b2041240c48931c137ab6b7d2d5e17b45c5bb23f42"
}

source "qemu" "debian-bookworm-arm64" {
  vm_name          = var.vm_name
  iso_url          = var.cloud_image_url
  iso_checksum     = var.cloud_image_checksum
  iso_target_path  = "packer_cache/debian-12-generic-arm64.qcow2"
  output_directory = var.output_directory
  
  # Use existing disk image instead of installing from ISO
  disk_image       = true
  
  # ARM64 specific QEMU settings
  qemu_binary      = "qemu-system-aarch64"
  machine_type     = "virt"
  cpu_model        = "cortex-a72"
  
  disk_size        = var.disk_size
  disk_interface   = "virtio"
  disk_compression = true
  format           = "qcow2"
  
  cpus             = var.cpus
  memory           = var.memory
  
  headless         = var.headless
  accelerator      = var.accelerator
  
  # Use VNC for display
  vnc_bind_address = "127.0.0.1"
  vnc_port_min     = 5900
  vnc_port_max     = 5900
  
  # Networking
  net_device       = "virtio-net"
  
  # SSH settings for provisioning (cloud image uses 'debian' user by default)
  ssh_username     = "debian"
  ssh_password     = "debian"
  ssh_timeout      = "10m"
  ssh_port         = 22
  
  # Wait for cloud-init to finish before provisioning
  ssh_wait_timeout = "10m"
  
  # Shutdown command
  shutdown_command = "echo 'debian' | sudo -S shutdown -P now"
  
  # Boot wait for cloud-init
  boot_wait = "30s"
  
  # Cloud-init configuration via user-data
  cd_files = ["./cloud-init/"]
  cd_label = "cidata"
  
  # ARM64 UEFI firmware
  qemuargs = [
    ["-bios", "/usr/share/qemu-efi-aarch64/QEMU_EFI.fd"]
  ]
}

build {
  sources = ["source.qemu.debian-bookworm-arm64"]
  
  # Wait for cloud-init and create vagrant user
  provisioner "shell" {
    inline = [
      "echo 'Waiting for cloud-init to complete...'",
      "sudo cloud-init status --wait || true",
      "echo 'Creating vagrant user...'",
      "sudo useradd -m -s /bin/bash vagrant || true",
      "echo 'vagrant:vagrant' | sudo chpasswd",
      "echo 'vagrant ALL=(ALL) NOPASSWD:ALL' | sudo tee /etc/sudoers.d/vagrant",
      "sudo chmod 0440 /etc/sudoers.d/vagrant",
      "sudo apt-get update"
    ]
  }
  
  # Run Ansible provisioning
  provisioner "ansible" {
    playbook_file = "ansible/packer.yml"
    user = "vagrant"
    extra_arguments = ["-vv", "--become"]
  }
  
  # Rename QCOW2 file to include .qcow2 extension
  post-processor "shell-local" {
    inline = [
      "mv ${var.output_directory}/${var.vm_name} ${var.output_directory}/${var.vm_name}.qcow2 || true",
      "echo 'ARM64 QCOW2 file: ${var.output_directory}/${var.vm_name}.qcow2'"
    ]
  }
  
  # Convert to VHDX for Windows ARM
  post-processor "shell-local" {
    inline = [
      "echo 'Converting to VHDX for Windows ARM...'",
      "qemu-img convert -f qcow2 -O vhdx ${var.output_directory}/${var.vm_name}.qcow2 ${var.output_directory}/${var.vm_name}.vhdx",
      "echo 'VHDX file: ${var.output_directory}/${var.vm_name}.vhdx'"
    ]
  }
  
  # Post-processor completion message
  post-processor "shell-local" {
    inline = [
      "echo 'ARM64 build complete.'",
      "echo 'QCOW2 for Apple Silicon/UTM: ${var.output_directory}/${var.vm_name}.qcow2'",
      "echo 'VHDX for Windows ARM/Hyper-V: ${var.output_directory}/${var.vm_name}.vhdx'"
    ]
  }
}
