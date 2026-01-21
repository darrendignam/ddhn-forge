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

variable "iso_url" {
  type    = string
  default = "https://cdimage.debian.org/cdimage/archive/12.8.0/arm64/iso-cd/debian-12.8.0-arm64-netinst.iso"
}

variable "iso_checksum" {
  type    = string
  default = "sha256:b242a2c76375fb0b912afbc31bbf9a4c27276524daeea4e65e3d0da83eee9931"
}

source "qemu" "debian-bookworm-arm64" {
  vm_name          = var.vm_name
  iso_url          = var.iso_url
  iso_checksum     = var.iso_checksum
  output_directory = var.output_directory
  
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
  
  # SSH settings for provisioning
  ssh_username     = "vagrant"
  ssh_password     = "vagrant"
  ssh_timeout      = "45m"
  ssh_port         = 22
  
  # Shutdown command
  shutdown_command = "echo 'vagrant' | sudo -S shutdown -P now"
  
  # Boot command for Debian preseed (ARM64 automated installation)
  boot_wait = "5s"
  boot_command = [
    "<esc><wait>",
    "auto <wait>",
    "console-setup/ask_detect=false <wait>",
    "console-keymaps-at/keymap=us <wait>",
    "debconf/frontend=noninteractive <wait>",
    "debian-installer=en_US.UTF-8 <wait>",
    "fb=false <wait>",
    "install <wait>",
    "kbd-chooser/method=us <wait>",
    "keyboard-configuration/xkb-keymap=us <wait>",
    "locale=en_US.UTF-8 <wait>",
    "netcfg/get_hostname=${var.vm_name} <wait>",
    "netcfg/get_domain=viper.test <wait>",
    "preseed/url=http://{{ .HTTPIP }}:{{ .HTTPPort }}/preseed.cfg <wait>",
    "<enter>"
  ]
  
  # Serve preseed file via HTTP
  http_directory = "http"
  
  # Complete QEMU args override to prevent Packer from adding unsupported -boot once=d
  # ARM64 doesn't support boot device ordering, so we let QEMU use natural boot order
  qemuargs = [
    ["-machine", "type=virt,accel=tcg"],
    ["-cpu", "cortex-a72"],
    ["-smp", "2"],
    ["-m", "4096M"],
    ["-name", "{{ .Name }}"],
    ["-bios", "/usr/share/qemu-efi-aarch64/QEMU_EFI.fd"],
    ["-device", "virtio-net,netdev=user.0"],
    ["-netdev", "user,id=user.0,hostfwd=tcp::{{ .SSHHostPort }}-:22"],
    ["-drive", "file={{ .OutputDir }}/{{ .Name }},if=virtio,cache=writeback,discard=ignore,format=qcow2"],
    ["-drive", "file={{ .ISOPath }},media=cdrom"],
    ["-vnc", "{{ .HTTPIP }}:{{ .VNCPort }}"]
  ]
}

build {
  sources = ["source.qemu.debian-bookworm-arm64"]
  
  # Wait for system to be ready
  provisioner "shell" {
    inline = [
      "echo 'Waiting for ARM64 system to be ready...'",
      "sudo apt-get update"
    ]
  }
  
  # Run Ansible provisioning
  provisioner "ansible" {
    playbook_file = "ansible/packer.yml"
    user = "vagrant"
    extra_arguments = ["-vv"]
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
