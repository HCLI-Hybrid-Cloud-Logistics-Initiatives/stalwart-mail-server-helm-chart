# Stalwart Mail Server Helm Chart

![Version: 0.1.0](https://img.shields.io/badge/Version-0.1.0-informational?style=flat-square) ![Type: application](https://img.shields.io/badge/Type-application-informational?style=flat-square) ![AppVersion: v0.11.8](https://img.shields.io/badge/AppVersion-v0.11.8-informational?style=flat-square)

A production-ready Helm chart for Stalwart Mail Server with multi-profile deployment options for high availability and scalability.

## Introduction

[Stalwart Mail Server](https://stalw.art/) is an open-source mail server solution with SMTP, JMAP, IMAP4, and POP3 support and a wide range of modern features. It's written in Rust and aims to be secure, fast, robust, and scalable.

This Helm chart provides a fully-featured deployment solution for Stalwart Mail Server on Kubernetes with customizable deployment profiles ranging from lightweight demos to production-grade high availability setups.

## Features

- **Multiple Deployment Profiles**: Choose from tiny, small, medium, or large deployment profiles to match your environment
- **High Availability**: True HA with mandatory pod anti-affinity and rolling updates
- **PostgreSQL HA Integration**: Optional high-availability PostgreSQL cluster with Pgpool and Repmgr
- **Redis Coordination**: Optional Redis cluster for coordination in large deployments
- **Comprehensive Security**: Pod Security Standards, network policies, and secure defaults
- **Monitoring Ready**: Prometheus metrics, ServiceMonitor integration, and Grafana dashboards
- **Autoscaling**: HPA and KEDA support for scaling based on load metrics
- **WebUI Configuration**: Editable configuration via WebUI with PVC-based storage

## Architecture

This chart deploys Stalwart Mail Server with the following components:

- **Stalwart Mail Server**: Stateless pods that handle all mail protocols
- **PostgreSQL HA**: Optional clustered PostgreSQL database with Pgpool-II load balancer
- **Redis**: Optional Redis for coordination and caching in large deployments
- **Persistent Storage**: PVCs for configuration and data storage
- **Network Policies**: Micro-segmentation to restrict traffic between components
- **Service**: LoadBalancer to expose mail protocols to the outside world
- **Ingress**: Optional Ingress for the WebUI admin interface

## Deployment Profiles

### Tiny Profile

- **Use Case**: Raspberry Pi, demos, quick testing
- **Features**: Single instance, minimal resources, filesystem storage
- **Resources**: 0.1-0.2 CPU, 256-512MB RAM
- **HA**: None (single instance)
- **PostgreSQL**: None (uses filesystem)
- **Redis**: None

### Small Profile

- **Use Case**: Homelab, small organizations, personal use
- **Features**: 1-2 instances, standalone PostgreSQL, RollingUpdate
- **Resources**: 0.25-0.5 CPU, 512MB-1GB RAM per instance
- **HA**: Optional (2 instances)
- **PostgreSQL**: Optional standalone (not HA)
- **Redis**: None

### Medium Profile

- **Use Case**: SME, enterprise departments, organizations up to 100 users
- **Features**: 2+ instances, PostgreSQL HA, NetworkPolicies, monitoring
- **Resources**: 0.5-1 CPU, 1-2GB RAM per instance
- **HA**: Required (minimum 2 instances)
- **PostgreSQL**: HA cluster with 3 nodes
- **Redis**: None (in-memory coordination)

### Large Profile

- **Use Case**: Hosting providers, critical production, SaaS platforms
- **Features**: 3+ instances, PostgreSQL HA, Redis HA, autoscaling, comprehensive monitoring
- **Resources**: 1-2 CPU, 2-4GB RAM per instance
- **HA**: Required (minimum 3 instances)
- **PostgreSQL**: HA cluster with 3 nodes
- **Redis**: HA with replication and Sentinel
- **Extras**: KEDA autoscaling, multi-zone distribution, backup integration

## Prerequisites

- Kubernetes 1.23+
- Helm 3.8.0+
- PV provisioner support in the underlying infrastructure
- LoadBalancer support or MetalLB for on-premises

## Getting Started

### Add Helm Repository

```bash
helm repo add bitnami https://charts.bitnami.com/bitnami
```

### Install with Default Profile (Small)

```bash
helm install my-mail-server ./stalwart-mail-server
```

### Install with Tiny Profile (Raspberry Pi/Demo)

```bash
helm install my-mail-server ./stalwart-mail-server --values ./stalwart-mail-server/values-profiles/values-tiny.yaml
```

### Install with Medium Profile (Enterprise)

```bash
helm install my-mail-server ./stalwart-mail-server --values ./stalwart-mail-server/values-profiles/values-medium.yaml
```

### Install with Large Profile (Hosting Provider)

```bash
helm install my-mail-server ./stalwart-mail-server --values ./stalwart-mail-server/values-profiles/values-large.yaml
```

### Custom Installation with Override Values

```bash
helm install my-mail-server ./stalwart-mail-server --values ./stalwart-mail-server/values-profiles/values-medium.yaml --set stalwart.replicaCount=3 --set service.type=NodePort
```

## Configuration

For complete configuration options, please see the [values.yaml](values.yaml) file.

### Common Configuration Parameters

| Parameter | Description | Default |
|-----------|-------------|---------|
| `global.profile` | Deployment profile (tiny, small, medium, large) | `small` |
| `stalwart.replicaCount` | Number of Stalwart instances | Profile-dependent |
| `stalwart.resources` | CPU/Memory resource requests/limits | Profile-dependent |
| `postgresql-ha.enabled` | Enable PostgreSQL HA | Profile-dependent |
| `redis.enabled` | Enable Redis | Profile-dependent |
| `storage.pvc.accessMode` | Storage access mode | Profile-dependent |
| `storage.pvc.size` | Storage size | Profile-dependent |
| `service.type` | Kubernetes Service type | `LoadBalancer` |
| `security.podSecurityStandards` | Pod Security Standards level | `restricted` |
| `security.networkPolicies.enabled` | Enable Network Policies | `true` |
| `config.content` | Custom Stalwart configuration | See values file |

### Advanced Configuration

#### Autoscaling

```yaml
autoscaling:
  enabled: true
  minReplicas: 2
  maxReplicas: 5
  targetCPUUtilizationPercentage: 70
  targetMemoryUtilizationPercentage: 80
```

#### Advanced Redis Configuration

```yaml
redis:
  enabled: true
  architecture: replication
  replica:
    replicaCount: 2
  sentinel:
    enabled: true
```

#### Custom Storage Classes

```yaml
global:
  storageClass: "fast-ssd"
  
storage:
  pvc:
    storageClass: "cephfs-rwx"
```

#### Security Customization

```yaml
security:
  networkPolicies:
    denyAll: true
    allowNamespaces:
      - monitoring
      - ingress-nginx
  
  serviceAccount:
    annotations:
      eks.amazonaws.com/role-arn: "arn:aws:iam::123456789012:role/my-iam-role"
```

## Security Considerations

This chart implements the following security best practices:

- Runs containers as non-root (UID 65534)
- Uses read-only root filesystem
- Drops all Linux capabilities
- Applies Pod Security Standards (restricted by default)
- Implements NetworkPolicies for micro-segmentation
- Minimizes RBAC permissions
- Disables ServiceAccount token automounting
- Sets secure Pod Security Context
- Enforces Pod anti-affinity for resilience

## Monitoring & Observability

The chart includes Prometheus ServiceMonitor and optional Grafana dashboards:

```yaml
monitoring:
  serviceMonitor:
    enabled: true
    namespace: monitoring
    labels:
      release: prometheus
  
  grafana:
    enabled: true
    dashboard: true
```

## Performance Tuning

For optimal performance in production environments:

1. Use high-performance StorageClass for PVCs
2. Adjust PostgreSQL resources based on expected load
3. Configure Redis for high-throughput scenarios
4. Set appropriate CPU/memory requests and limits
5. Enable autoscaling for dynamic workloads
6. Use node anti-affinity to distribute across failure domains

## Troubleshooting

### Common Issues

1. **Pods in CrashLoopBackOff**:
   - Check logs: `kubectl logs -l app.kubernetes.io/name=stalwart-mail-server`
   - Verify storage: `kubectl get pvc`
   - Check secrets: `kubectl get secrets`

2. **Service not accessible**:
   - Check LoadBalancer: `kubectl get svc`
   - Verify NetworkPolicies: `kubectl get networkpolicy`

3. **WebUI not working**:
   - Check Ingress: `kubectl get ingress`
   - Verify TLS: `kubectl get certificate`

### Logs and Debugging

```bash
# Get all pods
kubectl get pods -l app.kubernetes.io/name=stalwart-mail-server

# Check logs
kubectl logs -l app.kubernetes.io/name=stalwart-mail-server

# Get shell access
kubectl exec -it deployment/my-mail-server-stalwart-mail-server -- /bin/sh

# Check configuration
kubectl exec -it deployment/my-mail-server-stalwart-mail-server -- cat /config/config.toml
```

## Upgrade and Migration

To upgrade to a newer version:

```bash
helm repo update
helm upgrade my-mail-server ./stalwart-mail-server
```

To migrate between profiles (e.g., from small to medium):

```bash
helm upgrade my-mail-server ./stalwart-mail-server --values ./stalwart-mail-server/values-profiles/values-medium.yaml
```

## Support and Community

- [Stalwart Mail Server Documentation](https://stalw.art/docs)
- [GitHub Repository](https://github.com/stalwartlabs/mail-server)
- [Community Forum](https://github.com/stalwartlabs/mail-server/discussions)

## License

This Helm chart is licensed under the Apache License 2.0. See [LICENSE](LICENSE) for the full license text.

Stalwart Mail Server is licensed under the AGPL v3 with some features under the SELv1 license.

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.