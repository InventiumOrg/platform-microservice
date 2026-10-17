# Testing chart changes locally

All commands run from the chart root. `image.repository` is required, so pass a
values file or `--set image.repository=...`.

1. Render with the example values:

   ```bash
   helm template my-release . \
     -f examples/inventory-service/values/base.yaml \
     -f examples/inventory-service/values/local.yaml
   ```

2. Lint (schema + template validation):

   ```bash
   helm lint . --set image.repository=example/app
   helm lint . -f examples/inventory-service/values/base.yaml \
               -f examples/inventory-service/values/prod.yaml
   ```

3. Dry run against a cluster, which also validates the manifests server-side:

   ```bash
   helm install my-release . --dry-run --debug \
     -f examples/inventory-service/values/base.yaml \
     -f examples/inventory-service/values/local.yaml
   ```

4. Diff a change against what a service currently runs — the real safety net
   when changing shared templates:

   ```bash
   helm template inventory-service . -f <service-repo>/values/dev/values.yaml \
     | kubectl diff -f -
   ```

5. Test the wrapper-chart path (`examples/wrapper-chart`) by pointing its
   dependency at this directory:

   ```bash
   cd examples/wrapper-chart
   # repository: "file://../.."
   helm dependency update .
   helm template inventory-service .
   ```

Before opening a PR, render every example environment and every consuming
service's values file. A mistake here breaks every service at once.
