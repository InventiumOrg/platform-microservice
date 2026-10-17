# platform-microservice

The centralized Helm chart for Inventium platform microservices. One chart,
versioned and published once; every service supplies only a values file.

Renders: `Deployment`, `Service`, `ConfigMap`, `Secret`, `ServiceAccount`,
`HorizontalPodAutoscaler`, `PodDisruptionBudget`, Gateway API `HTTPRoute` or a
plain `Ingress`, and an optional OpenTelemetry collector sidecar with its config.

- [Quick start](#quick-start)
- [How services consume it](#how-services-consume-it)
- [Values reference](#values-reference)
- [Publishing a new chart version](#publishing-a-new-chart-version)
- [Migrating a service](./MIGRATION.md)
- [Testing changes locally](./INSTRUCTION.md)

## Requirements

- Kubernetes 1.25+ (`autoscaling/v2`, `policy/v1`, Gateway API `v1`)
- Helm 3.8+ (OCI registry support)
- Gateway API CRDs installed when `httproute.enabled=true`

## Quick start

The only required value is `image.repository`. Everything else has a default.

```bash
helm upgrade --install inventory-service \
  oci://596484148719.dkr.ecr.ap-southeast-1.amazonaws.com/inventium/charts/platform-microservice \
  --version 2.0.0 \
  --namespace inventory-service --create-namespace \
  -f values/base.yaml -f values/dev.yaml \
  --set image.tag="$BUILD_TAG"
```

Object names come from `nameOverride`, falling back to the release name — so a
release named `inventory-service` produces `inventory-service`,
`inventory-service-config` and `inventory-service-secrets`, exactly as the
per-service charts did before. Set `nameOverride` explicitly when the release
name differs from the service name.

## How services consume it

### Values only (recommended)

The service repo keeps no templates — only values files, typically a
`values/base.yaml` plus one overlay per environment. A worked example for
`inventory-service` is in
[`examples/inventory-service/values/`](./examples/inventory-service/values/).

```bash
helm upgrade --install inventory-service \
  oci://<registry>/inventium/charts/platform-microservice --version 2.0.0 \
  -f values/base.yaml -f values/prod.yaml
```

### Wrapper chart

For a service that also needs objects this chart does not render (a CronJob, an
ExternalSecret, a custom CR), declare this chart as a dependency and keep the
extra templates alongside it. See
[`examples/wrapper-chart/`](./examples/wrapper-chart/). Values for the shared
chart nest under its name:

```yaml
platform-microservice:
  image:
    repository: ...
```

Always pin `version:` in `Chart.yaml` / `--version`. Never track `main`.

## Values reference

### Naming and metadata

| Parameter | Description | Default |
| --- | --- | --- |
| `nameOverride` | Service name used for object names | `""` (release name) |
| `fullnameOverride` | Replaces the computed name entirely | `""` |
| `namespace` | Namespace for every object | `""` (release namespace) |
| `commonLabels` | Labels added to every object | `{}` |
| `commonAnnotations` | Annotations added to every object | `{}` |

### Workload

| Parameter | Description | Default |
| --- | --- | --- |
| `replicaCount` | Replicas (ignored when autoscaling is on) | `1` |
| `revisionHistoryLimit` | ReplicaSets kept for rollback | `10` |
| `strategy` | Deployment update strategy | `{}` |
| `image.repository` | **Required.** Image repository | `""` |
| `image.tag` | Image tag; also the `app.kubernetes.io/version` label | `""` (chart `appVersion`) |
| `image.pullPolicy` | Image pull policy | `IfNotPresent` |
| `imagePullSecrets` | Pull secrets; accepts a string, a list of strings, or `[{name: ...}]` | `[]` |
| `serviceAccount.create` | Create a ServiceAccount | `false` |
| `serviceAccount.automount` | Mount the SA token | `false` |
| `serviceAccount.annotations` | SA annotations (e.g. IRSA role) | `{}` |
| `serviceAccount.name` | SA name to use | `""` |
| `podAnnotations` / `podLabels` | Pod metadata | `{}` |
| `podSecurityContext` / `securityContext` | Pod and container security contexts | `{}` |
| `command` / `args` | Override the container entrypoint | `[]` |
| `rollOnConfigChange` | Add config checksums to pod annotations so pods roll when config changes | `true` |
| `terminationGracePeriodSeconds` | Graceful shutdown window | `30` |
| `priorityClassName` | Pod priority class | `""` |
| `lifecycle` | Container lifecycle hooks | `{}` |
| `initContainers` / `extraContainers` | Extra containers, rendered as-is | `[]` |

### Service and networking

| Parameter | Description | Default |
| --- | --- | --- |
| `service.enabled` | Render a Service | `true` |
| `service.type` | Service type | `ClusterIP` |
| `service.port` | Primary port; also the container port and route backend port | `8080` |
| `service.name` | Name of the primary port, referenced by the probes | `http` |
| `service.annotations` | Service annotations | `{}` |
| `service.extraPorts` | Additional service ports (gRPC, metrics) | `[]` |
| `extraContainerPorts` | Additional container ports | `[]` |
| `httproute.enabled` | Render a Gateway API HTTPRoute | `false` |
| `httproute.gateway.name` / `.namespace` / `.sectionName` | Gateway to attach to (name required when enabled) | `""` |
| `httproute.hostnames` | Route hostnames | `[]` |
| `httproute.annotations` / `.labels` | Route metadata | `{}` |
| `httproute.cors.enabled` | Append a CORS filter to every rule; all other `cors` keys pass through | `false` |
| `httproute.rules` | Rules; each may set `name`, `matches`, `filters`, `timeouts`, `backendRefs` | PathPrefix `/` |
| `ingress.enabled` | Render a plain Ingress instead | `false` |
| `ingress.className` / `.annotations` / `.hosts` / `.tls` | Standard Ingress fields | see `values.yaml` |

### Resources, probes and scaling

| Parameter | Description | Default |
| --- | --- | --- |
| `resources` | Requests and limits | `500m`/`512Mi` limits, `250m`/`256Mi` requests |
| `livenessProbe` | Liveness probe, rendered as-is | `GET /healthz` on `http`, delay 30s |
| `readinessProbe` | Readiness probe, rendered as-is | `GET /readyz` on `http`, delay 5s |
| `startupProbe` | Startup probe; empty disables it | `{}` |
| `autoscaling.enabled` | Create an HPA | `false` |
| `autoscaling.minReplicas` / `.maxReplicas` | HPA bounds | `1` / `100` |
| `autoscaling.targetCPUUtilizationPercentage` | CPU target | `80` |
| `autoscaling.targetMemoryUtilizationPercentage` | Memory target | unset |
| `autoscaling.metrics` / `.behavior` | Extra HPA metrics and scaling behavior | `[]` / `{}` |
| `podDisruptionBudget.enabled` | Create a PDB | `false` |
| `podDisruptionBudget.minAvailable` / `.maxUnavailable` | PDB target (set one) | `1` / unset |
| `nodeSelector` / `tolerations` / `affinity` / `topologySpreadConstraints` | Scheduling | empty |

### Configuration and secrets

| Parameter | Description | Default |
| --- | --- | --- |
| `config` | Non-sensitive key/value pairs → ConfigMap, loaded with `envFrom` | `{}` |
| `secrets` | Sensitive key/value pairs → Secret, loaded with `envFrom` | `{}` |
| `existingConfigMaps` | Names of ConfigMaps managed elsewhere, loaded with `envFrom` | `[]` |
| `existingSecrets` | Names of Secrets managed elsewhere, loaded with `envFrom` | `[]` |
| `env` | Explicit env entries, rendered as-is (`valueFrom`, field refs) | `[]` |
| `extraEnvFrom` | Extra `envFrom` entries, rendered as-is | `[]` |
| `secretFiles.enabled` | Mount files from a Secret (e.g. a Kafka CA bundle) | `false` |
| `secretFiles.files` | `filename: content` map rendered into a Secret | `{}` |
| `secretFiles.existingSecret` | Mount this Secret instead of creating one | `""` |
| `secretFiles.mountPath` | Where the files are mounted | `/etc/secrets` |
| `configMount.enabled` / `.mountPath` | Also mount `config` as files | `false` / `/etc/config` |
| `volumes` / `volumeMounts` | Extra volumes and mounts on the main container | `[]` |

Keys in `config` and `secrets` become environment variable names verbatim, so
use `UPPER_SNAKE_CASE`. Do not commit real credentials: keep them in a Secret
managed outside the chart and list it in `existingSecrets`, or pass them at
deploy time with `--set-file`/`--set`.

### Observability

The OpenTelemetry collector sidecar tails the app's log file, receives OTLP, and
scrapes the app's `/metrics`, then exports to Loki, Tempo and Prometheus.
Endpoints and credentials are read from the sidecar's environment
(`LOKI_URL`, `TEMPO_URL`, `PROMETHEUS_URL`, and the matching `*_USERNAME` /
`*_PASSWORD`), which comes from the same `config`/`secrets`/`existingSecrets` as
the app container.

| Parameter | Description | Default |
| --- | --- | --- |
| `logging.enabled` | Run the collector sidecar | `false` |
| `logging.logPath` | Shared log directory (emptyDir) | `/logs` |
| `logging.format` | `json` enables log parsing operators | `json` |
| `logging.environment` | `deployment.environment` resource attribute | `production` |
| `logging.insecure` | Skip TLS verification on the Tempo exporter | `false` |
| `logging.otelCollector.image` | Collector image | `otel/opentelemetry-collector-contrib:0.93.0` |
| `logging.otelCollector.logLevel` | Collector log level | `info` |
| `logging.otelCollector.debug` | Also export everything to the logging exporter | `false` |
| `logging.otelCollector.resources` | Sidecar resources | `200m`/`256Mi` limits |
| `logging.loki.enabled` | Export logs to Loki (otherwise debug exporter) | `true` |
| `logging.loki.username` | Enables Loki basic auth | `""` |
| `logging.loki.tenantId` | Enables multi-tenant Loki | `""` |
| `logging.tempo.enabled` / `.username` | Traces export and basic auth | `true` / `""` |
| `logging.metrics.enabled` | Export metrics via Prometheus remote write | `false` |
| `logging.metrics.path` / `.scrapeInterval` | App metrics scrape settings | `/metrics` / `30s` |
| `logging.prometheus.username` | Enables Prometheus basic auth | `""` |
| `logging.extraLabels` | Extra resource attributes | `{}` |

`values.schema.json` type-checks every value, so a typo or a wrong type fails at
`helm template` time rather than in the cluster. The chart also fails fast on a
volume without a source, a `secretFiles` block with nothing to mount, a PDB with
both `minAvailable` and `maxUnavailable`, and `maxReplicas < minReplicas`.

## Publishing a new chart version

Chart changes are released once and consumed everywhere, so every change needs a
`version:` bump in `Chart.yaml` (semver: breaking template or value changes are
a major bump).

```bash
# 1. bump version in Chart.yaml, then
helm lint . --set image.repository=example/app
helm package .

# 2. push to the ECR OCI registry
aws ecr get-login-password --region ap-southeast-1 \
  | helm registry login --username AWS --password-stdin 596484148719.dkr.ecr.ap-southeast-1.amazonaws.com
helm push platform-microservice-2.0.0.tgz \
  oci://596484148719.dkr.ecr.ap-southeast-1.amazonaws.com/inventium/charts
```

Create the ECR repository `inventium/charts/platform-microservice` once before
the first push. Tag the git commit with the chart version so a deployed chart
maps back to a commit.

## License

This Helm chart is licensed under the same terms as the services that use it.
