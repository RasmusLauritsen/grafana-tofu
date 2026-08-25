# Grafana OSS Service Account Permissions

This document compares the three practical role combinations for team service
accounts in this Grafana OSS setup.

## Summary

| Option | Organization role | Own folder ACL | Dashboard isolation | Alert isolation |
|---|---|---|---|---|
| 1 | Viewer | View | Read-only everywhere | No alert management |
| 2 | Viewer | Edit | Writes limited to own folder | No alert management |
| 3 | Editor | Edit | Own folder protected by ACLs, root writable | No isolation between team alerts |

Legend:

| Value | Meaning |
|---|---|
| Yes | Operation is allowed |
| No (`403`) | Operation is denied |
| N/A | Grafana-managed alerts must belong to a folder; there is no equivalent root alert location |

## Option 1: Viewer on organization, View on team folder

This is a fully read-only service account.

### Dashboards

| Operation | Own team folder | Other team folder | Root/General |
|---|---:|---:|---:|
| Create | No (`403`) | No (`403`) | No (`403`) |
| Edit | No (`403`) | No (`403`) | No (`403`) |
| Delete | No (`403`) | No (`403`) | No (`403`) |

### Alerts

| Operation | Own team folder | Other team folder | Root/General |
|---|---:|---:|---:|
| Create | No (`403`) | No (`403`) | N/A |
| Edit | No (`403`) | No (`403`) | N/A |
| Delete | No (`403`) | No (`403`) | N/A |

### Risks

| Risk | Impact |
|---|---|
| Datasource access | The service account can query any datasource it can see |
| Information exposure | It can view dashboards and alerts in folders where Viewer has access |
| No automation writes | It cannot manage dashboards or alerts for its own team |

## Option 2: Viewer on organization, Edit on team folder

This is the least-privilege option for team-managed dashboards. It is the
configuration previously tested with `local-sales`.

### Dashboards

| Operation | Own team folder | Other team folder | Root/General |
|---|---:|---:|---:|
| Create | Yes (`201`, verified) | No (`403`, verified) | No (`403`) |
| Edit | Yes | No (`403`) | No (`403`) |
| Delete | Yes | No (`403`) | No (`403`) |

### Alerts

| Operation | Own team folder | Other team folder | Root/General |
|---|---:|---:|---:|
| Create | No (`403`, verified) | No (`403`, verified) | N/A |
| Edit | No (`403`) | No (`403`) | N/A |
| Delete | No (`403`) | No (`403`) | N/A |

Folder `Edit` grants dashboard management but does not grant
`alert.rules:create`, alert editing, or alert deletion.

### Risks

| Risk | Impact |
|---|---|
| Datasource access | The service account can query any datasource it can see |
| Cross-team visibility | It can view other folders unless Viewer access is removed |
| Alert dependency | Alerts must be provisioned by a privileged central identity |
| Privileged workflow | A compromised central provisioning token can affect all teams |

## Option 3: Editor on organization, Edit on team folder

This enables team-managed dashboards and alerts, but alert permissions are not
isolated by the folder dashboard ACLs.

### Dashboards

| Operation | Own team folder | Other team folder | Root/General |
|---|---:|---:|---:|
| Create | Yes | No (`403`) when Editor role has explicit View ACL | Yes |
| Edit | Yes | No (`403`) when Editor role has explicit View ACL | Yes |
| Delete | Yes | No (`403`) when Editor role has explicit View ACL | Yes |

The OpenTofu configuration explicitly gives the organization `Editor` role
only `View` permission in each managed team folder, then grants the matching
team and service account `Edit`. This protects known team folders, but Editors
remain able to write in root and may write in future folders before restrictive
ACLs are applied.

### Alerts

| Operation | Own team folder | Other team folder | Root/General |
|---|---:|---:|---:|
| Create | Yes (`201`, verified) | Likely yes; broad Editor alert permission | N/A |
| Edit | Yes | Yes | N/A |
| Delete | Yes | Yes (`204`, verified both directions) | N/A |

Measured cross-team test:

| Test | HTTP result |
|---|---:|
| Sales created alert in Sales | `201 Created` |
| Accounting created alert in Accounting | `201 Created` |
| Accounting deleted Sales alert | `204 No Content` |
| Sales deleted Accounting alert | `204 No Content` |
| Deleted rules after test | `404 Not Found` |

### Risks

| Risk | Impact |
|---|---|
| Cross-team alert deletion | Verified: either team can delete the other team's alerts |
| Cross-team alert editing | Editor alert permissions are organization-wide rather than folder-isolated |
| Root dashboard writes | Editors can create, edit, and delete dashboards in General/root |
| Future folders | New folders may be writable until restrictive ACLs are applied |
| Token compromise | Attacker gains broad dashboard and alert write access |
| ACL drift | A missing or manually changed folder ACL can expose team dashboards |

## OSS Options

| Requirement | Recommended option |
|---|---|
| Read-only automation | Option 1: Viewer plus View |
| Team manages dashboards, alerts managed centrally | Option 2: Viewer plus folder Edit |
| Team directly manages dashboards and alerts; cross-team alert risk accepted | Option 3: Editor plus folder Edit |
| Team directly manages alerts with real isolation | Separate Grafana organizations or instances |

For folder-isolated dashboards, Option 2 is safest. For direct alert management
in one shared Grafana OSS organization, Option 3 works but does not isolate
alerts between teams.

Do not commit service-account tokens, generated `tokens.md`, OpenTofu state, or
privileged provisioning credentials.
