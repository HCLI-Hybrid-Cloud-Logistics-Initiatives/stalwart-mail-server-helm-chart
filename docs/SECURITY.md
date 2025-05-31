# Security Guide for Stalwart Mail Server Helm Chart

This document outlines the comprehensive security measures implemented in the Stalwart Mail Server Helm chart and provides guidance for maintaining a secure mail server deployment.

## Table of Contents

- [Security Architecture](#security-architecture)
- [Pod Security Standards](#pod-security-standards)
- [Network Security](#network-security)
- [Secret Management](#secret-management)
- [RBAC and Service Accounts](#rbac-and-service-accounts)
- [Database Security](#database-security)
- [Mail-Specific Security](#mail-specific-security)
- [Monitoring and Auditing](#monitoring-and-auditing)
- [Security Hardening Checklist](#security-hardening-checklist)
- [Compliance](#compliance)

## Security Architecture

The Stalwart Mail Server Helm chart implements a defense-in-depth security strategy with multiple layers of protection:

### 1. Pod-Level Security

- **Non-root containers**: All containers run as unprivileged user (UID 65534)
- **Read-only filesystem**: Root filesystem is mounted read-only
- **Capabilities dropped**: All Linux capabilities are dropped
- **Secure context**: No privilege escalation allowed

### 2. Network-Level Security

- **NetworkPolicies**: Micro-segmentation between components
- **Pod anti-affinity**: Prevents co-location of critical pods
- **Service exposure**: Only necessary ports are exposed
- **Ingress security**: TLS termination and certificate management

### 3. Application-Level Security

- **Configuration isolation**: PVC-based configuration management
- **Database encryption**: TLS connections to PostgreSQL
- **Redis security**: Authentication and encrypted connections
- **Mail security**: DKIM, SPF, DMARC support

## Pod Security Standards

The chart implements the **Restricted** Pod Security Standard by default, which provides the highest level of security constraints.

### Restricted Policy Configuration

```yaml
securityContext:
  runAsNonRoot: true
  runAsUser: 65534
  runAsGroup: 65534
  fsGroup: 65534
  allowPrivilegeEscalation: false
  capabilities:
    drop:
      - ALL
  readOnlyRootFilesystem: true
  seccompProfile:
    type: RuntimeDefault
```

### Pod Security Context

```yaml
podSecurityContext:
  runAsNonRoot: true
  runAsUser: 65534
  runAsGroup: 65534
  fsGroup: 65534
  seccompProfile:
    type: RuntimeDefault
```

### Security Profile Options

You can adjust the security profile based on your environment:

**Restricted** (Default):
- Maximum security constraints
- Suitable for production environments
- May require additional configuration for some features

**Baseline**:
- Moderate security constraints
- Better compatibility with legacy applications
- Prevents known privilege escalations

**Privileged**:
- No security constraints
- Only recommended for development/testing
- Should not be used in production

Example configuration:

```yaml
security:
  podSecurityStandards: "restricted"  # baseline, privileged
```

## Network Security

### NetworkPolicies

The chart implements comprehensive NetworkPolicies to control traffic between components:

#### Default Deny-All Policy

```yaml
security:
  networkPolicies:
    enabled: true
    denyAll: true  # Deny all traffic by default
```

#### Specific Allow Rules

1. **Mail Protocol Access**:
   - Allows inbound traffic on standard mail ports (25, 143, 587, 993, etc.)
   - No source restrictions for legitimate mail traffic

2. **Admin Interface Access**:
   - Restricted access to web admin interface (port 8080/443)
   - Can be limited to specific IP ranges or namespaces

3. **Database Communication**:
   - Stalwart → PostgreSQL: Port 5432
   - Stalwart → Redis: Port 6379/26379

4. **Inter-Pod Communication**:
   - Limited to same namespace by default
   - Additional namespaces can be allowed explicitly

#### Custom NetworkPolicy Example

```yaml
security:
  networkPolicies:
    enabled: true
    denyAll: true
    allowNamespaces:
      - monitoring
      - ingress-nginx
    custom:
    - apiVersion: networking.k8s.io/v1
      kind: NetworkPolicy
      metadata:
        name: allow-admin-access
      spec:
        podSelector:
          matchLabels:
            app.kubernetes.io/name: stalwart-mail-server
        policyTypes:
        - Ingress
        ingress:
        - from:
          - ipBlock:
              cidr: 10.0.0.0/8  # Internal network only
          ports:
          - protocol: TCP
            port: 8080
```

### Pod Anti-Affinity

Mandatory pod anti-affinity ensures high availability and prevents security vulnerabilities from affecting multiple instances:

```yaml
podAntiAffinity:
  enabled: true
  type: "requiredDuringSchedulingIgnoredDuringExecution"
  topologyKey: "kubernetes.io/hostname"
```

This configuration:
- Prevents multiple Stalwart pods on the same node
- Ensures resilience against node-level failures
- Reduces impact of security breaches

## Secret Management

### Kubernetes Secrets

The chart uses Kubernetes Secrets for sensitive data:

1. **Auto-generated passwords**: Random passwords for admin and database users
2. **External secret integration**: Support for External Secrets Operator
3. **Secret rotation**: Automated secret rotation capabilities

### Secret Types

| Secret | Purpose | Generation |
|--------|---------|------------|
| `admin-password` | Stalwart admin access | Auto-generated |
| `db-password` | PostgreSQL connection | Auto-generated |
| `redis-password` | Redis authentication | Auto-generated |

### External Secrets Integration

For production environments, integrate with external secret management systems:

```yaml
# Example with AWS Secrets Manager
security:
  serviceAccount:
    annotations:
      eks.amazonaws.com/role-arn: "arn:aws:iam::account:role/stalwart-secrets-role"

# External secret configuration
apiVersion: external-secrets.io/v1beta1
kind: SecretStore
metadata:
  name: aws-secrets-manager
spec:
  provider:
    aws:
      service: SecretsManager
      region: us-east-1
      auth:
        jwt:
          serviceAccountRef:
            name: stalwart-mail-sa
```

### Secret Rotation

Implement regular secret rotation:

1. **Automated rotation**: Using External Secrets Operator
2. **Manual rotation**: Through Helm upgrades
3. **Zero-downtime rotation**: Rolling updates preserve availability

## RBAC and Service Accounts

### Service Account Configuration

```yaml
security:
  serviceAccount:
    create: true
    name: "stalwart-mail-sa"
    automountServiceAccountToken: false  # Disabled by default
    annotations:
      # Cloud provider specific annotations
      eks.amazonaws.com/role-arn: "arn:aws:iam::account:role/stalwart-role"
```

### RBAC Permissions

Minimal RBAC permissions are granted:

```yaml
rules:
- apiGroups: [""]
  resources: ["configmaps"]
  verbs: ["get", "list", "watch"]
- apiGroups: [""]
  resources: ["secrets"]
  verbs: ["get", "list", "watch"]
- apiGroups: [""]
  resources: ["pods"]
  verbs: ["get", "list"]  # For clustering coordination
```

### Additional Security Measures

1. **ServiceAccount token mounting disabled**: Prevents unnecessary access to Kubernetes API
2. **Namespace-scoped permissions**: No cluster-wide access
3. **Read-only access**: No write permissions to cluster resources

## Database Security

### PostgreSQL HA Security

1. **Encrypted connections**: TLS encryption for all database connections
2. **Strong authentication**: Password-based authentication with strong passwords
3. **Network isolation**: Database access restricted via NetworkPolicies
4. **Backup encryption**: Encrypted backups with Velero

```yaml
postgresql-ha:
  postgresql:
    tls:
      enabled: true
      certificatesSecret: "postgresql-tls"
      certFilename: "tls.crt"
      certKeyFilename: "tls.key"
    auth:
      password: "StrongRandomPassword"
      postgresPassword: "AnotherStrongPassword"
```

### Redis Security

1. **Authentication enabled**: Password-based authentication
2. **TLS encryption**: Encrypted client connections
3. **Sentinel mode**: HA configuration with Sentinel monitoring

```yaml
redis:
  auth:
    enabled: true
    password: "SecureRedisPassword"
  tls:
    enabled: true
    certificatesSecret: "redis-tls"
    certFilename: "tls.crt"
    certKeyFilename: "tls.key"
```

## Mail-Specific Security

### Transport Security

1. **TLS encryption**: Enforced for all client connections
2. **STARTTLS**: Available for SMTP submission
3. **Strong cipher suites**: Modern encryption algorithms only

### Authentication Mechanisms

1. **SASL support**: Multiple authentication mechanisms
2. **OAuth2/OIDC**: Modern authentication protocols
3. **Failed login protection**: Brute force protection

### Anti-Spam and Security

1. **Built-in spam filter**: Comprehensive spam detection
2. **Virus scanning**: Optional virus scanning integration
3. **Rate limiting**: Connection and sending rate limits
4. **Greylisting**: Temporary rejection of suspicious emails

### Mail Authentication

1. **DKIM signing**: Domain-based message authentication
2. **SPF validation**: Sender policy framework
3. **DMARC enforcement**: Domain-based message authentication reporting

Example configuration:

```toml
# DKIM configuration
[directory.domains."example.com".dkim]
selector = "default"
algorithm = "ed25519"
headers = ["From", "Subject", "Date", "To", "Message-ID"]

# SPF configuration
[session.rcpt]
spf = [ { if = "!spf_pass", then = "reject" },
        { else = "continue" } ]

# DMARC configuration
[session.data]
dmarc = [ { if = "!dmarc_pass", then = "reject" },
          { else = "continue" } ]
```

## Monitoring and Auditing

### Security Monitoring

1. **Prometheus metrics**: Security-related metrics
2. **Log aggregation**: Centralized security logs
3. **Alert management**: Security alerts and notifications

### Audit Logging

Enable comprehensive audit logging:

```yaml
config:
  content: |
    [storage.logs]
    level = "info"
    format = "json"
    audit = true
    
    [storage.logs.audit]
    authentication = true
    authorization = true
    configuration_changes = true
    mail_flow = true
```

### Security Metrics

Monitor these security-related metrics:

- Failed authentication attempts
- Rejected emails (spam, virus, policy)
- TLS connection failures
- Configuration changes

## Security Hardening Checklist

### Pre-Deployment

- [ ] Review all default passwords and generate strong ones
- [ ] Configure external secret management (recommended for production)
- [ ] Set up TLS certificates (Let's Encrypt or custom)
- [ ] Review NetworkPolicy configurations
- [ ] Verify storage encryption capabilities

### Post-Deployment

- [ ] Change default admin password
- [ ] Configure DKIM, SPF, and DMARC records
- [ ] Set up monitoring and alerting
- [ ] Test mail authentication mechanisms
- [ ] Verify network isolation
- [ ] Review pod security context

### Ongoing Maintenance

- [ ] Regular security updates
- [ ] Secret rotation
- [ ] Certificate renewal
- [ ] Security audit reviews
- [ ] Log analysis and monitoring

## Compliance

### Standards Support

The chart helps meet various compliance standards:

**GDPR**:
- Data encryption at rest and in transit
- Audit logging capabilities
- Data retention policies
- Right to data deletion

**SOC 2**:
- Access controls and authentication
- Data protection measures
- Monitoring and logging
- Incident response capabilities

**HIPAA** (with additional configuration):
- Encryption requirements
- Access controls
- Audit trails
- Risk assessments

### Compliance Configuration Example

```yaml
# GDPR compliance settings
config:
  content: |
    # Data retention policies
    [store.data.retention]
    emails = "7y"  # 7 years
    logs = "1y"    # 1 year
    personal_data = "3y"  # 3 years
    
    # Audit logging
    [storage.logs.audit]
    level = "detailed"
    personal_data_access = true
    data_modifications = true
    deletions = true

# Backup encryption
backup:
  enabled: true
  encryption:
    enabled: true
    kmsKeyId: "arn:aws:kms:region:account:key/key-id"
```

## Security Incident Response

### Incident Detection

Monitor for:
1. Unusual authentication patterns
2. Large volumes of rejected emails
3. Configuration changes
4. Network policy violations

### Response Procedures

1. **Immediate containment**: Use NetworkPolicies to isolate affected components
2. **Investigation**: Analyze logs and metrics
3. **Remediation**: Apply fixes and updates
4. **Recovery**: Restore from secure backups if needed

### Recovery Planning

1. **Backup verification**: Regular testing of backup restoration
2. **Disaster recovery**: Documented procedures for full environment restoration
3. **Communication plan**: Stakeholder notification procedures

## Additional Security Considerations

### Development vs. Production

**Development environments**:
- Can use relaxed security settings for easier debugging
- Should still follow basic security practices
- Must not contain production data

**Production environments**:
- Must implement all security measures
- Require comprehensive monitoring
- Need incident response plans

### Regular Security Updates

1. **Chart updates**: Keep the Helm chart updated
2. **Image updates**: Regularly update Stalwart and dependency images
3. **Security patches**: Apply security patches promptly
4. **Configuration reviews**: Regular security configuration audits

### Security Resources

- [Kubernetes Security Best Practices](https://kubernetes.io/docs/concepts/security/)
- [NSA/CISA Kubernetes Hardening Guidance](https://www.nsa.gov/News-Features/Feature-Stories/Article-View/Article/2716980/nsa-cisa-release-kubernetes-hardening-guidance/)
- [CIS Kubernetes Benchmark](https://www.cisecurity.org/benchmark/kubernetes)
- [OWASP Container Security](https://owasp.org/www-project-container-security/)

By following this security guide, you can ensure that your Stalwart Mail Server deployment maintains the highest security standards while providing reliable mail services.