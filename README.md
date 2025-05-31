# 📬 Stalwart Mail Server Helm Chart

![Version: 0.1.0](https://img.shields.io/badge/Version-0.1.0-informational?style=flat-square) ![Type: application](https://img.shields.io/badge/Type-application-informational?style=flat-square) ![AppVersion: v0.11.8](https://img.shields.io/badge/AppVersion-v0.11.8-informational?style=flat-square)

A production-ready Helm chart for **Stalwart Mail Server** with flexible deployment profiles for high availability and scalability 🚀

---

## 🌐 Introduction

[**Stalwart Mail Server**](https://stalw.art/) is a modern, open-source mail server written in Rust 🦀. It supports **SMTP, JMAP, IMAP4, and POP3** and is designed for security 🔐, speed ⚡, robustness 🛡️, and scalability 📈.

This Helm chart lets you deploy Stalwart Mail Server on Kubernetes in a breeze, with built-in support for everything from Raspberry Pi demos to enterprise-grade HA setups 💼.

---

## ✨ Features

* 🧩 **Multiple Deployment Profiles** – tiny to large, tailored to your needs
* 🛡️ **High Availability** – anti-affinity, rolling updates, zero-downtime upgrades
* 🗃️ **PostgreSQL HA Integration** – includes Pgpool & Repmgr
* 🧠 **Redis Coordination** – for caching & clustering in large deployments
* 🔐 **Comprehensive Security** – secure-by-default, Pod Security Standards, NetworkPolicies
* 📈 **Monitoring Ready** – Prometheus + Grafana support out of the box
* 📊 **Autoscaling** – via HPA or KEDA
* 🖥️ **WebUI Configuration** – config stored on PVCs, editable via WebUI

---

## 🏗️ Architecture

This chart deploys the following components:

* 📮 **Stalwart Mail Server** – stateless mail protocol pods
* 🗄️ **PostgreSQL HA** – optional 3-node clustered backend
* ⚡ **Redis Cluster** – optional for advanced caching/coordination
* 💾 **Persistent Storage** – PVCs for data and config
* 🔐 **Network Policies** – micro-segmentation for traffic control
* 🌐 **Service** – LoadBalancer for external mail access
* 🚪 **Ingress** – optional access to WebUI

---

## 🧪 Deployment Profiles

### 🐣 Tiny Profile

* 🔍 For: Raspberry Pi, quick demos
* 🔧 Single instance, filesystem storage
* 🧠 0.1–0.2 CPU, 256–512MB RAM
* 🚫 No HA, PostgreSQL, or Redis

### 🏠 Small Profile

* 🧑‍💻 For: Homelabs, small teams
* 📦 1–2 instances, optional standalone PostgreSQL
* 🧠 0.25–0.5 CPU, 512MB–1GB RAM
* 🔄 Optional HA, no Redis

### 🏢 Medium Profile

* 🧑‍🤝‍🧑 For: SMEs, departments (\~100 users)
* 💪 2+ instances, PostgreSQL HA, monitoring
* 🧠 0.5–1 CPU, 1–2GB RAM
* ✅ HA required, Redis optional

### 🏙️ Large Profile

* 🌐 For: Hosting providers, SaaS, production
* 🔥 3+ instances, HA PostgreSQL & Redis, autoscaling
* 🧠 1–2 CPU, 2–4GB RAM
* 🎯 KEDA, backups, multi-zone ready

---

## ✅ Prerequisites

* ☁️ Kubernetes 1.23+
* 🪄 Helm 3.8.0+
* 📦 PVC provisioner support
* 🌍 LoadBalancer support (or MetalLB for on-prem)

---

## 🚀 Getting Started

### 📦 Add Helm Repo

```bash
helm repo add bitnami https://charts.bitnami.com/bitnami
```

### ⚙️ Install (Default: Small Profile)

```bash
helm install my-mail-server ./stalwart-mail-server
```

### 🐣 Tiny (Demo/Raspberry Pi)

```bash
helm install my-mail-server ./stalwart-mail-server --values ./stalwart-mail-server/values-profiles/values-tiny.yaml
```

### 🏢 Medium (Enterprise)

```bash
helm install my-mail-server ./stalwart-mail-server --values ./stalwart-mail-server/values-profiles/values-medium.yaml
```

### 🏙️ Large (Production Hosting)

```bash
helm install my-mail-server ./stalwart-mail-server --values ./stalwart-mail-server/values-profiles/values-large.yaml
```

### 🛠️ Custom Overrides

```bash
helm install my-mail-server ./stalwart-mail-server \
  --values ./stalwart-mail-server/values-profiles/values-medium.yaml \
  --set stalwart.replicaCount=3 \
  --set service.type=NodePort
```

---

## ⚙️ Configuration

See full options in [`values.yaml`](values.yaml)

| Parameter                       | Description               | Default            |
| ------------------------------- | ------------------------- | ------------------ |
| `global.profile`                | Profile name              | `small`            |
| `stalwart.replicaCount`         | Number of replicas        | Depends on profile |
| `stalwart.resources`            | CPU/RAM requests & limits | Profile-based      |
| `postgresql-ha.enabled`         | Enable PostgreSQL HA      | Profile-based      |
| `redis.enabled`                 | Enable Redis              | Profile-based      |
| `service.type`                  | Service type              | `LoadBalancer`     |
| `storage.pvc.size`              | Storage size              | Profile-based      |
| `security.podSecurityStandards` | PSS level                 | `restricted`       |

---

## 📈 Autoscaling Example

```yaml
autoscaling:
  enabled: true
  minReplicas: 2
  maxReplicas: 5
  targetCPUUtilizationPercentage: 70
  targetMemoryUtilizationPercentage: 80
```

---

## 🧠 Advanced Redis

```yaml
redis:
  enabled: true
  architecture: replication
  replica:
    replicaCount: 2
  sentinel:
    enabled: true
```

---

## 💾 Custom Storage Classes

```yaml
global:
  storageClass: "fast-ssd"
storage:
  pvc:
    storageClass: "cephfs-rwx"
```

---

## 🔐 Security Config

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

---

## 🛡️ Security Best Practices

* 🔒 Non-root containers (UID 65534)
* 📁 Read-only root FS
* 🚫 Dropped Linux capabilities
* ✅ Restricted PodSecurityContext
* 🔐 NetworkPolicies + RBAC minimization
* 🔁 Pod anti-affinity for resilience

---

## 📊 Monitoring & Observability

Includes Prometheus and Grafana support:

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

---

## 🚦 Troubleshooting

### 🧨 CrashLoopBackOff?

```bash
kubectl logs -l app.kubernetes.io/name=stalwart-mail-server
kubectl get pvc
kubectl get secrets
```

### ❌ Can't Access Service?

```bash
kubectl get svc
kubectl get networkpolicy
```

### 🛑 WebUI Broken?

```bash
kubectl get ingress
kubectl get certificate
```

### 🔍 Debug Tips

```bash
kubectl get pods -l app.kubernetes.io/name=stalwart-mail-server
kubectl exec -it deployment/my-mail-server-stalwart-mail-server -- /bin/sh
kubectl exec -it deployment/my-mail-server-stalwart-mail-server -- cat /config/config.toml
```

---

## 🔄 Upgrades & Migration

### 🆙 Upgrade Chart

```bash
helm repo update
helm upgrade my-mail-server ./stalwart-mail-server
```

### 🔁 Migrate Profile

```bash
helm upgrade my-mail-server ./stalwart-mail-server --values ./stalwart-mail-server/values-profiles/values-medium.yaml
```

---

## 💬 Support & Community

* 📚 [Docs](https://stalw.art/docs)
* 🧑‍💻 [GitHub](https://github.com/stalwartlabs/mail-server)
* 💬 [Discussions](https://github.com/stalwartlabs/mail-server/discussions)

---

## 📜 License

* 📦 This Helm chart: **Apache 2.0**
* 📨 Stalwart Mail Server: **AGPL v3 / SELv1**

---

## 🤝 Contributing

PRs welcome! 💡 Help us make this chart even better 🛠️


