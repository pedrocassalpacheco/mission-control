variable "gcp_project" {
  description = "GCP project to deploy to"
  type = string
}

variable "gcp_region" {
  description = "GCP region to deploy to"
  type = string
}

variable "gcp_zone" {
  description = "GCP zone to deploy to"
  type = string
}

variable "gcp_network" {
  description = "GCP network to deploy to"
  type = string
}

variable "prefix" {
  description = "Resource name prefix to avoid conflicts"
  type = string
}

variable "platform_instance_type" {
  description = "Instance type for platform nodes"
  type = string
  default = "n2d-standard-8"
}

variable "database_instance_type" {
  description = "Instance type for database nodes"
  type = string
  default = "n2d-standard-32"
}