# hedgedoc-kubernetes

Production-ready Helm chart for [HedgeDoc](https://hedgedoc.org) — the open platform for real-time collaborative markdown notes — with OCI release automation and Renovate-driven dependency management.

## Repository Structure

```
hedgedoc-kubernetes/
├── .github/
│   ├── scripts/
│   │   └── bump-chart-version.sh   # Bumps Chart.yaml on image update
│   └── workflows/
│       └── release.yaml            # OCI release pipeline (GHCR)
├── charts/
│   └── hedgedoc/
│       ├── Chart.yaml
│       ├── values.yaml
│       ├── .helmignore
│       └── templates/
│           ├── _helpers.tpl
│           ├── NOTES.txt
│           ├── configmap.yaml      # Non-sensitive CMD_* env vars
│           ├── deployment.yaml
│           ├── httproute.yaml      # Gateway API (Istio)
│           ├── ingress.yaml        # Standard k8s Ingress
│           ├── pvc.yaml            # /hedgedoc/public/uploads
│           ├── secret.yaml         # CMD_DB_URL, CMD_SESSION_SECRET, S3 creds
│           ├── service.yaml
│           └── serviceaccount.yaml
├── renovate.json
└── README.md
```

## Quick Start

### 1. Add dependencies

```bash
helm repo add bitnami https://charts.bitnami.com/bitnami
helm dependency update charts/hedgedoc
```

### 2. Install with internal PostgreSQL

```bash
helm install hedgedoc charts/hedgedoc \
  --namespace hedgedoc --create-namespace \
  --set postgresql.auth.password="change-me-in-production" \
  --set extraEnv.CMD_DOMAIN="notes.example.com" \
  --set extraEnv.CMD_PROTOCOL_USESSL="true"
```

### 3. Install with an external PostgreSQL

```bash
helm install hedgedoc charts/hedgedoc \
  --namespace hedgedoc --create-namespace \
  --set postgresql.enabled=false \
  --set externalDatabase.host="pg.example.com" \
  --set externalDatabase.password="pg-password" \
  --set extraEnv.CMD_DOMAIN="notes.example.com"
```

### 4. Install using pre-existing Secrets (SealedSecrets / ESO)

When `existingSecret` is set the chart creates **no** Secret. Your external
secret must expose:

| Key                    | Description                             |
|------------------------|-----------------------------------------|
| `CMD_DB_URL`           | Full PostgreSQL URL (percent-encode special chars) |
| `CMD_SESSION_SECRET`   | Random string ≥ 32 chars                |
| `CMD_S3_ACCESS_KEY_ID` | (optional) S3 access key                |
| `CMD_S3_SECRET_ACCESS_KEY` | (optional) S3 secret key            |

```bash
helm install hedgedoc charts/hedgedoc \
  --set existingSecret="hedgedoc-externalsecret" \
  --set existingConfigMap="hedgedoc-config"      # optional
```

## Key Features

| Feature | Detail |
|---|---|
| **Deployment** | `apps/v1 Deployment` with non-root `SecurityContext` (UID 1000) |
| **Probes** | Startup (5 min grace), Liveness, Readiness — all via `/status` |
| **Database** | Bitnami/PostgreSQL sub-chart **or** external DB via `externalDatabase.*` |
| **Secret lifecycle** | Session secret preserved across upgrades via `lookup()` |
| **ConfigMap** | All non-sensitive `CMD_*` vars; rolling restart on change via checksum annotation |
| **Uploads** | PVC (`ReadWriteOnce`) auto-disabled when `CMD_IMAGE_UPLOAD_TYPE=s3` |
| **Ingress** | Standard `networking.k8s.io/v1 Ingress` |
| **Gateway API** | `gateway.networking.k8s.io/v1 HTTPRoute` for Istio / Envoy Gateway |
| **GitOps** | `existingSecret` + `existingConfigMap` for SealedSecrets / ExternalSecrets |
| **OCI Release** | GitHub Actions → `helm push` → `ghcr.io/<owner>/hedgedoc:<version>` |
| **Renovate** | Auto-detects image updates; bumps `appVersion` + chart `version` (patch) |

## Networking

### Standard Ingress (cert-manager + nginx)

```yaml
ingress:
  enabled: true
  className: nginx
  annotations:
    cert-manager.io/cluster-issuer: letsencrypt-prod
  hosts:
    - host: notes.example.com
      paths:
        - path: /
          pathType: Prefix
  tls:
    - secretName: hedgedoc-tls
      hosts:
        - notes.example.com
```

### Gateway API / Istio

```yaml
gatewayApi:
  enabled: true
  hostname: notes.example.com
  parentRefs:
    - name: main-gateway
      namespace: istio-system
      group: gateway.networking.k8s.io
      kind: Gateway
```

Both can be enabled simultaneously if required (e.g. during a migration).

## S3 Upload Backend

```yaml
extraEnv:
  CMD_IMAGE_UPLOAD_TYPE: "s3"
  CMD_S3_BUCKET: "hedgedoc-uploads"
  CMD_S3_REGION: "eu-central-1"
  CMD_S3_ENDPOINT: ""   # leave empty for AWS S3

s3:
  accessKeyId: "AKIAIOSFODNN7EXAMPLE"
  secretAccessKey: "wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY"
```

When `CMD_IMAGE_UPLOAD_TYPE` is `"s3"`, the PVC for `/hedgedoc/public/uploads` is **automatically disabled**.

## Installing from GHCR (after first release)

```bash
helm install hedgedoc \
  oci://ghcr.io/<your-github-org>/hedgedoc \
  --version 0.1.0 \
  --namespace hedgedoc --create-namespace \
  -f my-values.yaml
```

## Local Development

Dependencies are **not vendored** in the repository. Before running any Helm
command locally, fetch them first:

```bash
helm repo add bitnami https://charts.bitnami.com/bitnami
helm repo update
helm dependency update charts/hedgedoc
```

The downloaded artifacts (`charts/hedgedoc/charts/`) are gitignored. Lint and
template rendering then work as normal:

```bash
# Lint
helm lint charts/hedgedoc --strict \
  --set postgresql.auth.password="local-test"

# Dry-run template rendering
helm template hedgedoc charts/hedgedoc \
  --set postgresql.auth.password="local-test" \
  > /dev/null
```

## CI/CD

The GitHub Actions workflow (`.github/workflows/release.yaml`) runs on every
push to `main` that touches `charts/**`:

1. `helm dependency update`
2. `helm lint --strict`
3. `helm template` (dry-run)
4. `kind` cluster smoke test (`helm install --wait`)
5. `helm package` + `helm push` → `oci://ghcr.io/<owner>/hedgedoc:<chart-version>`

No external secrets or tokens are needed — `GITHUB_TOKEN` (auto-provisioned)
has `packages: write` permission.

## Renovate Automation

`renovate.json` configures:

- **Helm sub-chart updates** (`helmv3` manager) — detects `bitnami/postgresql` version bumps in `Chart.yaml`.
- **Docker image updates** (custom regex manager) — detects `image.repository` / `image.tag` pairs in `values.yaml`.
- **`postUpgradeTasks`** — after bumping the HedgeDoc image tag, Renovate automatically runs `.github/scripts/bump-chart-version.sh` to update `appVersion` **and** bump the chart `version` (patch).

## Values Reference (selected)

| Key | Default | Description |
|-----|---------|-------------|
| `replicaCount` | `1` | Pod replicas |
| `image.repository` | `quay.io/hedgedoc/hedgedoc` | Container image |
| `image.tag` | `1.9.9` | Image tag |
| `postgresql.enabled` | `true` | Use Bitnami sub-chart |
| `postgresql.auth.password` | `""` | **Required** (non-existingSecret path) |
| `externalDatabase.host` | `""` | External PG host |
| `existingSecret` | `""` | Skip secret creation; use external |
| `existingConfigMap` | `""` | Skip configmap creation; use external |
| `sessionSecret` | `""` | Auto-generated if empty |
| `persistence.enabled` | `true` | Enable uploads PVC |
| `persistence.size` | `10Gi` | PVC size |
| `ingress.enabled` | `false` | Standard Ingress |
| `gatewayApi.enabled` | `false` | HTTPRoute (Gateway API) |
| `s3.accessKeyId` | `""` | S3 access key (→ Secret) |
| `extraEnv.CMD_IMAGE_UPLOAD_TYPE` | `filesystem` | Upload backend |

For the full list of `extraEnv` `CMD_*` variables, see the annotated [`values.yaml`](charts/hedgedoc/values.yaml) and the [official HedgeDoc configuration docs](https://docs.hedgedoc.org/configuration/).
