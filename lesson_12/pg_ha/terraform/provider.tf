terraform {
  required_version = ">= 1.6.0"
  required_providers {
    yandex = {
      source  = "yandex-cloud/yandex"
      version = ">= 0.116.0"
    }
  }
}

provider "yandex" {
  service_account_key_file = "/home/sedunovsv/.config/yandex-cloud/sa_key.json"
  cloud_id  = var.yc_cloud_id
  folder_id = var.yc_folder_id
  zone      = var.yc_zone
}
