# Connects OpenTofu to the local Grafana instance using administrator credentials.
provider "grafana" {
  url  = var.grafana_url
  auth = "${var.grafana_admin_user}:${var.grafana_admin_password}"
}

locals {
  # Loads each YAML file in teams/ and indexes its contents by filename.
  teams = {
    for team_file in fileset("${path.module}/teams", "*.yaml") :
    trimsuffix(basename(team_file), ".yaml") => yamldecode(file("${path.module}/teams/${team_file}"))
  }

  # Builds a single user map and records which team each user belongs to.
  users = merge([
    for team_key, team in local.teams : {
      for user in team.users : user.login => merge(user, { team_key = team_key })
    }
  ]...)

  # Creates the email-address membership list used by each Grafana team.
  team_members = {
    for team_key, team in local.teams :
    team_key => [for user in team.users : user.email]
  }
}

# Configures the Mimir Prometheus-compatible data source as Grafana's default.
resource "grafana_data_source" "mimir" {
  type        = "prometheus"
  name        = "Mimir"
  uid         = "mimir"
  url         = var.mimir_url
  access_mode = "proxy"
  is_default  = true

  json_data_encoded = jsonencode({
    cacheLevel                    = "High"
    disableRecordingRules         = true
    httpMethod                    = "POST"
    incrementalQueryOverlapWindow = "10m"
    incrementalQuerying           = true
    manageAlerts                  = false
    pdcInjected                   = false
    prometheusType                = "Mimir"
    prometheusVersion             = "2.9.1"
    seriesEndpoint                = false
    timeInterval                  = "1m"
  })
}

# Creates a Grafana user for every user declared in the team YAML files.
resource "grafana_user" "team" {
  for_each = local.users

  name     = each.value.name
  login    = each.value.login
  email    = each.value.email
  password = each.value.password
}

# Grants every declared team user the Editor role in the default organization.
resource "grafana_organization" "main" {
  name         = "Main Org."
  create_users = false
  admin_user   = "admin"
  editors      = [for user in grafana_user.team : user.email]
}

# Creates each Grafana team and assigns its declared users as members.
resource "grafana_team" "team" {
  for_each = local.teams

  name    = each.value.name
  members = local.team_members[each.key]
}

# Creates a Grafana folder for each team.
resource "grafana_folder" "team" {
  for_each = local.teams

  title = each.value.name
}

# Grants standard roles read access and the owning team and service account edit access.
resource "grafana_folder_permission" "team" {
  for_each = local.teams

  folder_uid = grafana_folder.team[each.key].uid

  permissions {
    role       = "Viewer"
    permission = "View"
  }

  permissions {
    role       = "Editor"
    permission = "View"
  }

  permissions {
    team_id    = grafana_team.team[each.key].id
    permission = "Edit"
  }

  permissions {
    user_id    = grafana_service_account.team[each.key].id
    permission = "Admin"
  }
}

# Creates an Editor service account for each team.
resource "grafana_service_account" "team" {
  for_each = local.teams

  name = "${each.key}-service-account"
  role = "Viewer"
}

# Creates an authentication token for each team's service account.
resource "grafana_service_account_token" "team" {
  for_each = local.teams

  name               = "${each.key}-token"
  service_account_id = grafana_service_account.team[each.key].id
}

# Exposes the generated team tokens as a sensitive output value.
output "team_tokens" {
  sensitive = true
  value = {
    for name, token in grafana_service_account_token.team : name => token.key
  }
}
