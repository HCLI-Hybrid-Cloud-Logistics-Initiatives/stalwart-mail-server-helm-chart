# Production Deployment Example for Stalwart Mail Server

This example provides a comprehensive production deployment configuration for Stalwart Mail Server, suitable for enterprise environments and hosting providers. It demonstrates advanced features, security hardening, and high availability configuration.

## Production Deployment with High Availability and Security Hardening

```yaml
# production-values.yaml

# Global settings
global:
  profile: "large"  # Use large profile as a base
  storageClass: "premium-ssd"  # Use high-performance storage
  imageRegistry: "docker.io"

# Stalwart configuration
stalwart:
  # High availability with 5 replicas
  replicaCount: 5
  
  # Rolling update strategy
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxSurge: 1
      maxUnavailable: 1
  
  # Enhanced resources for high traffic
  resources:
    limits:
      cpu: 3000m  # 3 CPUs
      memory: 6Gi
    requests:
      cpu: 1500m  # 1.5 CPUs
      memory: 3Gi
  
  # Multi-zone distribution with strict anti-affinity
  podAntiAffinity:
    enabled: true
    type: "requiredDuringSchedulingIgnoredDuringExecution"
    topologyKey: "kubernetes.io/hostname"
  
  # Zone-level anti-affinity
  affinity:
    podAntiAffinity:
      preferredDuringSchedulingIgnoredDuringExecution:
      - weight: 100
        podAffinityTerm:
          labelSelector:
            matchExpressions:
            - key: app.kubernetes.io/name
              operator: In
              values: ["stalwart-mail-server"]
          topologyKey: "topology.kubernetes.io/zone"
  
  # Enhanced pod disruption budget
  podDisruptionBudget:
    enabled: true
    minAvailable: 3  # Always keep at least 3 instances running
  
  # Node selection for mail workloads
  nodeSelector:
    workload-type: "mail-server"
  
  # Tolerate dedicated mail nodes
  tolerations:
  - key: "mail-server"
    operator: "Equal"
    value: "true"
    effect: "NoSchedule"
  
  # Enhanced probes for better reliability
  livenessProbe:
    initialDelaySeconds: 60
    periodSeconds: 15
    timeoutSeconds: 10
    failureThreshold: 5
  readinessProbe:
    initialDelaySeconds: 30
    periodSeconds: 10
    timeoutSeconds: 5
    failureThreshold: 3
  startupProbe:
    initialDelaySeconds: 60
    periodSeconds: 10
    timeoutSeconds: 5
    failureThreshold: 30
  
  # Critical workload priority
  priorityClassName: "production-critical"
  
  # Increased termination grace period
  terminationGracePeriodSeconds: 180
  
  # Additional annotations for observability
  podAnnotations:
    prometheus.io/scrape: "true"
    prometheus.io/port: "8080"
    prometheus.io/path: "/metrics"

# Enhanced storage configuration
storage:
  type: "pvc"
  pvc:
    enabled: true
    accessMode: "ReadWriteMany"
    size: "200Gi"  # Larger storage for production
    storageClass: "premium-ssd-repl"  # Replicated storage class
    annotations:
      backup.velero.io/backup-volumes: "data-storage"
    config:
      enabled: true
      accessMode: "ReadWriteMany"
      size: "10Gi"
      storageClass: "premium-ssd-repl"
      annotations:
        backup.velero.io/backup-volumes: "config-storage"

# Advanced configuration
config:
  type: "pvc"
  hostname: "mail.company.com"
  content: |
    [server]
    hostname = "mail.company.com"
    
    [cluster]
    node-id = 1  # Will be overridden by NODE_ID env var
    coordinator = "redis"
    
    # Roles distribution
    [cluster.roles.purge]
    stores = [1, 2]
    accounts = [1, 2]
    
    [cluster.roles.acme]
    renew = [3, 4]
    
    [cluster.roles.metrics]
    calculate = [5]
    push = [5]
    
    # PostgreSQL HA backend with enhanced configuration
    [store."data"]
    type = "postgresql"
    url = "postgresql://stalwart:${SECRET:db-password}@${RELEASE_NAME}-postgresql-ha-pgpool:5432/stalwart"
    max-connections = 100
    min-connections = 10
    idle-timeout = "10m"
    connect-timeout = "5s"
    
    [store."blob"]
    type = "postgresql"
    url = "postgresql://stalwart:${SECRET:db-password}@${RELEASE_NAME}-postgresql-ha-pgpool:5432/stalwart"
    max-connections = 50
    min-connections = 5
    
    [store."fts"]
    type = "postgresql"
    url = "postgresql://stalwart:${SECRET:db-password}@${RELEASE_NAME}-postgresql-ha-pgpool:5432/stalwart"
    max-connections = 20
    min-connections = 2
    
    [store."lookup"]
    type = "postgresql"
    url = "postgresql://stalwart:${SECRET:db-password}@${RELEASE_NAME}-postgresql-ha-pgpool:5432/stalwart"
    max-connections = 20
    min-connections = 2
    
    # Redis for coordination and caching with sentinel
    [store."redis"]
    type = "redis"
    url = "redis+sentinel://:${SECRET:redis-password}@${RELEASE_NAME}-redis:26379/mymaster"
    
    [store."in-memory"]
    type = "redis"
    url = "redis+sentinel://:${SECRET:redis-password}@${RELEASE_NAME}-redis:26379/mymaster"
    
    # Production SMTP configuration
    [session.smtp]
    max-connections = 1000
    timeout = "10m"
    
    [queue.outbound]
    next-hop = ["mx1.company.com", "mx2.company.com", "mx3.company.com"]
    retry = ["2m", "5m", "10m", "15m", "30m", "1h", "2h", "4h", "8h", "12h"]
    max-attempts = 15
    
    # Production IMAP configuration
    [session.imap]
    max-connections = 500
    timeout = "30m"
    
    # Advanced spam filtering
    [session.rcpt]
    relay = [ { if = "!is_authenticated", then = false },
              { else = true } ]
              
    [session.data]
    pipe = [ { if = "is_spam", then = "reject" },
             { if = "is_phishing", then = "reject" },
             { if = "is_virus", then = "reject" },
             { else = "accept" } ]
             
    # Rate limiting
    [session.throttle]
    rate = [ { if = "is_authenticated", then = "5000/1h" },
             { else = "10/1h" } ]
    
    # TLS configuration
    [server.tls]
    implicit = true
    protocols = ["TLSv1.2", "TLSv1.3"]
    cipher-suites = ["TLS_ECDHE_ECDSA_WITH_AES_256_GCM_SHA384", "TLS_ECDHE_RSA_WITH_AES_256_GCM_SHA384"]
    
    # ACME configuration
    [server.tls.acme]
    enabled = true
    provider = "letsencrypt"
    contact = ["admin@company.com"]
    
    # Directory configuration
    [directory]
    domains = ["company.com", "subsidiary.com"]
    admin-email = "admin@company.com"
    
    # DKIM configuration
    [directory.domains."company.com".dkim]
    selector = "default"
    algorithm = "ed25519"
    
    # Enhanced logs
    [storage.logs]
    directory = "/var/log/stalwart"
    level = "info"
    format = "json"

# PostgreSQL HA with enhanced configuration
postgresql-ha:
  enabled: true
  
  postgresql:
    replicaCount: 3
    database: stalwart
    username: stalwart
    password: "ChangeMe123!"  # Should be changed or generated
    syncReplication: true
    
    # Enhanced resources
    resources:
      limits:
        cpu: 4000m  # 4 CPUs
        memory: 8Gi
      requests:
        cpu: 2000m  # 2 CPUs
        memory: 4Gi
    
    # PostgreSQL configuration tuning
    postgresqlConfiguration:
      max_connections: "500"
      shared_buffers: "2GB"
      effective_cache_size: "6GB"
      maintenance_work_mem: "512MB"
      checkpoint_completion_target: "0.9"
      wal_buffers: "16MB"
      default_statistics_target: "100"
      random_page_cost: "1.1"
      effective_io_concurrency: "200"
      work_mem: "10MB"
      min_wal_size: "1GB"
      max_wal_size: "4GB"
    
    # Strict anti-affinity
    podAntiAffinityPreset: hard
    nodeAffinityPreset:
      type: soft
      key: role
      values:
        - database
    
    # PVC annotations for backup
    persistence:
      annotations:
        backup.velero.io/backup-volumes: "data"
    
  pgpool:
    replicaCount: 2  # HA Pgpool
    resources:
      limits:
        cpu: 2000m
        memory: 2Gi
      requests:
        cpu: 1000m
        memory: 1Gi
    
    # Pgpool configuration
    pgpoolConfiguration:
      num_init_children: "100"
      max_pool: "4"
      connection_life_time: "900"
      client_idle_limit: "300"
      connection_cache: "on"
      load_balance_mode: "on"
    
    # Strict anti-affinity
    podAntiAffinityPreset: hard
    
  persistence:
    enabled: true
    size: 500Gi
    storageClass: "premium-ssd"
    
  metrics:
    enabled: true
    serviceMonitor:
      enabled: true
      interval: "30s"
      scrapeTimeout: "10s"
      namespace: "monitoring"
      additionalLabels:
        release: prometheus

# Redis HA with Sentinel
redis:
  enabled: true
  architecture: replication
  
  auth:
    enabled: true
    password: "ChangeMe456!"  # Should be changed or generated
    
  master:
    resources:
      limits:
        cpu: 2000m
        memory: 4Gi
      requests:
        cpu: 1000m
        memory: 2Gi
    persistence:
      enabled: true
      size: 50Gi
      storageClass: "premium-ssd"
    
  replica:
    replicaCount: 3
    resources:
      limits:
        cpu: 2000m
        memory: 4Gi
      requests:
        cpu: 1000m
        memory: 2Gi
    persistence:
      enabled: true
      size: 50Gi
      storageClass: "premium-ssd"
    
  sentinel:
    enabled: true
    resources:
      limits:
        cpu: 500m
        memory: 1Gi
      requests:
        cpu: 250m
        memory: 512Mi
    
  metrics:
    enabled: true
    serviceMonitor:
      enabled: true
      namespace: "monitoring"
      interval: "30s"
      labels:
        release: prometheus

# Maximum security hardening
security:
  podSecurityStandards: "restricted"
  networkPolicies:
    enabled: true
    denyAll: true
    allowNamespaces: ["monitoring", "ingress-nginx", "cert-manager"]
    custom:
    - apiVersion: networking.k8s.io/v1
      kind: NetworkPolicy
      metadata:
        name: allow-specific-ips
      spec:
        podSelector:
          matchLabels:
            app.kubernetes.io/name: stalwart-mail-server
        policyTypes:
        - Ingress
        ingress:
        - from:
          - ipBlock:
              cidr: 10.0.0.0/8
          - ipBlock:
              cidr: 192.168.0.0/16
        ports:
        - protocol: TCP
          port: 25
        - protocol: TCP
          port: 587
  
  serviceAccount:
    create: true
    name: "stalwart-mail-sa"
    automountServiceAccountToken: false
    annotations:
      eks.amazonaws.com/role-arn: "arn:aws:iam::123456789012:role/stalwart-mail-role"
  
  rbac:
    create: true
    rules:
    - apiGroups: [""]
      resources: ["configmaps"]
      verbs: ["get", "list", "watch"]
    - apiGroups: [""]
      resources: ["secrets"]
      verbs: ["get", "list", "watch"]
    - apiGroups: [""]
      resources: ["pods"]
      verbs: ["get", "list"]

# Comprehensive monitoring and observability
monitoring:
  serviceMonitor:
    enabled: true
    namespace: "monitoring"
    labels:
      release: prometheus
    interval: "15s"
    scrapeTimeout: "10s"
    
  grafana:
    enabled: true
    dashboard: true

# Autoscaling with HPA and KEDA
autoscaling:
  enabled: true
  minReplicas: 5
  maxReplicas: 15
  targetCPUUtilizationPercentage: 70
  targetMemoryUtilizationPercentage: 80
  
  # KEDA for advanced autoscaling
  keda:
    enabled: true
    triggers:
    - type: prometheus
      metadata:
        serverAddress: http://prometheus-operated.monitoring.svc.cluster.local:9090
        metricName: stalwart_smtp_queue_size
        threshold: "100"
        query: sum(stalwart_smtp_queue_size)
    - type: prometheus
      metadata:
        serverAddress: http://prometheus-operated.monitoring.svc.cluster.local:9090
        metricName: stalwart_connections_active
        threshold: "500"
        query: sum(stalwart_connections_active)
    behavior:
      scaleDown:
        stabilizationWindowSeconds: 300
        policies:
        - type: Pods
          value: 1
          periodSeconds: 60
      scaleUp:
        stabilizationWindowSeconds: 0
        policies:
        - type: Percent
          value: 100
          periodSeconds: 15

# Production service with advanced configuration
service:
  type: LoadBalancer
  externalTrafficPolicy: Local
  annotations:
    service.beta.kubernetes.io/aws-load-balancer-type: nlb
    service.beta.kubernetes.io/aws-load-balancer-cross-zone-load-balancing-enabled: "true"
    service.beta.kubernetes.io/aws-load-balancer-ssl-cert: "arn:aws:acm:region:account-id:certificate/certificate-id"
    service.beta.kubernetes.io/aws-load-balancer-ssl-ports: "443,465,993,995"
    service.beta.kubernetes.io/aws-load-balancer-backend-protocol: "tcp"

# Production ingress with advanced features
ingress:
  enabled: true
  className: "nginx"
  annotations:
    cert-manager.io/cluster-issuer: "letsencrypt-prod"
    nginx.ingress.kubernetes.io/ssl-redirect: "true"
    nginx.ingress.kubernetes.io/force-ssl-redirect: "true"
    nginx.ingress.kubernetes.io/proxy-body-size: "50m"
    nginx.ingress.kubernetes.io/proxy-connect-timeout: "60"
    nginx.ingress.kubernetes.io/proxy-read-timeout: "600"
    nginx.ingress.kubernetes.io/proxy-send-timeout: "600"
    nginx.ingress.kubernetes.io/configuration-snippet: |
      proxy_set_header X-Real-IP $remote_addr;
      proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    nginx.ingress.kubernetes.io/modsecurity-snippet: |
      SecRuleEngine On
      SecRequestBodyLimit 50000000
  hosts:
    - host: mail-admin.company.com
      paths:
        - path: /
          pathType: Prefix
  tls:
    - secretName: mail-admin-tls
      hosts:
        - mail-admin.company.com

# Production backup strategy
backup:
  enabled: true
  schedule: "0 */4 * * *"  # Every 4 hours
  retention: "30d"  # 30 days retention
  storage:
    type: "s3"
    bucket: "company-mail-backups"
    region: "us-east-1"
    accessKey: ""  # Should be provided via external secrets
    secretKey: ""  # Should be provided via external secrets

# Resource quotas for governance
resourceQuota:
  enabled: true
  limits:
    requests.cpu: "40"
    requests.memory: "80Gi"
    limits.cpu: "80"
    limits.memory: "160Gi"
    persistentvolumeclaims: "20"

# Extra resources like PodMonitor for custom monitoring
extraResources:
- apiVersion: monitoring.coreos.com/v1
  kind: PodMonitor
  metadata:
    name: stalwart-mail-detailed
    namespace: monitoring
  spec:
    selector:
      matchLabels:
        app.kubernetes.io/name: stalwart-mail-server
    podMetricsEndpoints:
    - port: webadmin
      path: /metrics
      interval: 15s
      metricRelabelings:
      - sourceLabels: [__name__]
        action: keep
        regex: ^stalwart_.*$
```

## Installation Instructions

1. Create a dedicated namespace:

```bash
kubectl create namespace mail-production
```

2. Create a secret for sensitive values:

```bash
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Secret
metadata:
  name: stalwart-mail-sensitive
  namespace: mail-production
type: Opaque
stringData:
  postgresql-password: "YourStrongPassword1"
  redis-password: "YourStrongPassword2"
EOF
```

3. Install the Helm chart with production values:

```bash
helm install stalwart-mail -n mail-production \
  -f production-values.yaml \
  --set postgresql-ha.postgresql.password=$(kubectl get secret -n mail-production stalwart-mail-sensitive -o jsonpath="{.data.postgresql-password}" | base64 --decode) \
  --set redis.auth.password=$(kubectl get secret -n mail-production stalwart-mail-sensitive -o jsonpath="{.data.redis-password}" | base64 --decode) \
  ./stalwart-mail-server
```

4. Verify all components are running correctly:

```bash
kubectl get pods,svc,pvc -n mail-production
```

5. Test mail functionality:

```bash
# Test SMTP
kubectl run -n mail-production --rm -it smtp-test --image=alpine -- sh -c "apk add --no-cache swaks && swaks --server stalwart-mail-stalwart-mail-server.mail-production.svc.cluster.local:25 --to test@example.com --from sender@example.com --body 'This is a test email'"

# Test IMAP (requires account setup first)
kubectl run -n mail-production --rm -it imap-test --image=alpine -- sh -c "apk add --no-cache curl && curl -v telnet://stalwart-mail-stalwart-mail-server.mail-production.svc.cluster.local:143"
```

## Production Checklist

- [ ] Review all passwords and ensure they are not stored in version control
- [ ] Configure monitoring alerts for mail server metrics
- [ ] Set up regular backups of PostgreSQL data
- [ ] Implement a disaster recovery plan
- [ ] Configure external SMTP relay for outbound mail (if needed)
- [ ] Set up DNS records (MX, SPF, DKIM, DMARC)
- [ ] Configure mail filtering and antispam settings
- [ ] Implement log aggregation and analysis
- [ ] Conduct a security audit of the deployment
- [ ] Test failover scenarios for all components