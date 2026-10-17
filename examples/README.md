# Consuming the shared chart

Two patterns, both pinned to a chart version.

## 1. Values only (recommended)

The service repo keeps no templates at all — only values files. See
[`inventory-service/values/`](./inventory-service/values/): a `base.yaml` with
everything environment-independent, plus one overlay per environment.

```bash
helm upgrade --install inventory-service \
  oci://596484148719.dkr.ecr.ap-southeast-1.amazonaws.com/inventium/charts/platform-microservice \
  --version 2.0.0 \
  --namespace inventory-service --create-namespace \
  -f values/base.yaml -f values/dev.yaml \
  --set image.tag="$BUILD_TAG"
```

## 2. Wrapper chart

Use this when the service needs extra objects of its own. See
[`wrapper-chart/`](./wrapper-chart/): a `Chart.yaml` that declares
`platform-microservice` as a dependency, with the shared chart's values nested
under its name. Service-specific templates live in the wrapper's own
`templates/` directory.

```bash
helm dependency update .
helm upgrade --install inventory-service . -f values/dev.yaml
```
