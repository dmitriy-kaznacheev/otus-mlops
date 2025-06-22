resource "yandex_storage_bucket" "bucket" {
  bucket        = "${var.name}-fahzeeph"
  access_key    = var.access_key
  secret_key    = var.secret_key
  force_destroy = true
}