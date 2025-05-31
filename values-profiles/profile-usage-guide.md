# Stalwart Mail Server Profile Usage Guide

This document explains how to use the different deployment profiles of the Stalwart Mail Server Helm chart, from the simplest to the most advanced.

## Profile Overview

| Profile    | Use Case           | Stalwart      | PostgreSQL   | Redis | HA       | CPU/RAM Resources   |
| ---------- | ------------------ | ------------- | ------------ | ----- | -------- | ------------------- |
| **Tiny**   | Demo, RPI, Testing | 1 instance    | Optional     | ❌     | ❌        | 100m/256Mi          |
| **Small**  | Homelab, SMB       | 1–2 instances | Standalone   | ❌     | Optional | 200m–400m/512Mi–1Gi |
| **Medium** | SME, Enterprise    | 2+ instances  | HA (3 nodes) | ❌     | ✅        | 500m–1000m/1–2Gi    |
| **Large**  | Hosting, SaaS      | 3+ instances  | HA (3 nodes) | HA    | ✅        | 1000m–2000m/2–4Gi   |

## Quick Installation by Profile

### Tiny Profile – Quick Demo

```bash
# For a quick test on Raspberry Pi or local demo
helm install stalwart-demo ./stalwart-mail-chart \
  --values values-tiny.yaml \
  --set demo.quickStart.enabled=true \
  --set postgresql.enabled=false \
  --set stalwart.blobStorageOnly.enabled=true

# Access: http://nodeip:30080 (WebUI)
# User: admin
# Password: retrieve from pod logs with:
kubectl logs $(kubectl get pods -l app.kubernetes.io/name=stalwart-mail -o name | head -1) | grep "administrator account"
```

### Small Profile – Homelab/Organization

```bash
# For a serious homelab with optional HA
helm install stalwart-homelab ./stalwart-mail-chart \
  --values values-small.yaml \
  --set stalwart.replicaCount=2 \
  --set stalwart.persistence.accessMode=ReadWriteMany

# Verification
kubectl get pods -l app.kubernetes.io/name=stalwart-mail
kubectl get svc stalwart-mail-service

# Retrieve admin password
kubectl logs $(kubectl get pods -l app.kubernetes.io/name=stalwart-mail -o name | head -1) | grep "administrator account"
```

### Medium Profile – SME Production

```bash
# Add Bitnami repo for PostgreSQL HA
helm repo add bitnami https://charts.bitnami.com/bitnami
helm repo update

# Deployment with PostgreSQL HA
helm install stalwart-prod ./stalwart-mail-chart \
  --values values-medium.yaml \
  --set global.storageClass="fast-ssd" \
  --set monitoring.enabled=true

# HA Verification
kubectl get pods -o wide | grep stalwart
kubectl get pdb stalwart-mail-pdb

# Retrieve admin password
kubectl logs $(kubectl get pods -l app.kubernetes.io/name=stalwart-mail -o name | head -1) | grep "administrator account"
```

### Large Profile – Critical Infrastructure

```bash
# Prerequisites: KEDA and Prometheus deployed
helm repo add kedacore https://kedacore.github.io/charts
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts

# Full deployment with Redis HA
helm install stalwart-enterprise ./stalwart-mail-chart \
  --values values-large.yaml \
  --set global.storageClass="premium-ssd" \
  --set keda.enabled=true \
  --set monitoring.prometheus.enabled=true

# Autoscaling check
kubectl get hpa stalwart-mail-hpa
kubectl get scaledobject stalwart-mail-keda

# Retrieve admin password
kubectl logs $(kubectl get pods -l app.kubernetes.io/name=stalwart-mail -o name | head -1) | grep "administrator account"
```

## Feature Details by Profile

### Security and Compliance

| Feature                | Tiny     | Small      | Medium     | Large      |
| ---------------------- | -------- | ---------- | ---------- | ---------- |
| Pod Security Standards | Baseline | Restricted | Restricted | Restricted |
| NetworkPolicies        | ❌        | ❌          | ✅          | ✅          |
| Granular RBAC          | ❌        | ✅          | ✅          | ✅          |
| External Secrets       | ❌        | ❌          | ✅          | ✅          |
| Audit Logging          | ❌        | ❌          | ✅          | ✅          |
| GDPR Compliance        | ❌        | ❌          | ❌          | ✅          |

### High Availability

| Feature             | Tiny         | Small    | Medium   | Large    |
| ------------------- | ------------ | -------- | -------- | -------- |
| Pod Anti-Affinity   | ❌            | Optional | Required | Required |
| Multi-Zone          | ❌            | ❌        | Optional | ✅        |
| PodDisruptionBudget | ❌            | ❌        | ✅        | ✅        |
| Rolling Updates     | ❌ (Recreate) | ✅        | ✅        | ✅        |
| Automated Backup    | ❌            | ❌        | ✅        | ✅        |

### Monitoring and Observability

| Feature            | Tiny | Small | Medium | Large |
| ------------------ | ---- | ----- | ------ | ----- |
| Prometheus Metrics | ❌    | ❌     | ✅      | ✅     |
| Grafana Dashboards | ❌    | ❌     | ✅      | ✅     |
| Alerting           | ❌    | ❌     | ✅      | ✅     |
| Service Monitors   | ❌    | ❌     | ✅      | ✅     |
| Log Forwarding     | ❌    | ❌     | ❌      | ✅     |

## Profile Migration

### From Tiny to Small

```bash
# 1. Backup data
kubectl exec stalwart-pod -- tar czf /tmp/backup.tar.gz /opt/stalwart-mail

# 2. Migration
helm upgrade stalwart-demo ./stalwart-mail-chart \
  --values values-small.yaml \
  --set postgresql.enabled=true

# 3. Restore data if needed
```

### From Small to Medium

```bash
# 1. Enable PostgreSQL HA
helm upgrade stalwart-homelab ./stalwart-mail-chart \
  --values values-medium.yaml \
  --set postgresql-ha.enabled=true \
  --set postgresql.enabled=false

# 2. Migrate PostgreSQL data
# (Migration script provided)
```

### From Medium to Large

```bash
# 1. Add Redis HA
helm upgrade stalwart-prod ./stalwart-mail-chart \
  --values values-large.yaml \
  --set redis.enabled=true \
  --set keda.enabled=true
```

## Validation Tests

### Connectivity Test

```bash
# Automated test pod
kubectl apply -f - <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: mail-test
spec:
  containers:
  - name: test
    image: alpine/curl
    command: ["sleep", "3600"]
EOF

# Tests
kubectl exec mail-test -- curl -f http://stalwart-mail-service:8080/healthz/ready
kubectl exec mail-test -- nc -zv stalwart-mail-service 25
kubectl exec mail-test -- nc -zv stalwart-mail-service 587
kubectl exec mail-test -- nc -zv stalwart-mail-service 993
```

### Email Sending Test

```bash
# Via SMTP
kubectl exec mail-test -- sh -c '
echo "Subject: Test Email
From: test@mail.local
To: demo@mail.local

Test message body" | nc stalwart-mail-service 25
'
```

### WebUI Test

```bash
# Retrieve admin password
ADMIN_PASSWORD=$(kubectl logs $(kubectl get pods -l app.kubernetes.io/name=stalwart-mail -o name | head -1) | grep "administrator account" | awk -F "'" '{print $4}')

# Port-forward for local access
kubectl port-forward svc/stalwart-mail-service 8080:8080

# Access: http://localhost:8080
# User: admin / $ADMIN_PASSWORD
```

## Troubleshooting by Profile

### Tiny – Common Issues

```bash
# Pod CrashLoopBackOff
kubectl logs stalwart-mail-xxx --previous

# Storage issue
kubectl describe pvc stalwart-pvc

# Blob-only mode not working
kubectl exec stalwart-pod -- ls -la /opt/stalwart-mail/data

# Password not found
kubectl logs stalwart-mail-xxx | grep -i password
```

### Small – HA Issues

```bash
# Anti-affinity not respected (2 instances)
kubectl get pods -o wide | grep stalwart

# RWX issue
kubectl describe pvc stalwart-config-pvc
kubectl get storageclass

# Admin password inaccessible
# If first pod restarted, check previous pod logs
kubectl logs stalwart-mail-xxx --previous | grep "administrator account"
```

### Medium – PostgreSQL HA Issues

```bash
# PostgreSQL cluster status
kubectl exec postgresql-ha-postgresql-0 -- patronictl list

# Pgpool connectivity
kubectl exec stalwart-pod -- nc -zv postgresql-ha-pgpool 5432

# Blocking NetworkPolicies
kubectl describe netpol
```

### Large – Redis and Autoscaling Issues

```bash
# Redis HA status
kubectl exec redis-master-0 -- redis-cli info replication

# KEDA not scaling
kubectl describe scaledobject stalwart-mail-keda
kubectl logs -n keda-system deployment/keda-operator

# Missing Prometheus metrics
kubectl get servicemonitor stalwart-mail
kubectl logs -n monitoring prometheus-operated-xxx
```

## Useful Commands

### Secret Management

```bash
# Retrieve generated passwords
kubectl get secret stalwart-postgresql-secret -o yaml
kubectl get secret stalwart-redis-secret -o yaml

# Retrieve admin password
kubectl logs $(kubectl get pods -l app.kubernetes.io/name=stalwart-mail -o name | head -1) | grep "administrator account"

# Secret rotation (External Secrets)
kubectl annotate externalsecret stalwart-secrets force-sync=$(date +%s)
```

### Monitoring and Metrics

```bash
# Metrics check
kubectl port-forward svc/stalwart-mail-service 8080:8080
curl http://localhost:8080/metrics

# Grafana dashboard
kubectl port-forward -n monitoring svc/grafana 3000:80
# http://localhost:3000 (admin/admin)
```

### Backup and Restore

```bash
# Manual Velero backup
velero backup create stalwart-manual --include-namespaces=stalwart

# Restore
velero restore create stalwart-restore --from-backup stalwart-manual

# Verification
velero backup describe stalwart-manual
```

## Advanced Customization

### Custom Storage

```yaml
global:
  storageClass: "your-storage-class"

stalwart:
  persistence:
    size: "100Gi"
    annotations:
      volume.kubernetes.io/storage-class: "premium-ssd"
```

### Custom Redis Configuration

```yaml
redis:
  master:
    configuration: |
      maxmemory 2gb
      maxmemory-policy allkeys-lru
      save 900 1
      save 300 10
```

### Ingress with ModSecurity

```yaml
ingress:
  enabled: true
  annotations:
    nginx.ingress.kubernetes.io/enable-modsecurity: "true"
    nginx.ingress.kubernetes.io/modsecurity-snippet: |
      SecRuleEngine On
      SecRequestBodyAccess On
      SecRule REQUEST_HEADERS:Content-Type "text/xml" \
        "id:'200001',phase:1,t:none,t:lowercase,pass,nolog,ctl:requestBodyProcessor=XML"
```

---

## Support and Contribution

* **Issues**: [GitHub Issues](https://github.com/stalwartlabs/stalwart-helm/issues)
* **Documentation**: [Stalwart Mail Docs](https://stalw.art/docs)
* **Community**: [Discord](https://discord.gg/stalwart)

This chart is community-maintained and ready for submission to the official Stalwart Labs repository.

