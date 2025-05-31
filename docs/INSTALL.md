# Stalwart Mail Server Helm Chart - Installation Guide

This guide provides detailed instructions for installing and configuring the Stalwart Mail Server Helm chart on a Kubernetes cluster. It covers all deployment profiles and explains each step of the process.

## Table of Contents

- [Prerequisites](#prerequisites)
- [Choosing a Deployment Profile](#choosing-a-deployment-profile)
- [Installation Steps](#installation-steps)
- [Configuration Options](#configuration-options)
- [Post-Installation Setup](#post-installation-setup)
- [Upgrading](#upgrading)
- [Troubleshooting](#troubleshooting)

## Prerequisites

Before installing Stalwart Mail Server, ensure your environment meets the following requirements:

### Kubernetes Cluster

- **Kubernetes version**: 1.23 or later
- **Nodes**: Minimum resources vary by profile (see [Choosing a Deployment Profile](#choosing-a-deployment-profile))
- **kubectl**: Configured to access your cluster

### Helm

- **Helm version**: 3.8.0 or later
- **Repository**: Bitnami repo added for dependencies

```bash
helm repo add bitnami https://charts.bitnami.com/bitnami
helm repo update
```

### Storage

- **Dynamic provisioning**: Working StorageClass for dynamic PV provisioning
- **ReadWriteMany support**: For multi-instance deployments (Medium/Large profiles)

Check available storage classes:

```bash
kubectl get storageclass
```

### Networking

- **LoadBalancer**: For production deployments (Medium/Large profiles)
- **Public IP or domain**: For mail server access
- **DNS records**: Ability to configure MX, SPF, DKIM, and DMARC records

### Mail Server Requirements

- **Allowed ports**: Ensure your infrastructure allows the required mail ports:
  - SMTP: 25
  - SMTP Submission: 587
  - SMTP over SSL: 465
  - IMAP: 143
  - IMAP over SSL: 993
  - POP3: 110
  - POP3 over SSL: 995
  - ManageSieve: 4190
  - Web Admin: 8080/443

## Choosing a Deployment Profile

The chart offers four deployment profiles, each designed for specific use cases:

### Tiny Profile

- **Use case**: Raspberry Pi, demonstrations, quick testing
- **Features**: Single instance, minimal resources, filesystem storage
- **Resource requirements**:
  - 1 node with at least 1 CPU core and 1GB RAM
  - 5GB storage
- **Dependencies**: None (uses local filesystem storage)
- **Limitations**: No HA, limited scalability, not suitable for production

### Small Profile

- **Use case**: Homelab, small organizations, personal use
- **Features**: 1-2 instances, standalone PostgreSQL, rolling updates
- **Resource requirements**:
  - 1-2 nodes with at least 2 CPU cores and 2GB RAM each
  - 10GB+ storage
- **Dependencies**: Optional standalone PostgreSQL
- **Limitations**: Limited HA capabilities, suitable for small-scale production

### Medium Profile

- **Use case**: SME, enterprise departments, organizations up to 100 users
- **Features**: 2+ instances, PostgreSQL HA, NetworkPolicies, monitoring
- **Resource requirements**:
  - 3+ nodes with at least 4 CPU cores and 4GB RAM each
  - 50GB+ storage with ReadWriteMany support
- **Dependencies**: PostgreSQL HA (Bitnami chart)
- **Limitations**: No Redis coordination, suitable for medium-scale production

### Large Profile

- **Use case**: Hosting providers, critical production, SaaS platforms
- **Features**: 3+ instances, PostgreSQL HA, Redis HA, autoscaling, comprehensive monitoring
- **Resource requirements**:
  - 5+ nodes with at least 8 CPU cores and 16GB RAM each
  - 100GB+ storage with ReadWriteMany support
- **Dependencies**: PostgreSQL HA and Redis HA (Bitnami charts)
- **Advantages**: Maximum HA, scaling, and resilience for large-scale production

## Installation Steps

### Step 1: Create a Namespace

Create a dedicated namespace for your mail server deployment:

```bash
kubectl create namespace mail-system
```

### Step 2: Prepare Configuration Values

Create a custom values file or use one of the predefined profile values files. Add your specific configuration as needed.

Example for creating a custom values file:

```bash
# Copy the profile values file as a starting point
cp values-profiles/values-medium.yaml my-custom-values.yaml

# Edit the file with your specific settings
vim my-custom-values.yaml
```

### Step 3: Install Dependencies (Optional)

If you prefer to install dependencies separately (recommended for production):

**PostgreSQL HA**:

```bash
helm install postgresql-ha bitnami/postgresql-ha \
  --namespace mail-system \
  --set postgresql.database=stalwart \
  --set postgresql.username=stalwart \
  --set postgresql.password=YourSecurePassword \
  --set postgresql.replicaCount=3 \
  --set postgresql.syncReplication=true
```

**Redis** (for Large profile):

```bash
helm install redis bitnami/redis \
  --namespace mail-system \
  --set architecture=replication \
  --set auth.password=YourSecurePassword \
  --set replica.replicaCount=2 \
  --set sentinel.enabled=true
```

### Step 4: Install Stalwart Mail Server

#### Basic Installation

```bash
helm install stalwart-mail ./stalwart-mail-server \
  --namespace mail-system \
  --values my-custom-values.yaml
```

#### Installation with Override Values

```bash
helm install stalwart-mail ./stalwart-mail-server \
  --namespace mail-system \
  --values values-profiles/values-medium.yaml \
  --set global.profile=medium \
  --set config.hostname=mail.example.com \
  --set stalwart.replicaCount=3 \
  --set service.type=LoadBalancer
```

#### Installation with External Dependencies

If you installed dependencies separately:

```bash
helm install stalwart-mail ./stalwart-mail-server \
  --namespace mail-system \
  --values values-profiles/values-medium.yaml \
  --set global.profile=medium \
  --set config.hostname=mail.example.com \
  --set postgresql-ha.enabled=false \
  --set redis.enabled=false \
  --set config.content='[server]\nhostname = "mail.example.com"\n\n[store."data"]\ntype = "postgresql"\nurl = "postgresql://stalwart:YourSecurePassword@postgresql-ha-pgpool:5432/stalwart"'
```

### Step 5: Verify Installation

Check that all pods are running:

```bash
kubectl get pods -n mail-system
```

Check the services:

```bash
kubectl get svc -n mail-system
```

Retrieve the admin password:

```bash
kubectl get secret -n mail-system stalwart-mail-stalwart-mail-server-secret -o jsonpath="{.data.admin-password}" | base64 --decode
```

### Step 6: Access the Web UI

If using LoadBalancer:

```bash
export SERVICE_IP=$(kubectl get svc -n mail-system stalwart-mail-stalwart-mail-server -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
echo "Web Admin URL: http://$SERVICE_IP:8080"
```

If using port-forwarding:

```bash
kubectl port-forward -n mail-system svc/stalwart-mail-stalwart-mail-server 8080:8080
echo "Web Admin URL: http://localhost:8080"
```

## Configuration Options

### Critical Configuration Parameters

#### Global Settings

| Parameter | Description | Default |
|-----------|-------------|---------|
| `global.profile` | Deployment profile (tiny, small, medium, large) | `small` |
| `global.storageClass` | Default storage class | `""` |
| `global.imageRegistry` | Global image registry | `""` |

#### Stalwart Settings

| Parameter | Description | Default |
|-----------|-------------|---------|
| `stalwart.replicaCount` | Number of replicas | Profile dependent |
| `stalwart.image.tag` | Stalwart image tag | `v0.11.8` |
| `stalwart.resources` | Resource requests/limits | Profile dependent |
| `stalwart.podAntiAffinity.enabled` | Enable pod anti-affinity | `true` for HA profiles |

#### Storage Settings

| Parameter | Description | Default |
|-----------|-------------|---------|
| `storage.pvc.accessMode` | Storage access mode | `ReadWriteOnce` or `ReadWriteMany` |
| `storage.pvc.size` | Storage size | Profile dependent |
| `storage.pvc.config.enabled` | Enable config PVC | `true` |

#### Service Settings

| Parameter | Description | Default |
|-----------|-------------|---------|
| `service.type` | Service type | `LoadBalancer` |
| `service.externalTrafficPolicy` | External traffic policy | `Local` |
| `ingress.enabled` | Enable ingress | `false` |

#### Database Settings

| Parameter | Description | Default |
|-----------|-------------|---------|
| `postgresql-ha.enabled` | Enable PostgreSQL HA | Profile dependent |
| `postgresql-ha.postgresql.replicaCount` | PostgreSQL replicas | `3` |
| `redis.enabled` | Enable Redis | Profile dependent |
| `redis.architecture` | Redis architecture | `standalone` or `replication` |

#### Security Settings

| Parameter | Description | Default |
|-----------|-------------|---------|
| `security.podSecurityStandards` | Pod Security level | `restricted` |
| `security.networkPolicies.enabled` | Enable NetworkPolicies | `true` |
| `security.serviceAccount.create` | Create ServiceAccount | `true` |

### Advanced Configuration

For advanced configuration, refer to the `values.yaml` file and the examples in the `examples` directory.

## Post-Installation Setup

### Configure DNS Records

Set up the following DNS records for your domain:

1. **A/AAAA Record**:
   ```
   mail.example.com.  IN A  <YOUR_SERVER_IP>
   ```

2. **MX Record**:
   ```
   example.com.  IN MX  10 mail.example.com.
   ```

3. **SPF Record**:
   ```
   example.com.  IN TXT  "v=spf1 mx -all"
   ```

4. **DMARC Record**:
   ```
   _dmarc.example.com.  IN TXT  "v=DMARC1; p=reject; sp=reject; adkim=s; aspf=s;"
   ```

5. **DKIM Record**: Generate through the Stalwart WebUI after installation

### Configure TLS Certificates

1. Access the Stalwart WebUI
2. Navigate to Settings > Server > TLS > ACME Providers
3. Configure Let's Encrypt for automatic TLS certificate provisioning

### Create Email Accounts

1. Access the Stalwart WebUI
2. Navigate to Management > Directory > Accounts
3. Create user accounts as needed

### Configure Spam Protection

1. Access the Stalwart WebUI
2. Navigate to Settings > Spam Protection
3. Adjust spam protection settings according to your needs

## Upgrading

### Regular Updates

To upgrade to a newer version of the chart or Stalwart:

```bash
helm repo update  # If using repository
helm upgrade stalwart-mail ./stalwart-mail-server \
  --namespace mail-system \
  --values my-custom-values.yaml
```

### Profile Changes

To upgrade from one profile to another (e.g., from Small to Medium):

1. Back up your data and configuration
2. Update your values file to use the new profile
3. Upgrade the release:

```bash
helm upgrade stalwart-mail ./stalwart-mail-server \
  --namespace mail-system \
  --values values-profiles/values-medium.yaml \
  --set global.profile=medium
```

> **Note**: When migrating from a profile without HA to one with HA, ensure your storage class supports ReadWriteMany access mode.

## Troubleshooting

### Common Issues

#### Pods Stuck in Pending State

**Cause**: Insufficient resources or PVC issues

**Solution**:
```bash
kubectl describe pod -n mail-system <pod-name>
kubectl describe pvc -n mail-system <pvc-name>
```

#### Database Connection Errors

**Cause**: PostgreSQL connection issues

**Solution**:
```bash
# Check PostgreSQL pods
kubectl get pods -n mail-system -l app.kubernetes.io/name=postgresql-ha

# Check PostgreSQL logs
kubectl logs -n mail-system <postgresql-pod-name>

# Verify connection from Stalwart pod
kubectl exec -it -n mail-system <stalwart-pod-name> -- sh -c "nc -zv postgresql-ha-pgpool 5432"
```

#### Email Delivery Issues

**Cause**: DNS configuration or network policy issues

**Solution**:
```bash
# Check DNS records
dig MX example.com
dig TXT example.com  # For SPF

# Check outbound connectivity
kubectl exec -it -n mail-system <stalwart-pod-name> -- sh -c "nc -zv gmail-smtp-in.l.google.com 25"
```

#### WebUI Access Issues

**Cause**: Service or ingress configuration

**Solution**:
```bash
# Check service
kubectl get svc -n mail-system stalwart-mail-stalwart-mail-server

# Check ingress if enabled
kubectl get ingress -n mail-system
kubectl describe ingress -n mail-system <ingress-name>
```

### Getting Support

If you encounter issues not covered in this guide:

1. Check the Stalwart documentation: https://stalw.art/docs/
2. Visit the GitHub repository: https://github.com/stalwartlabs/mail-server
3. Join the community discussion: https://github.com/stalwartlabs/mail-server/discussions
4. Submit an issue: https://github.com/stalwartlabs/mail-server/issues