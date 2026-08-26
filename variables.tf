variable "grafana_url" {
  description = "URL of the local Grafana instance."
  type        = string
  default     = "http://localhost:3000"
}

variable "grafana_admin_user" {
  description = "Grafana admin user for local OpenTofu provisioning."
  type        = string
  default     = "admin"
}

variable "grafana_admin_password" {
  description = "Grafana admin password for this disposable local environment."
  type        = string
  sensitive   = true
  default     = "password"
}

variable "mimir_url" {
  description = "Mimir Prometheus-compatible query endpoint reachable by Grafana."
  type        = string
  default     = "http://192.168.50.25:9009/prometheus"
}
