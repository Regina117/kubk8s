terraform {
  required_providers {
    yandex = {
      source = "yandex-cloud/yandex"
    }
  }
  required_version = ">= 0.13"
}

provider "yandex" {
  token     = "${var.yc_token}"
  cloud_id  = "${var.yc_cloud_id}"
  folder_id = "${var.yc_folder_id}"
  zone      = "ru-central1-d"
}

# Создаем сеть
resource "yandex_vpc_network" "k8s_network" {
  name = "k8s-network"
}

# Создаем подсеть
resource "yandex_vpc_subnet" "k8s_subnet" {
  name           = "k8s-subnet"
  zone           = "ru-central1-d"
  network_id     = yandex_vpc_network.k8s_network.id
  v4_cidr_blocks = ["10.0.0.0/24"]
}

# Создаем группу безопасности
resource "yandex_vpc_security_group" "k8s_sg" {
  name        = "k8s-security-group"
  network_id  = yandex_vpc_network.k8s_network.id
  description = "Security group for Kubernetes cluster"

  # Разрешаем SSH
  ingress {
    protocol       = "TCP"
    port          = 22
    v4_cidr_blocks = ["0.0.0.0/0"]
  }

  # Разрешаем Kubernetes порты
  ingress {
    protocol       = "TCP"
    port          = 6443
    v4_cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    protocol       = "TCP"
    port          = 10250
    v4_cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    protocol       = "TCP"
    port          = 25000
    v4_cidr_blocks = ["0.0.0.0/0"]
  }

  # Разрешаем весь внутренний трафик внутри сети
  ingress {
    protocol       = "ANY"
    v4_cidr_blocks = ["10.0.0.0/24"]
  }

  # Разрешаем исходящий трафик
  egress {
    protocol       = "ANY"
    v4_cidr_blocks = ["0.0.0.0/0"]
  }
}

# Шаблон для всех нод
resource "yandex_compute_instance" "k8s_nodes" {
  count       = 4
  name        = count.index == 0 ? "master" : "worker-${count.index}"
  platform_id = "standard-v2"

  resources {
    cores  = 2
    memory = 4
  }

  boot_disk {
    initialize_params {
      image_id = "fd8421uec874p44sq4j3"
      size     = 20
    }
  }

  network_interface {
    subnet_id          = yandex_vpc_subnet.k8s_subnet.id
    nat                = true
    security_group_ids = [yandex_vpc_security_group.k8s_sg.id]
  }

  metadata = {
    ssh-keys = "regina:${file("/home/regina/.ssh/id_rsa.pub")}"
    user-data = <<-EOT
      #cloud-config
      hostname: ${count.index == 0 ? "master" : "worker-${count.index}"}
      manage_etc_hosts: true
      users:
        - name: regina
          sudo: ALL=(ALL) NOPASSWD:ALL
          groups: sudo
          ssh_authorized_keys:
            - ${file("/home/regina/.ssh/id_rsa.pub")}
      write_files:
        - path: /home/regina/.ssh/config
          content: |
            Host *
              StrictHostKeyChecking no
              UserKnownHostsFile=/dev/null
              LogLevel=ERROR
          permissions: '0644'
      runcmd:
        - apt update && apt install -y openssh-server
        - systemctl enable ssh
        - systemctl start ssh
    EOT
  }
}

variable "yc_token" {}
variable "yc_cloud_id" {}
variable "yc_folder_id" {}
variable "subnet_id" {}

output "nodes_external_ips" {
  value = { for i, instance in yandex_compute_instance.k8s_nodes : instance.name => instance.network_interface.0.nat_ip_address }
}

output "nodes_internal_ips" {
  value = { for i, instance in yandex_compute_instance.k8s_nodes : instance.name => instance.network_interface.0.ip_address }
}
