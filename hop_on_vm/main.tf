// Project
module "hop_proj" {
  source          = "github.com/GoogleCloudPlatform/cloud-foundation-fabric//modules/project?ref=v16.0.0"
  billing_account = var.billing_account
  name            = var.project_id
  parent          = var.project_parent
  services        = [
    "dataflow.googleapis.com",
    "monitoring.googleapis.com"
  ]
}

// Bucket for staging data, scripts, etc
module "hop_bucket" {
  source        = "github.com/GoogleCloudPlatform/cloud-foundation-fabric//modules/gcs?ref=v16.0.0"
  project_id    = module.hop_proj.project_id
  name          = module.hop_proj.project_id
  location      = var.region
  storage_class = "STANDARD"
  force_destroy = true
}

// Service accounts
module "hop_vm_sa" {
  source            = "github.com/GoogleCloudPlatform/cloud-foundation-fabric//modules/iam-service-account?ref=v16.0.0"
  project_id        = module.hop_proj.project_id
  name              = "my-hop-vm-sa"
  generate_key      = false
  iam_project_roles = {
    (module.hop_proj.project_id) = [
      "roles/storage.admin",
      "roles/dataflow.worker",
      "roles/monitoring.metricWriter"
    ]
  }
}

module "dataflow_sa" {
  source            = "github.com/GoogleCloudPlatform/cloud-foundation-fabric//modules/iam-service-account?ref=v16.0.0"
  project_id        = module.hop_proj.project_id
  name              = "my-dataflow-sa"
  generate_key      = false
  iam               = {
    "roles/iam.serviceAccountUser" = [
      module.hop_vm_sa.iam_email]
  }
  iam_project_roles = {
    (module.hop_proj.project_id) = [
      "roles/storage.admin",
      "roles/dataflow.worker",
      "roles/monitoring.metricWriter"
    ]
  }
}

// Container for VM
module "hop_container" {
  source  = "terraform-google-modules/container-vm/google"
  version = "~> 2.0"

  container = {
    image          = "apache/hop-web:2.0.1"
    restart_policy = "OnFailure"
  }
}

// Hop VM
module "hop_vm" {
  source                 = "github.com/GoogleCloudPlatform/cloud-foundation-fabric//modules/compute-vm?ref=v16.0.0"
  project_id             = module.hop_proj.project_id
  name                   = "hop-vm"
  instance_type          = "e2-medium"
  service_account        = module.hop_vm_sa.email
  service_account_scopes = [
    "https://www.googleapis.com/auth/cloud-platform"
  ]
  boot_disk              = {
    image = module.hop_container.source_image
    type  = "pd-ssd"
    size  = 10
  }
  metadata               = {
    gce-container-declaration = module.hop_container.metadata_value
  }
  tags                   = [
    "ssh",
    "hop-server"
  ]
  network_interfaces     = [
    {
      network    = module.hop_vpc.self_link
      subnetwork = module.hop_vpc.subnet_self_links["${var.region}/default"]
      nat        = false
      // NAT is already created below for the VPC
      addresses  = {
        internal = "10.1.0.132"
        external = ""
      }
      alias_ips  = null
    }
  ]
  zone                   = "${var.region}-a"
}


// Network
module "hop_vpc" {
  source                = "github.com/GoogleCloudPlatform/cloud-foundation-fabric//modules/net-vpc?ref=v16.0.0"
  project_id            = module.hop_proj.project_id
  name                  = "default"
  subnets               = [
    {
      ip_cidr_range      = "10.1.0.0/24"
      name               = "default"
      region             = var.region
      secondary_ip_range = {}
    }
  ]
  subnet_private_access = {
    "subnet" = true
  }
}

module "hop_firewall" {
  // Default rules for internal traffic + SSH/HTTP/HTTPS access via IAP
  source       = "github.com/GoogleCloudPlatform/cloud-foundation-fabric//modules/net-vpc-firewall?ref=v16.0.0"
  project_id   = module.hop_proj.project_id
  network      = module.hop_vpc.name
  admin_ranges = [
    module.hop_vpc.subnet_ips["${var.region}/default"]
  ]
  custom_rules = {
    hop-server = {
      description          = "Apache Hop Server"
      direction            = "INGRESS"
      action               = "allow"
      sources              = []
      ranges               = ["35.235.240.0/20"]
      targets              = [
        "hop-server"]
      use_service_accounts = false
      rules                = [
        {
          protocol = "tcp",
          ports    = [
            8080
          ]
        }
      ]
      extra_attributes     = {}
    }
  }
}

module "hop_nat" {
  // So we can get to Internet if necessary
  source         = "github.com/GoogleCloudPlatform/cloud-foundation-fabric//modules/net-cloudnat?ref=v16.0.0"
  project_id     = module.hop_proj.project_id
  region         = var.region
  name           = "default"
  router_network = module.hop_vpc.self_link
}
