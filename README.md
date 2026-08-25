# Local Grafana with OpenTofu

Runs Grafana at <http://localhost:3000> with persistent Docker storage and
provisions team resources through OpenTofu.

## Usage

```bash
mise install
make up
```

Grafana credentials:

- User: `admin`
- Password: `password`

These credentials are intentionally insecure and suitable only for a disposable
local environment. Do not expose port 3000 beyond the development machine.

The Mimir datasource defaults to
`http://host.docker.internal:9009/prometheus`. Override it for your environment:

```bash
TF_VAR_mimir_url=http://mimir.example.test:9009/prometheus make up
```

`make up` also creates the gcx `local` context backed by an Admin service
account and writes the Sales and Accounting service-account tokens to the
Git-ignored `tokens.md` file.

## Teams and users

Each file in `teams/` defines one team and its users:

```yaml
name: Sales
users:
  - name: Bob
    login: bob
    email: bob@example.test
    password: password
```

The YAML filename is the stable team key used for folders, service accounts,
and OpenTofu state. User logins must be unique across all team files.

## Lifecycle

```bash
make stop     # Stop Grafana and preserve its volume
make start    # Start Grafana without applying OpenTofu
make up       # Start Grafana, configure gcx, and apply OpenTofu
make reset    # Delete the container, volume, OpenTofu state, and tokens
make restart  # Stop and run the complete setup again
```

Bob and Alice use `password` for this local test instance. Generated service
account tokens and OpenTofu state contain secrets and must not be committed.
