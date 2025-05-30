#-- IAM ---------------------------------------------------------------------------------

resource "yandex_iam_service_account" "sa" {
  name        = var.yc_service_account_name
  description = "Service account for Yandex Data Processing cluster"
}

resource "yandex_resourcemanager_folder_iam_member" "sa_roles" {
  for_each = toset([
    "iam.serviceAccounts.user",
    "vpc.user",
    "compute.admin",
    "storage.admin",
    "dataproc.editor",
    "dataproc.agent",
    "mdb.dataproc.agent",
  ])

  folder_id = var.yc_folder
  role      = each.key
  member    = "serviceAccount:${yandex_iam_service_account.sa.id}"
}

resource "yandex_iam_service_account_static_access_key" "sa-static-key" {
  service_account_id = yandex_iam_service_account.sa.id
  description        = "Static access key for object storage"
}

#-- netrwork ----------------------------------------------------------------------------

resource "yandex_vpc_network" "network" {
  name = var.yc_network_name
}

resource "yandex_vpc_subnet" "subnet" {
  name           = var.yc_subnet_name
  zone           = var.yc_zone
  network_id     = yandex_vpc_network.network.id
  v4_cidr_blocks = [var.yc_subnet_range]
  route_table_id = yandex_vpc_route_table.route_table.id
}

resource "yandex_vpc_gateway" "nat_gateway" {
  name = var.yc_nat_gateway_name
  shared_egress_gateway {}
}

resource "yandex_vpc_route_table" "route_table" {
  name       = var.yc_route_table_name
  network_id = yandex_vpc_network.network.id

  static_route {
    destination_prefix = "0.0.0.0/0"
    gateway_id         = yandex_vpc_gateway.nat_gateway.id
  }
}

resource "yandex_vpc_security_group" "security_group" {
  name        = var.yc_security_group_name
  description = "Security group for Yandex Data Processing cluster"
  network_id  = yandex_vpc_network.network.id

  ingress {
    protocol       = "ANY"
    description    = "Allow all incoming traffic"
    v4_cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    protocol       = "ANY"
    description    = "Allow all outgoing traffic"
    v4_cidr_blocks = ["0.0.0.0/0"]
  }
}

#--- storage (object) -------------------------------------------------------------------

resource "yandex_storage_bucket" "data_bucket" {
  bucket        = var.yc_bucket_name
  access_key    = yandex_iam_service_account_static_access_key.sa-static-key.access_key
  secret_key    = yandex_iam_service_account_static_access_key.sa-static-key.secret_key
  force_destroy = true
}

#--- dataproc (spark-cluster) -----------------------------------------------------------

resource "yandex_dataproc_cluster" "dataproc_cluster" {
  depends_on  = [yandex_resourcemanager_folder_iam_member.sa_roles]
  bucket      = yandex_storage_bucket.data_bucket.bucket
  description = "Yandex Data Processing cluster"
  name        = var.yc_dataproc_cluster_name
  labels = {
    created_by = "terraform"
  }
  service_account_id = yandex_iam_service_account.sa.id
  zone_id            = var.yc_zone
  security_group_ids = [yandex_vpc_security_group.security_group.id]


  cluster_config {
    version_id = var.yc_dataproc_version

    hadoop {
      services = ["HDFS", "YARN", "SPARK", "HIVE", "TEZ"]
      properties = {
        "yarn:yarn.resourcemanager.am.max-attempts" = 5
      }
      ssh_public_keys = [file(var.public_key_path)]
    }

    subcluster_spec {
      name = "master"
      role = "MASTERNODE"
      resources {
        resource_preset_id = var.dataproc_master_resources.resource_preset_id
        disk_type_id       = var.dataproc_master_resources.disk_type_id
        disk_size          = var.dataproc_master_resources.disk_size
      }
      subnet_id        = yandex_vpc_subnet.subnet.id
      hosts_count      = 1
      assign_public_ip = true
    }

    subcluster_spec {
      name = "data"
      role = "DATANODE"
      resources {
        resource_preset_id = var.dataproc_data_resources.resource_preset_id
        disk_type_id       = var.dataproc_data_resources.disk_type_id
        disk_size          = var.dataproc_data_resources.disk_size
      }
      subnet_id   = yandex_vpc_subnet.subnet.id
      hosts_count = 3
    }

  }
}

#--- proxy (compute) --------------------------------------------------------------------

resource "yandex_compute_disk" "boot_disk" {
  name     = "boot-disk"
  zone     = var.yc_zone
  image_id = var.yc_image_id
  size     = 30
}

resource "yandex_compute_instance" "proxy" {
  name                      = var.yc_instance_name
  allow_stopping_for_update = true
  platform_id               = "standard-v3"
  zone                      = var.yc_zone
  service_account_id        = yandex_iam_service_account.sa.id

  metadata = {
    ssh-keys = "ubuntu:${file(var.public_key_path)}"
    user-data = templatefile("${path.root}/scripts/proxy_node_setting.sh", {
      access_key        = yandex_iam_service_account_static_access_key.sa-static-key.access_key
      secret_key        = yandex_iam_service_account_static_access_key.sa-static-key.secret_key
      dst_bucket        = yandex_storage_bucket.data_bucket.bucket
      src_bucket        = var.yc_public_bucket_name
      token             = var.yc_token
      cloud             = var.yc_cloud
      folder            = var.yc_folder
      ssh_private_key   = file(var.private_key_path)
      hdfs_dir          = var.hdfs_directory_name
    })
  }

  scheduling_policy {
    preemptible = true
  }

  resources {
    cores  = 2
    memory = 16
  }

  boot_disk {
    disk_id = yandex_compute_disk.boot_disk.id
  }

  network_interface {
    subnet_id = yandex_vpc_subnet.subnet.id
    nat       = true
  }

  metadata_options {
    gce_http_endpoint = 1
    gce_http_token    = 1
  }

  connection {
    type        = "ssh"
    user        = "ubuntu"
    private_key = file(var.private_key_path)
    host        = self.network_interface[0].nat_ip_address
  }

  depends_on = [yandex_dataproc_cluster.dataproc_cluster]
}
