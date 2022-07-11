terraform {
  backend "gcs" {
    prefix  = "apache_hop_template/state"
  }
}
