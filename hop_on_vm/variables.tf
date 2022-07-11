variable "region" {
  description = "The region for resources and networking"
  type = string
}

variable "project_id" {
  description = "ID for the GCP project"
  type = string
}

variable "project_parent" {
  description = "Organization or folder id for the project"
  type = string
  default = null
}

variable "billing_account" {
  description = "Billing account for the projects/resources"
  type = string
}