# Troubleshooting Guide for Stalwart Mail Server Helm Chart

This guide covers common issues you might encounter when deploying and operating Stalwart Mail Server using this Helm chart, along with detailed troubleshooting steps and solutions.

## Table of Contents

- [Installation Issues](#installation-issues)
- [Pod Status Issues](#pod-status-issues)
- [Database Issues](#database-issues)
- [Storage Issues](#storage-issues)
- [Networking Issues](#networking-issues)
- [Mail Protocol Issues](#mail-protocol-issues)
- [WebUI Issues](#webui-issues)
- [Performance Issues](#performance-issues)
- [Upgrading Issues](#upgrading-issues)
- [Debugging Techniques](#debugging-techniques)

## Installation Issues

### Error: Chart Dependency Not Found

**Symptom**: Helm reports missing dependencies when installing the chart.

**Cause**: Bitnami repository not added or dependencies not updated.

**Solution**:
```bash
# Add Bitnami repository
helm repo add bitnami https://charts.bitnami.com/bitnami

# Update repositories
helm repo update

# Update chart dependencies
helm dependency update ./stalwart-mail-server
```

### Error: Invalid Profile

**Symptom**: Error message about invalid profile during installation.

**Cause**: The specified profile does not match one of the allowed values.

**Solution**: Ensure you're using one of the valid profiles: `tiny`, `small`, `medium`, or `large`.

```bash
# Example correction
helm install stalwart-mail ./stalwart-mail-server --set global.profile=medium
```

### Error: PVC Storage Class Not Found

**Symptom**: Installation fails with error about storage class not found.

**Cause**: The specified storage class doesn't exist in your cluster.

**Solution**:
```bash
# Check available storage classes
kubectl get storageclass

# Use an existing storage class
helm install stalwart-mail ./stalwart-mail-server --set global.storageClass=standard
```

## Pod Status Issues

### Pods Stuck in Pending State

**Symptom**: Pods remain in `Pending` status and don't start.

**Causes**:
1. Insufficient cluster resources
2. PVC issues
3. Node selector constraints not met

**Solutions**:

Check pod events:
```bash
kubectl describe pod -n <namespace> <pod-name>
```

For resource issues:
```bash
# Check node resources
kubectl describe nodes
```

For PVC issues:
```bash
kubectl get pvc -n <namespace>
kubectl describe pvc -n <namespace> <pvc-name>
```

### Pods in CrashLoopBackOff

**Symptom**: Pods repeatedly crash and restart.

**Causes**:
1. Configuration errors
2. Permission issues
3. Resource constraints
4. Dependency issues (PostgreSQL/Redis)

**Solutions**:

Check pod logs:
```bash
kubectl logs -n <namespace> <pod-name>
```

Check readiness/liveness probe failures:
```bash
kubectl describe pod -n <namespace> <pod-name>
```

Verify configuration:
```bash
kubectl get cm -n <namespace> <configmap-name> -o yaml
```

### Container Not Starting Due to Security Constraints

**Symptom**: Container fails to start with security context related errors.

**Cause**: Pod Security Standards policy violations.

**Solution**:
```bash
# Option 1: Adjust the pod security standards level
helm upgrade stalwart-mail ./stalwart-mail-server --set security.podSecurityStandards=baseline

# Option 2: Fix security context configuration
kubectl describe pod -n <namespace> <pod-name>  # Find exact error
```

## Database Issues

### PostgreSQL Connection Failures

**Symptom**: Stalwart pods report they cannot connect to PostgreSQL.

**Causes**:
1. PostgreSQL pods not ready
2. Incorrect credentials
3. Network policy blocking access

**Solutions**:

Check PostgreSQL pod status:
```bash
kubectl get pods -n <namespace> -l app.kubernetes.io/name=postgresql-ha
```

Check PostgreSQL logs:
```bash
kubectl logs -n <namespace> <postgresql-pod-name>
```

Verify connectivity:
```bash
kubectl exec -it -n <namespace> <stalwart-pod-name> -- nc -zv <postgresql-service> 5432
```

Verify credentials:
```bash
kubectl get secret -n <namespace> <postgresql-secret> -o yaml
```

### Redis Connection Issues

**Symptom**: Cannot connect to Redis when using Large profile.

**Causes**:
1. Redis pods not ready
2. Network policy issues
3. Authentication failures

**Solutions**:

Check Redis pod status:
```bash
kubectl get pods -n <namespace> -l app.kubernetes.io/name=redis
```

Verify connectivity:
```bash
kubectl exec -it -n <namespace> <stalwart-pod-name> -- nc -zv <redis-service> 6379
```

Check Redis authentication:
```bash
kubectl exec -it -n <namespace> <redis-pod-name> -- redis-cli -a <password> ping
```

## Storage Issues

### ReadWriteMany Requirements

**Symptom**: Deployment fails when using multiple replicas with `ReadWriteOnce` PVCs.

**Cause**: Multiple pods cannot use the same `ReadWriteOnce` volume.

**Solution**:
```bash
# Check if your cluster supports ReadWriteMany
kubectl get sc

# Configure chart to use ReadWriteMany
helm install stalwart-mail ./stalwart-mail-server --set storage.pvc.accessMode=ReadWriteMany
```

Common ReadWriteMany providers:
- NFS
- CephFS
- AWS EFS
- Azure Files
- Google Filestore

### PVC Stuck in Pending

**Symptom**: PVC remains in `Pending` state.

**Causes**:
1. No default storage class
2. Storage class doesn't support requested access mode
3. Insufficient storage capacity

**Solutions**:

Check PVC status:
```bash
kubectl describe pvc -n <namespace> <pvc-name>
```

Check storage classes:
```bash
kubectl get sc
kubectl describe sc <storage-class-name>
```

## Networking Issues

### Service LoadBalancer Pending

**Symptom**: Service stuck in `Pending` state when using LoadBalancer.

**Causes**:
1. No LoadBalancer provider in cluster
2. LoadBalancer configuration issues

**Solutions**:

For on-premises clusters, install MetalLB:
```bash
# Install MetalLB
kubectl apply -f https://raw.githubusercontent.com/metallb/metallb/v0.13.9/config/manifests/metallb-native.yaml

# Configure address pool
cat <<EOF | kubectl apply -f -
apiVersion: metallb.io/v1beta1
kind: IPAddressPool
metadata:
  name: default-pool
  namespace: metallb-system
spec:
  addresses:
  - 192.168.1.240-192.168.1.250
EOF

# Configure L2 announcement
cat <<EOF | kubectl apply -f -
apiVersion: metallb.io/v1beta1
kind: L2Advertisement
metadata:
  name: l2-advert
  namespace: metallb-system
spec:
  ipAddressPools:
  - default-pool
EOF
```

Or use NodePort instead:
```bash
helm upgrade stalwart-mail ./stalwart-mail-server --set service.type=NodePort
```

### NetworkPolicy Blocking Traffic

**Symptom**: Cannot access services or pods cannot communicate with each other.

**Cause**: Overly restrictive NetworkPolicies.

**Solution**:
```bash
# List NetworkPolicies
kubectl get networkpolicy -n <namespace>

# View NetworkPolicy details
kubectl describe networkpolicy -n <namespace> <policy-name>

# Temporarily disable NetworkPolicies (for testing only)
helm upgrade stalwart-mail ./stalwart-mail-server --set security.networkPolicies.enabled=false
```

## Mail Protocol Issues

### SMTP Connection Issues

**Symptom**: Cannot send emails through the server.

**Causes**:
1. Port 25/587/465 blocked by network policy
2. TLS configuration issues
3. Authentication issues

**Solutions**:

Test SMTP connection:
```bash
# From inside the cluster
kubectl run -it --rm smtp-test --image=alpine -- sh -c "apk add --no-cache swaks && swaks --server <service-name> --port 25 --to test@example.com --from test@example.com"

# From outside the cluster
swaks --tls --auth LOGIN --auth-user user@example.com --auth-password password --server mail.example.com --port 587 --to test@example.com --from user@example.com
```

Check SMTP logs:
```bash
kubectl logs -n <namespace> <pod-name> | grep smtp
```

### IMAP/POP3 Connection Issues

**Symptom**: Email clients cannot connect to IMAP/POP3.

**Causes**:
1. Port 143/993/110/995 blocked
2. TLS configuration issues
3. Authentication issues

**Solutions**:

Test IMAP connection:
```bash
kubectl run -it --rm imap-test --image=alpine -- sh -c "apk add --no-cache openssl && openssl s_client -connect <service-name>:993"
```

Check IMAP logs:
```bash
kubectl logs -n <namespace> <pod-name> | grep imap
```

## WebUI Issues

### Cannot Access WebUI

**Symptom**: Unable to access the Stalwart WebUI.

**Causes**:
1. Service not exposing port 8080/443
2. Ingress issues
3. Configuration errors

**Solutions**:

Check service:
```bash
kubectl get svc -n <namespace>
```

Use port-forwarding to test direct access:
```bash
kubectl port-forward -n <namespace> svc/<service-name> 8080:8080
```

Check ingress (if enabled):
```bash
kubectl get ingress -n <namespace>
kubectl describe ingress -n <namespace> <ingress-name>
```

### WebUI Configuration Changes Not Applied

**Symptom**: Changes made via WebUI don't persist after pod restart.

**Cause**: Configuration not properly saved to PVC.

**Solution**:

1. Verify PVC configuration:
```bash
kubectl describe pvc -n <namespace> <config-pvc-name>
```

2. Check configuration settings:
```yaml
config:
  type: "pvc"  # Make sure this is "pvc" not "configmap"
  
storage:
  pvc:
    config:
      enabled: true  # Must be true
      accessMode: "ReadWriteMany"  # Required for multiple replicas
```

3. Verify mount paths in deployment:
```bash
kubectl describe deployment -n <namespace> <deployment-name>
```

## Performance Issues

### High CPU/Memory Usage

**Symptom**: Pods using excessive CPU or memory.

**Causes**:
1. Insufficient resources allocated
2. Large mail volume
3. Inefficient configuration

**Solutions**:

Monitor resource usage:
```bash
kubectl top pods -n <namespace>
```

Adjust resource limits:
```yaml
stalwart:
  resources:
    requests:
      cpu: 1
      memory: 2Gi
    limits:
      cpu: 2
      memory: 4Gi
```

### Slow Email Delivery

**Symptom**: Emails taking long time to be delivered.

**Causes**:
1. Queue processing issues
2. Resource constraints
3. External mail server issues

**Solutions**:

Check the mail queue:
```bash
kubectl exec -it -n <namespace> <pod-name> -- /opt/stalwart-mail/bin/stalwart-cli queue list
```

Check outbound connections:
```bash
kubectl exec -it -n <namespace> <pod-name> -- netstat -an | grep ESTABLISHED
```

## Upgrading Issues

### Configuration Lost After Upgrade

**Symptom**: Custom configurations disappear after upgrading.

**Cause**: Configuration not properly stored or overwritten during upgrade.

**Solution**:
1. Use `--reuse-values` when upgrading:
```bash
helm upgrade stalwart-mail ./stalwart-mail-server --reuse-values
```

2. Save your values to a file and reference it:
```bash
helm get values stalwart-mail -n <namespace> > current-values.yaml
helm upgrade stalwart-mail ./stalwart-mail-server -f current-values.yaml
```

### Upgrade Fails

**Symptom**: Helm upgrade command fails.

**Causes**:
1. Incompatible changes between versions
2. Resource conflicts
3. PVC access mode changes

**Solutions**:

Get detailed error message:
```bash
helm upgrade --debug --dry-run stalwart-mail ./stalwart-mail-server -f values.yaml
```

For PVC issues, you may need to uninstall and reinstall:
```bash
helm uninstall stalwart-mail -n <namespace>
# Make sure to back up data first!
helm install stalwart-mail ./stalwart-mail-server -f values.yaml
```

## Debugging Techniques

### Basic Debugging Commands

```bash
# Check pod status
kubectl get pods -n <namespace> -o wide

# Check pod details
kubectl describe pod -n <namespace> <pod-name>

# Check logs
kubectl logs -n <namespace> <pod-name>

# Follow logs
kubectl logs -n <namespace> <pod-name> -f

# Check events
kubectl get events -n <namespace> --sort-by='.lastTimestamp'
```

### Advanced Debugging

#### Shell Access

```bash
kubectl exec -it -n <namespace> <pod-name> -- /bin/sh
```

#### Testing Network Connectivity

```bash
# Install debugging tools
kubectl exec -it -n <namespace> <pod-name> -- apk add --no-cache curl netcat-openbsd

# Test DNS resolution
kubectl exec -it -n <namespace> <pod-name> -- nslookup postgresql-ha-pgpool

# Test TCP connection
kubectl exec -it -n <namespace> <pod-name> -- nc -zv postgresql-ha-pgpool 5432
```

#### Checking Mounted Volumes

```bash
kubectl exec -it -n <namespace> <pod-name> -- df -h
kubectl exec -it -n <namespace> <pod-name> -- ls -la /config
```

#### Validating Configuration

```bash
kubectl exec -it -n <namespace> <pod-name> -- cat /config/config.toml
```

### Profile-Specific Troubleshooting

#### Tiny Profile

Common issues:
- Resource constraints on small devices
- Filesystem storage limitations

Debugging:
```bash
kubectl exec -it -n <namespace> <pod-name> -- df -h /opt/stalwart-mail/data
kubectl top pods -n <namespace>
```

#### Small Profile

Common issues:
- RWO limitations when scaling to 2 replicas
- PostgreSQL standalone connection issues

Debugging:
```bash
kubectl get pvc -n <namespace>
kubectl describe pvc -n <namespace> <pvc-name>
```

#### Medium Profile

Common issues:
- PostgreSQL HA configuration
- Pod anti-affinity requirements

Debugging:
```bash
kubectl get pods -n <namespace> -l app.kubernetes.io/name=postgresql-ha -o wide
kubectl describe pods -n <namespace> <stalwart-pod-name> | grep affinity -A 10
```

#### Large Profile

Common issues:
- Redis Sentinel configuration
- KEDA autoscaling issues
- Complex network policies

Debugging:
```bash
kubectl get pods -n <namespace> -l app.kubernetes.io/name=redis -o wide
kubectl get hpa -n <namespace>
kubectl describe scaledobject -n <namespace> <scaled-object-name>
```

## Specific Error Scenarios

### "Connection refused" to PostgreSQL

**Symptoms**:
- Logs show `connection refused` errors
- Pods crash with database connection errors

**Debugging**:
```bash
# Check if PostgreSQL is running
kubectl get pods -n <namespace> -l app.kubernetes.io/name=postgresql-ha

# Check if service exists and has endpoints
kubectl get svc -n <namespace> <postgresql-service>
kubectl get endpoints -n <namespace> <postgresql-service>

# Check NetworkPolicies
kubectl get networkpolicy -n <namespace>

# Test connectivity from Stalwart pod
kubectl exec -it -n <namespace> <stalwart-pod> -- sh -c "nc -zv <postgresql-service> 5432"
```

**Solution**:
1. Ensure PostgreSQL pods are running
2. Check service names and ports match configuration
3. Verify NetworkPolicies allow database traffic
4. Check PostgreSQL credentials are correct

### TLS Certificate Issues

**Symptoms**:
- HTTPS connections fail
- Email clients report certificate errors
- Let's Encrypt failures

**Debugging**:
```bash
# Check certificate
kubectl describe secret -n <namespace> <tls-secret>

# Check cert-manager (if used)
kubectl get certificate -n <namespace>
kubectl describe certificate -n <namespace> <certificate-name>
kubectl get certificaterequest -n <namespace>
kubectl get order -n <namespace>
kubectl get challenge -n <namespace>
```

**Solution**:
1. Verify DNS records point to correct IP
2. Check cert-manager configuration
3. Check Stalwart TLS configuration
4. Manually create certificate if needed

### Emails Rejected by External Servers

**Symptoms**:
- Outgoing emails rejected by Gmail, Yahoo, etc.
- NDR messages indicating spam or authentication issues

**Debugging**:
```bash
# Check outbound mail logs
kubectl logs -n <namespace> <stalwart-pod> | grep "rejected"

# Check DNS records
dig TXT example.com  # For SPF
dig TXT selector._domainkey.example.com  # For DKIM
dig TXT _dmarc.example.com  # For DMARC
```

**Solution**:
1. Configure proper reverse DNS
2. Set up SPF, DKIM, and DMARC records
3. Ensure IP address is not on blacklists
4. Configure proper HELO/EHLO

## Common Questions and Answers

### Q: How do I scale my deployment?

**A**: Use the `replicaCount` parameter:
```bash
helm upgrade stalwart-mail ./stalwart-mail-server --set stalwart.replicaCount=3
```

For automatic scaling, enable HPA:
```bash
helm upgrade stalwart-mail ./stalwart-mail-server --set autoscaling.enabled=true
```

### Q: How do I backup my mail data?

**A**: Enable the backup feature:
```yaml
backup:
  enabled: true
  schedule: "0 2 * * *"  # Daily at 2 AM
  retention: "30d"
  storage:
    type: "s3"
    bucket: "mail-backups"
    region: "us-east-1"
```

Alternatively, use Velero for Kubernetes-native backups.

### Q: How do I monitor my mail server?

**A**: Enable the ServiceMonitor:
```yaml
monitoring:
  serviceMonitor:
    enabled: true
```

And deploy Prometheus/Grafana in your cluster.

### Q: How do I migrate from one profile to another?

**A**: Generally, you can upgrade directly:
```bash
helm upgrade stalwart-mail ./stalwart-mail-server --set global.profile=medium
```

For major profile changes (e.g., tiny to large), consider:
1. Backup all data
2. Export email accounts
3. Deploy fresh installation
4. Import accounts and data

## Reporting Issues

If you encounter issues that cannot be resolved using this guide:

1. Check the [Stalwart documentation](https://stalw.art/docs/)
2. Check the [GitHub repository issues](https://github.com/stalwartlabs/mail-server/issues)
3. Open a new issue with:
   - Detailed description
   - Kubernetes version
   - Helm chart version
   - Full error messages
   - `helm get values` output (sanitized)