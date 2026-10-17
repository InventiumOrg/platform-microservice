# Migrating a service onto the shared chart

Every service repo (`platform-inventory-service`, `platform-order-service`,
`platform-warehouse-service`, `platform-sale-service`, `platform-pos-service`,
`platform-recipe-service`, `platform-inventory-transaction-service`, …)
currently carries its own copy of these templates, differing only in the helper
prefix. Migration deletes that copy and keeps the values files.

Object names are unchanged as long as the release name equals the service name
(or `nameOverride` is set to it), so this is an in-place upgrade, not a
redeploy.

## Steps

1. **Delete** `templates/` and `Chart.yaml` from the service repo. Keep
   `values/`.

2. **Point the deploy at the shared chart.** Wherever the pipeline runs
   `helm upgrade ... .`, replace the local path:

   ```bash
   helm upgrade --install inventory-service \
     oci://596484148719.dkr.ecr.ap-southeast-1.amazonaws.com/inventium/charts/platform-microservice \
     --version 2.0.0 \
     --namespace inventory-service \
     -f values/<env>/values.yaml \
     --set image.tag="$BUILD_TAG"
   ```

   If the release name differs from the service name, add
   `--set nameOverride=inventory-service` to keep object names stable.

3. **Apply the value changes below.**

4. **Diff before deploying.** This shows exactly what the upgrade will change in
   the cluster:

   ```bash
   helm template inventory-service \
     oci://.../platform-microservice --version 2.0.0 \
     -f values/<env>/values.yaml | kubectl diff -f -
   ```

## Value changes

| Old | New | Why |
| --- | --- | --- |
| `volumes: [{name: kafka-ca-cert}]` (no source) | `secretFiles.enabled: true` + `secretFiles.files."ca.pem"`, or a complete volume definition | The old chart ignored `volumes` and hardcoded a `kafka-ca-cert` volume backed by `<name>-kafka-ca`. `volumes` is now actually rendered, so a sourceless entry is rejected. |
| `kafkaCaCert: \|` (unused by the templates) | `secretFiles.files."ca.pem"` | The CA bundle now has a real home; point `KAFKA_CA_FILE_PATH` at `<secretFiles.mountPath>/ca.pem`. |
| `secrets: {dbSource: ..., clerkKey: ...}` | `secrets: {DB_SOURCE: ..., CLERK_KEY: ...}` or `existingSecrets: [<name>]` | `secrets` keys are now used verbatim as environment variable names. camelCase keys would produce `dbSource` in the environment, which the services do not read. |
| An externally created `<service>-secrets` Secret | `existingSecrets: [<service>-secrets]` | The chart no longer loads `<name>-secrets` implicitly. If you keep that Secret and also set `secrets:`, the names collide — rename one. |
| `imagePullSecrets: ecr-registry-secret` | works as-is (also accepts a list) | Normalized by the chart. |
| `ingress:` block with no effect | `httproute:` (Gateway API) or `ingress.enabled: true` | The old chart had `ingress` values but no Ingress template. Both are rendered now, so stale `ingress` values that say `enabled: false` stay inert. |
| `livenessProbe.httpGet.port: 13740` | `port: http` | Optional. Tracks `service.port` so the port appears once. |
| — | `nameOverride: <service-name>` in `values/base.yaml` | Guarantees stable object names regardless of release name. |

## Things to check per service

- **`<service>-secrets` ownership.** If that Secret exists in the cluster and
  was not created by Helm, an upgrade that starts managing it fails with an
  ownership error. Either keep it external (`existingSecrets`) or delete it
  before the first upgrade that defines `secrets:`.
- **The OTel sidecar needs its endpoints.** `LOKI_URL`, `TEMPO_URL` and
  `PROMETHEUS_URL` must be present in the environment the sidecar gets. Set
  `logging.loki.enabled` / `logging.tempo.enabled` to `false` and
  `logging.metrics.enabled: false` in environments where those backends do not
  exist — the collector then falls back to its debug exporter instead of failing
  to start.
- **ServiceAccount token mounting.** The pod now sets
  `automountServiceAccountToken` from `serviceAccount.automount`, which defaults
  to `false`. A service that talks to the Kubernetes API (leader election,
  discovery) needs `serviceAccount.automount: true`.
- **Pod rollout on config change.** `rollOnConfigChange` is on by default, so
  editing `config` now restarts pods on upgrade. That is usually what you want;
  set it to `false` to keep the old behavior.
- **`app.kubernetes.io/version`** now reports `image.tag` rather than the chart
  `appVersion`. Dashboards or selectors that read that label see the image tag.

## Rollback

The chart is pinned by version, so rolling back is `helm rollback <release>` or
re-running the previous `--version`. Nothing in the service repo needs to be
restored.
