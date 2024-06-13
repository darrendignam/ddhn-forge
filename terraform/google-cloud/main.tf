provider "google" {
  project = "opf-viper-cloud"
  credentials = file("google-aim.json")

  region  = "us-central1"
  zone    = "us-central1-a"
}

variable "gce_ssh_pub_key_file" {
  description = "Path to your SSH public key file"
  type        = string
  default     = "~/.ssh/google-cloud-viper.pub" # Set your key path here
}
variable "gce_ssh_user" {
  description = "Path to your SSH public key file"
  type        = string
  default     = "darren"
}

resource "google_compute_instance" "viper_instance" {
  name         = "debian-viper-cloud"
  machine_type = "e2-medium"


  boot_disk {
    initialize_params {
      image = "debian-cloud/debian-11"
      # size  = 20  # Set the desired disk size in gigabytes
    }
  }

  network_interface {
    network = "default"
    access_config {
      // Ephemeral IP will be assigned automatically
    }
  }

  metadata = {
    ssh-keys = "${var.gce_ssh_user}:${file(var.gce_ssh_pub_key_file)}"
  }

  # Establishes connection to be used by all
  # generic remote provisioners (i.e. file/remote-exec)
  connection {
    type     = "ssh"
    user     = "darren"
    private_key = "~/.ssh/google-cloud-viper"
  }

  provisioner "file" {
    source      = "./vm-setup-script.sh"
    destination = "~/vm-setup-script.sh"
  }

  provisioner "remote-exec" {
    inline = [
      "chmod +x ~/vm-setup-script.sh",
      "~/vm-setup-script.sh",
    ]
  }

}







#"/var/lib/locales/supported.d/ and /etc/locale.gen are missing. Is the package \"locales\" installed?"
# sudo apt install locales htop 
# sudo apt install snapd
# sudo snap install novnc
# sudo snap get novnc services
# sudo snap set novnc services.n6082.listen=6082 services.n6082.vnc=localhost:5902
# sudo snap get novnc services

# sudo apt install xfce4 xfce4-goodies
# sudo apt install tightvncserver
# vncserver
# vncserver -kill :1

# sudo nano /etc/systemd/system/vncserver@.service
# sudo systemctl enable vncserver@1
# sudo systemctl start vncserver@1
# # ps -ef | grep vnc
# sudo lsof -i -P | grep vnc
# sudo snap set novnc services.n6082.listen='' services.n6082.vnc=''
# sudo snap get novnc services
# sudo shutdown -r now


# sudo nano /etc/systemd/system/vncserver@.service
    # [Unit]
    # Description=VNC Server on %i
    # After=syslog.target network.target

    # [Service]
    # Type=forking
    # User=darren
    # ExecStartPre=-/usr/bin/vncserver -kill :%i > /dev/null 2>&1
    # ExecStart=/usr/bin/vncserver -depth 24 -geometry 1280x800 :%i
    # ExecStop=/usr/bin/vncserver -kill :%i

    # [Install]
    # WantedBy=multi-user.target

