# Defines the supported OpenTofu version and the required Grafana provider.
terraform {
  required_version = ">= 1.8.0"

  required_providers {
    grafana = {
      source  = "grafana/grafana"
      version = "~> 4.0"
    }
  }
}
