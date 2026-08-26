# Grafana OSS Service Account Permissions

This document compares the four practical role combinations for team service
accounts in this Grafana OSS setup.

## Summary

| Option | Organization role | Own folder ACL | Dashboard isolation | Alert isolation |
|---|---|---|---|---|
| 1 | Viewer | View | Read-only everywhere | No alert management |
| 2 | Viewer | Edit | Writes limited to own folder | No alert management |
| 3 | Viewer | Admin | Writes limited to own folder | Alerts limited to own folder |
| 4 | Editor | Edit | Own folder protected by ACLs, root writable | No isolation between team alerts |

## Human User Summary

This table summarizes the practical human-user combinations in Grafana OSS.
"Own folder" means a folder where the user receives the listed permission
directly or through team membership. Contact points are organization-scoped, so
the folder permission does not affect them.

| Organization role | Own folder ACL | Root/General dashboards | Own folder dashboards | Other team folders | Alerts | Contact points | Explore/Drilldown |
|---|---|---|---|---|---|---|---|
| Viewer | View | Read only | Read only | Read only | Read only | Read only | No |
| Viewer | Edit | Read only | CRUD | Read only | Read only | Read only | No |
| Viewer | Admin | Read only | CRUD plus ACL management | Read only | CRUD in own folder | Read only | No |
| Editor | View | Writable | Read only | Read only | Organization-wide CRUD | Organization-wide CRUD | Yes |
| Editor | Edit | Writable | CRUD | Read only | Organization-wide CRUD | Organization-wide CRUD | Yes |
| Editor | Admin | Writable | CRUD plus ACL management | Read only | Organization-wide CRUD | Organization-wide CRUD | Yes |

Important consequences:

- Organization `Viewer` plus folder `Edit` is the least-privilege combination
  for users who only need to manage dashboards in their team folder.
- Organization `Viewer` plus folder `Admin` also enables folder-scoped alert
  management, but lets the user change that folder's ACL.
- Organization `Editor` grants broad alert and contact-point management that is
  not constrained by the user's own-folder ACL.
- Other OpenTofu-managed team folders remain read-only because the built-in
  Editor and Viewer roles receive explicit `View` access.
- Explore and Drilldown require organization `Editor` or `Admin`; folder
  permissions do not grant access to these features.
- Organization Editors can create root dashboards and top-level folders. In the
  App Platform API, some root dashboards created by an Editor could not later be
  updated or deleted by that user and required Admin cleanup.

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

## Option 3: Viewer on organization, Admin on team folder

This is the least-privilege option tested that allows a team service account to
manage both dashboards and alerts in its own folder.

### Dashboards

| Operation | Own team folder | Other team folder | Root/General |
|---|---:|---:|---:|
| Create | Yes | No (`403`) | No (`403`) |
| Edit | Yes | No (`403`) | No (`403`) |
| Delete | Yes | No (`403`) | No (`403`) |

### Alerts

| Operation | Own team folder | Other team folder | Root/General |
|---|---:|---:|---:|
| Create | Yes (verified) | No (`403`) | N/A |
| Edit | Yes (verified) | No (`403`) | N/A |
| Delete | Yes (verified) | No (`403`) | N/A |

The Sales service account created, updated, and deleted an alert rule while it
had organization `Viewer` and folder `Admin`. Folder `Admin`, unlike folder
`Edit`, grants the required alert-rule permissions without making the service
account an organization Editor.

### Current Sales service account permissions

The following matrix was verified on Grafana OSS 13.2.0 using
`sa-1-sales-service-account`, which has organization `Viewer` and `Admin` on the
Sales folder. These results use Grafana HTTP APIs directly.

| Resource | Create | Read | Update | Delete |
|---|---:|---:|---:|---:|
| Folders | No (`403`) | Yes (`200`) | Own folder: Yes (`200`) | No (`403`) |
| Folder ACLs | N/A | Yes | Own folder: Yes (`200`) | N/A |
| Users | No (`403`) | No (`403`) | No (`403`) | No (`403`) |
| Dashboards in Sales | Yes (`200`) | Yes (`200`) | Yes (`200`) | Yes (`200`) |
| Alerts in Sales, App Platform API | Yes (`201`) | Yes (`200`) | Yes (`200`) | Yes (`200`) |
| Alerts, deprecated provisioning API | No (`403`) | Existing rules only | No (`403`) | No (`403`) |
| Service accounts | No (`403`) | No (`403`) | No (`403`) | No (`403`) |
| Contact points | No (`403`) | Yes | No (`403`) | No (`403`) |
| Datasources | No (`403`) | Yes (`200`) | No (`403`) | No (`403`) |
| Teams | No (`403`) | No (`403`) | No (`403`) | No (`403`) |
| Notification policy | N/A | Yes (`200`) | No (`403`) | No (`403`) |

The modern App Platform alert endpoint is
`/apis/rules.alerting.grafana.app/v0alpha1`. It honors folder `Admin` for alert
CRUD. The deprecated `/api/v1/provisioning/alert-rules` endpoint additionally
requires provisioning permissions and returns `403` for the same identity.

Folder `Admin` is more powerful through the HTTP API than the earlier gcx test
suggested. The service account can rename its folder and replace its ACL. It can
therefore delegate `Admin` to another user or team within that folder. OpenTofu
restores the intended ACL on its next apply, but does not prevent temporary ACL
changes between applies.

### Risks

| Risk | Impact |
|---|---|
| Datasource access | The service account can query any datasource it can see |
| Cross-team visibility | It can view other folders unless Viewer access is removed |
| Folder administration | It can manage dashboards and alert rules in its folder |
| Contact-point dependency | Contact points still require a privileged central identity |

## Option 4: Editor on organization, Edit on team folder

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

## Contact Points

Contact points are organization-scoped, not folder-scoped. Folder permission
therefore does not change whether a service account can create, update, or
delete them.

| Organization role | Folder permission | Read | Create | Edit | Delete |
|---|---|---:|---:|---:|---:|
| Viewer | View | Yes | No (`403`) | No (`403`) | No (`403`) |
| Viewer | Edit | Yes | No (`403`) | No (`403`) | No (`403`) |
| Viewer | Admin | Yes (verified) | No (`403`, verified) | No (`403`, verified) | No (`403`, verified) |
| Editor | Edit | Yes | Yes | Yes | Yes |
| Admin | N/A | Yes | Yes (verified) | Yes (verified) | Yes (verified) |

The Viewer tests returned missing `alert.notifications.receivers:create`,
`alert.notifications.receivers:write`, and
`alert.notifications.receivers:delete` permissions. Because contact points are
shared across the organization, use a central privileged identity to provision
them when team service accounts remain Viewers.

## Human Editor API and CLI Verification

The following tests used Bob, an organization `Editor` and Sales team member.
The built-in Editor role has `View` on managed team folders, while the Sales team
has `Edit` on Sales.

### Direct HTTP API

| Resource or operation | Result |
|---|---|
| Sales dashboards | Full CRUD (`200`) |
| Accounting dashboard create | Denied (`403`) |
| Root dashboard create | Allowed (`200`) |
| Folder create | Allowed (`200`), but the new folder immediately becomes read-only under the explicit Editor `View` ACL model |
| Managed folder rename | Allowed (`200`) |
| Sales folder ACL update | Denied (`403`) |
| Sales alert CRUD | Allowed (`201`/`200`/`200`/`204`) |
| Users | Full CRUD denied (`403`) |
| Service accounts | Full CRUD denied (`403`) |
| Datasources | Read allowed; create, update, and delete denied (`403`) |
| Teams | Full CRUD denied (`403`) |
| Contact points | Create, update, and delete allowed (`202`) |
| Notification policy | Read and reset allowed; update reached validation (`400`), proving authorization succeeded |

### gcx CLI

| Resource or operation | Result |
|---|---|
| Sales dashboard create, update, delete | Allowed |
| Accounting dashboard create | Denied (`403`) |
| Root dashboard create | Allowed |
| Root dashboard update and delete | Denied (`403`) after creation; Admin cleanup required |
| Folder create, update, delete | Allowed for the folder created through gcx |
| Sales alert create, update, delete | Allowed |
| Contact point create, update, delete | Allowed |

gcx uses the App Platform APIs for dashboards, folders, and alert rules, so its
authorization behavior can differ from deprecated provisioning endpoints. The
CLI does not bypass Grafana permissions, but it can expose capabilities that are
easy to miss when testing only legacy APIs.

### Human Editor risks

| Risk | Impact |
|---|---|
| Root dashboard writes | Editors can create dashboards outside managed team folders |
| Orphaned root resources | Some App Platform-created root dashboards cannot be changed by their creator and require Admin cleanup |
| Folder creation | Editors can create unmanaged folders before OpenTofu applies restrictive ACLs |
| Organization-wide alerts | Editors can manage Grafana alert rules beyond their team folder through broad organization permissions |
| Notification administration | Editors can manage shared contact points and reset the organization notification policy |
| Shared datasource queries | Editors can query all visible datasources, although they cannot administer them |

## OSS Options

| Requirement | Recommended option |
|---|---|
| Read-only automation | Option 1: Viewer plus View |
| Team manages dashboards, alerts managed centrally | Option 2: Viewer plus folder Edit |
| Team manages dashboards and folder-isolated alerts | Option 3: Viewer plus folder Admin |
| Team directly manages organization-wide notification resources | Option 4: Editor plus folder Edit |
| Strong isolation for notification resources | Separate Grafana organizations or instances |

For folder-isolated dashboards and alerts, Option 3 is the least-privilege
combination tested. Contact points remain organization-scoped, so they need
central provisioning or a broader organization role.

Do not commit service-account tokens, generated `tokens.md`, OpenTofu state, or
privileged provisioning credentials.
