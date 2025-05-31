# Quick Start Installation Guide for Stalwart Mail Server Helm Chart

This example provides a step-by-step guide to quickly deploy Stalwart Mail Server using different profiles for testing or production use.

## Prerequisites

Before you begin, ensure you have:
- A running Kubernetes cluster (version 1.23+)
- Helm 3.8.0+ installed
- `kubectl` configured to access your cluster
- Dynamic volume provisioning enabled in your cluster

## Step 1: Add Required Helm Repositories

```bash
# Add Bitnami repository for PostgreSQL HA and Redis dependencies
helm repo add bitnami https://charts.bitnami.com/bitnami

# Update repositories
helm repo update
```

## Step 2: Create a Namespace

```bash
kubectl create namespace mail-system
```

## Step 3: Choose a Deployment Profile

### Option A: Tiny Profile (for demos/testing)

```bash
# Clone the chart repository
git clone https://github.com/stalwartlabs/stalwart-mail-server-helm.git
cd stalwart-mail-server-helm

# Install using the tiny profile
helm install stalwart-mail -n mail-system \
  --values ./values-profiles/values-tiny.yaml \
  --set config.hostname="mail.example.com" \
  .
```

### Option B: Small Profile (for homelab/small teams)

```bash
# Install using the small profile
helm install stalwart-mail -n mail-system \
  --values ./values-profiles/values-small.yaml \
  --set config.hostname="mail.example.com" \
  --set stalwart.replicaCount=1 \
  .
```

### Option C: Medium Profile (for SMEs/enterprise)

```bash
# Install using the medium profile
helm install stalwart-mail -n mail-system \
  --values ./values-profiles/values-medium.yaml \
  --set config.hostname="mail.example.com" \
  --set stalwart.replicaCount=2 \
  .
```

### Option D: Large Profile (for hosting providers/critical workloads)

```bash
# Install using the large profile
helm install stalwart-mail -n mail-system \
  --values ./values-profiles/values-large.yaml \
  --set config.hostname="mail.example.com" \
  --set stalwart.replicaCount=3 \
  .
```

## Step 4: Verify the Installation

```bash
# Check deployment status
kubectl get pods -n mail-system

# Check services
kubectl get svc -n mail-system
```

## Step 5: Access the Web Admin Interface

```bash
# Get the external IP/hostname
export SERVICE_IP=$(kubectl get svc -n mail-system stalwart-mail-stalwart-mail-server -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
echo "Web Admin URL: http://$SERVICE_IP:8080"

# Get the admin password
kubectl get secret -n mail-system stalwart-mail-stalwart-mail-server-secret -o jsonpath="{.data.admin-password}" | base64 --decode
echo

# Alternatively, use port-forwarding if LoadBalancer is not available
kubectl port-forward -n mail-system svc/stalwart-mail-stalwart-mail-server 8080:8080
echo "Web Admin URL: http://localhost:8080"
```

## Step 6: Configure DNS Records

For production use, configure the following DNS records:

```
# A/AAAA records
mail.example.com.    IN A    <YOUR_SERVER_IP>

# MX record
example.com.         IN MX   10 mail.example.com.

# SPF record
example.com.         IN TXT  "v=spf1 mx -all"

# DMARC record
_dmarc.example.com.  IN TXT  "v=DMARC1; p=reject; sp=reject; adkim=s; aspf=s;"
```

DKIM records can be generated through the web admin interface after installation.

## Step 7: Configure TLS Certificates

Through the web admin interface:
1. Go to Settings > Server > TLS > ACME Providers
2. Configure Let's Encrypt for automatic TLS certificate provisioning

## Examples of Custom Configuration

### Custom Storage Class

```bash
helm install stalwart-mail -n mail-system \
  --values ./values-profiles/values-medium.yaml \
  --set global.storageClass="ceph-block" \
  --set storage.pvc.config.storageClass="ceph-filesystem" \
  .
```

### Custom Resources

```bash
helm install stalwart-mail -n mail-system \
  --values ./values-profiles/values-medium.yaml \
  --set stalwart.resources.requests.cpu="1" \
  --set stalwart.resources.requests.memory="2Gi" \
  --set stalwart.resources.limits.cpu="2" \
  --set stalwart.resources.limits.memory="4Gi" \
  .
```

### Custom Service Type (NodePort)

```bash
helm install stalwart-mail -n mail-system \
  --values ./values-profiles/values-small.yaml \
  --set service.type="NodePort" \
  .
```

### Enable Ingress with TLS

```bash
helm install stalwart-mail -n mail-system \
  --values ./values-profiles/values-medium.yaml \
  --set ingress.enabled=true \
  --set ingress.className=nginx \
  --set ingress.annotations."cert-manager\.io/cluster-issuer"=letsencrypt-prod \
  --set ingress.hosts[0].host=mail-admin.example.com \
  --set ingress.hosts[0].paths[0].path=/ \
  --set ingress.hosts[0].paths[0].pathType=Prefix \
  --set ingress.tls[0].secretName=mail-admin-tls \
  --set ingress.tls[0].hosts[0]=mail-admin.example.com \
  .
```

## Upgrade and Scaling

### Upgrade the chart

```bash
helm upgrade stalwart-mail -n mail-system \
  --values ./values-profiles/values-medium.yaml \
  .
```

### Scale up replicas

```bash
kubectl scale deployment -n mail-system stalwart-mail-stalwart-mail-server --replicas=3
```

or

```bash
helm upgrade stalwart-mail -n mail-system \
  --values ./values-profiles/values-medium.yaml \
  --set stalwart.replicaCount=3 \
  .
```

## Cleanup

```bash
# Uninstall the chart
helm uninstall stalwart-mail -n mail-system

# Delete PVCs if you want to remove persistent data
kubectl delete pvc -n mail-system -l app.kubernetes.io/instance=stalwart-mail

# Delete the namespace
kubectl delete namespace mail-system
```