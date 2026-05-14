# Confluent Platform 8.1 with KRaft on Kubernetes - Installation Runbook

**Document Version:** 1.0  
**Confluent Platform Version:** 8.1.0  
**Target Environment:** Azure Kubernetes Service (AKS) / Any Kubernetes 1.25+  
**Date:** May 2026  
**Architecture:** KRaft Mode (Zookeeper-free)

---

## Table of Contents

1. [Overview](#overview)
2. [Architecture](#architecture)
3. [Prerequisites](#prerequisites)
4. [Pre-Installation Planning](#pre-installation-planning)
5. [Installation Steps](#installation-steps)
6. [Post-Installation Verification](#post-installation-verification)
7. [Accessing the Platform](#accessing-the-platform)
8. [Troubleshooting](#troubleshooting)
9. [Appendix](#appendix)

---

## 1. Overview

### What This Runbook Deploys

This runbook provides step-by-step instructions to deploy a production-ready Confluent Platform 8.1 cluster with the following components:

| Component | Version | Replicas | Purpose |
|-----------|---------|----------|---------|
| **KRaft Controller** | 8.1.0 | 1 | Metadata management (replaces Zookeeper) |
| **Kafka Brokers** | 8.1.0 | 3 | Message streaming and storage |
| **Control Center Next-Gen** | 2.4.1 | 1 | Web UI for monitoring and management |
| **Prometheus** | 2.4.1 | 1 (sidecar) | Metrics collection |
| **AlertManager** | 2.4.1 | 1 (sidecar) | Alert management |
| **Confluent Operator** | 0.1514.40 | 1 | Kubernetes operator for lifecycle management |

### Key Features

- ✅ **KRaft Mode**: Modern, Zookeeper-free architecture
- ✅ **High Availability**: 3 Kafka brokers with replication factor 3
- ✅ **External Access**: LoadBalancer services for external connectivity
- ✅ **Integrated Monitoring**: Prometheus and AlertManager embedded
- ✅ **Web UI**: Next-generation Control Center for management
- ✅ **Cloud Native**: Fully Kubernetes-native deployment

### Deployment Time

- **Estimated Duration**: 30-45 minutes
- **Prerequisites Setup**: 15-20 minutes
- **Installation**: 15-20 minutes
- **Verification**: 5-10 minutes

---

## 2. Architecture

### High-Level Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    Azure Load Balancers                     │
│  Control Center: 20.x.x.x:9021   Kafka: 20.x.x.x:9092      │
└──────────────────────┬──────────────────────────────────────┘
                       │
┌──────────────────────┴──────────────────────────────────────┐
│              Azure Kubernetes Service (AKS)                 │
│  ┌──────────────────────────────────────────────────────┐  │
│  │              Namespace: confluent                     │  │
│  │                                                        │  │
│  │  ┌──────────────────┐     ┌──────────────────┐       │  │
│  │  │ KRaft Controller │     │ Confluent        │       │  │
│  │  │   (1 replica)    │────▶│ Operator         │       │  │
│  │  └──────────────────┘     └──────────────────┘       │  │
│  │           │                                           │  │
│  │           │ manages metadata                          │  │
│  │           ▼                                           │  │
│  │  ┌──────────────────┐  ┌──────────────────┐          │  │
│  │  │   Kafka Broker   │  │   Kafka Broker   │          │  │
│  │  │     kafka-0      │  │     kafka-1      │ ....     │  │
│  │  │  (replication)   │◀▶│  (replication)   │          │  │
│  │  └──────────────────┘  └──────────────────┘          │  │
│  │                                                        │  │
│  │  ┌───────────────────────────────────────────┐       │  │
│  │  │         Control Center Pod                 │       │  │
│  │  │  ┌─────────────────────────────────────┐  │       │  │
│  │  │  │ Control Center (Main Container)    │  │       │  │
│  │  │  └─────────────────────────────────────┘  │       │  │
│  │  │  ┌─────────────────────────────────────┐  │       │  │
│  │  │  │ Prometheus (Sidecar)                │  │       │  │
│  │  │  └─────────────────────────────────────┘  │       │  │
│  │  │  ┌─────────────────────────────────────┐  │       │  │
│  │  │  │ AlertManager (Sidecar)              │  │       │  │
│  │  │  └─────────────────────────────────────┘  │       │  │
│  │  └───────────────────────────────────────────┘       │  │
│  └──────────────────────────────────────────────────────┘  │
│                                                             │
│  Storage: Azure Managed Disks (managed-csi)                │
└─────────────────────────────────────────────────────────────┘
```

### Network Flow

```
External Client
      ▼
LoadBalancer (20.x.x.x:9092)
      ▼
Kafka Service (ClusterIP)
      ▼
Kafka Pods (kafka-0, kafka-1, kafka-2)
      ▼
KRaft Controller (metadata)
      ▼
Azure Managed Disks (persistent storage)
```

---

## 3. Prerequisites

### 3.1 Infrastructure Requirements

#### Kubernetes Cluster

| Requirement | Specification |
|-------------|--------------|
| **Kubernetes Version** | 1.25+ (tested on 1.33.5) |
| **Node Count** | Minimum 3 nodes |
| **Node Size** | Standard_D4s_v3 or higher (4 vCPU, 16 GB RAM) |
| **Total CPU** | Minimum 12 vCPUs available |
| **Total Memory** | Minimum 24 GB RAM available |
| **Storage Class** | Dynamic provisioning enabled (e.g., managed-csi for AKS) |

#### Resource Allocation

**Per Component CPU/Memory Requirements:**

| Component | CPU Request | Memory Request | CPU Limit | Memory Limit | Storage |
|-----------|-------------|----------------|-----------|--------------|---------|
| KRaft Controller | 100m | 512Mi | 500m | 1Gi | 5Gi |
| Kafka Broker (×3) | 100m | 768Mi | 1000m | 2Gi | 10Gi each |
| Control Center | 50m | 768Mi | 1000m | 2Gi | 5Gi |
| Prometheus (sidecar) | - | - | - | - | 5Gi |
| Confluent Operator | 100m | 256Mi | 500m | 512Mi | - |

**Total Cluster Requirements:**
- **CPU Requests**: ~450m (0.45 cores)
- **Memory Requests**: ~3.5 Gi
- **Storage**: ~40 Gi

### 3.2 Software Prerequisites

#### Required Tools

| Tool | Version | Installation Check |
|------|---------|-------------------|
| **kubectl** | 1.25+ | `kubectl version --client` |
| **helm** | 3.10+ | `helm version` |
| **Azure CLI** (for AKS) | 2.40+ | `az --version` |
| **jq** (optional) | 1.6+ | `jq --version` |
| **git** (optional) | 2.30+ | `git --version` |

#### Install kubectl (if not installed)

```bash
# macOS
brew install kubectl

# Linux
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
chmod +x kubectl
sudo mv kubectl /usr/local/bin/

# Windows
choco install kubernetes-cli
```

#### Install Helm (if not installed)

```bash
# macOS
brew install helm

# Linux
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash

# Windows
choco install kubernetes-helm
```

### 3.3 Access Requirements

#### Kubernetes Cluster Access

```bash
# Verify kubectl can connect to your cluster
kubectl cluster-info

# Check nodes are ready
kubectl get nodes

# Verify you have cluster-admin permissions
kubectl auth can-i create namespace
# Should return: yes
```

#### Network Requirements

| Type | Description | Port | Protocol |
|------|-------------|------|----------|
| **External Access** | Control Center UI | 9021 | TCP |
| **External Access** | Kafka Bootstrap | 9092 | TCP |
| **Internal** | Kafka Inter-broker | 9071 | TCP |
| **Internal** | KRaft Controller | 9074 | TCP |
| **Internal** | Prometheus | 9090 | TCP |
| **Internal** | AlertManager | 9093 | TCP |

**Firewall Rules:**
- Ensure LoadBalancer services can obtain public IPs
- Allow inbound traffic on ports 9021 and 9092 from client networks

### 3.4 Permissions

#### Required Kubernetes RBAC Permissions

The user/service account performing the installation must have:

- Create/Delete/Update:
  - Namespaces
  - CustomResourceDefinitions (CRDs)
  - ClusterRoles, ClusterRoleBindings
  - Services, StatefulSets, Deployments
  - PersistentVolumeClaims
  - ConfigMaps, Secrets

```bash
# Verify permissions
kubectl auth can-i create crd
kubectl auth can-i create clusterrole
kubectl auth can-i create statefulset
```

---

## 4. Pre-Installation Planning

### 4.1 Capacity Planning

#### Storage Sizing

**Kafka Data Retention:**

```
Storage = (Messages/sec × Avg Message Size × Retention Period × Replication Factor) / Compression Ratio

Example:
- 10,000 msg/sec
- 1 KB avg message
- 7 days retention
- Replication factor 3
- 2x compression

Storage = (10000 × 1024 × 86400 × 7 × 3) / 2 = ~9 TB total (~3 TB per broker)
```

**Recommended Storage per Broker:**
- **Development**: 10-50 GB
- **Staging**: 100-500 GB
- **Production**: 500 GB - 10 TB

#### Scaling Considerations

| Scenario | Brokers | KRaft Controllers | Replication Factor |
|----------|---------|-------------------|-------------------|
| **Development** | 1 | 1 | 1 |
| **Staging/POC** | 3 | 1 | 3 |
| **Production (Small)** | 3-5 | 3 | 3 |
| **Production (Large)** | 10+ | 3-5 | 3 |

### 4.2 Naming Conventions

**Recommended Standards:**

```yaml
Namespace: confluent (or <env>-confluent for multi-env)
Release Name: confluent-operator
Cluster Name: Keep default (auto-generated)

Resource Labels:
  environment: production|staging|development
  app: confluent
  component: kafka|kraftcontroller|controlcenter
  managed-by: confluent-operator
```

### 4.3 Configuration Decisions

**Before Installation, Decide:**

1. **Kafka Broker Count**: 3 (recommended minimum for HA)
2. **KRaft Controller Count**: 1 for POC, 3 for production
3. **External Access**: LoadBalancer (yes/no)
4. **Storage Class**: managed-csi (AKS) or your cluster's default
5. **Replication Factor**: 3 for production, 1 for dev/test
6. **Resource Limits**: Based on expected throughput
7. **Monitoring**: Enable Prometheus/AlertManager (recommended)

---

## 5. Installation Steps

### Step 1: Prepare Directory Structure

```bash
# Create working directory
mkdir -p ~/confluent-platform-install
cd ~/confluent-platform-install

# Create subdirectories
mkdir -p manifests
mkdir -p scripts
mkdir -p docs
```

### Step 2: Verify Cluster Readiness

```bash
# Check cluster connectivity
kubectl cluster-info

# List nodes and verify resources
kubectl get nodes
kubectl top nodes  # Verify sufficient CPU/memory

# Check available storage classes
kubectl get storageclass

# Example output:
# NAME                    PROVISIONER             
# managed-csi (default)   disk.csi.azure.com      
# azurefile               file.csi.azure.com
```

**Expected Output:**
- All nodes in `Ready` state
- CPU usage < 80% on all nodes
- At least one storage class with dynamic provisioning

### Step 3: Create Namespace

```bash
# Create dedicated namespace for Confluent Platform
kubectl create namespace confluent

# Verify namespace creation
kubectl get namespace confluent

# Set as default namespace (optional)
kubectl config set-context --current --namespace=confluent
```

### Step 4: Install Confluent for Kubernetes Operator

```bash
# Add Confluent Helm repository
helm repo add confluentinc https://packages.confluent.io/helm

# Update Helm repositories
helm repo update

# Verify repository added successfully
helm search repo confluent

# Install Confluent Operator
helm upgrade --install confluent-operator \
  confluentinc/confluent-for-kubernetes \
  --namespace confluent \
  --create-namespace

# Expected output:
# Release "confluent-operator" does not exist. Installing it now.
# NAME: confluent-operator
# NAMESPACE: confluent
# STATUS: deployed
```

**Verification:**

```bash
# Check operator pod is running
kubectl get pods -n confluent

# Expected output:
# NAME                                  READY   STATUS    RESTARTS   AGE
# confluent-operator-xxxxx-xxxxx        1/1     Running   0          30s

# Check operator logs (should show no errors)
kubectl logs -n confluent -l app=confluent-operator --tail=50

# Verify CRDs are installed
kubectl get crd | grep confluent
# Should list: kafka, kraftcontroller, schemaregistry, etc.
```

**Wait for operator to be fully ready:**

```bash
kubectl wait --for=condition=ready pod \
  -l app=confluent-operator \
  -n confluent \
  --timeout=120s
```

### Step 5: Create Configuration Files

Create the following YAML files in the `manifests/` directory:

#### 5.1 KRaft Controller Configuration

**File: `manifests/kraftcontroller.yaml`**

```yaml
apiVersion: platform.confluent.io/v1beta1
kind: KRaftController
metadata:
  name: kraftcontroller
  namespace: confluent
spec:
  replicas: 1
  image:
    application: confluentinc/cp-server:8.1.0
    init: confluentinc/confluent-init-container:3.1.0
  dataVolumeCapacity: 5Gi
  storageClass:
    name: managed-csi  # Change to your storage class
  podTemplate:
    resources:
      requests:
        cpu: 100m
        memory: 512Mi
      limits:
        cpu: 500m
        memory: 1Gi
```

**Configuration Notes:**
- `replicas`: Set to 1 for POC, 3 for production
- `storageClass.name`: Use your cluster's storage class
- Adjust CPU/memory based on your requirements

#### 5.2 Kafka Broker Configuration

**File: `manifests/kafka.yaml`**

```yaml
apiVersion: platform.confluent.io/v1beta1
kind: Kafka
metadata:
  name: kafka
  namespace: confluent
spec:
  replicas: 3
  image:
    application: confluentinc/cp-server:8.1.0
    init: confluentinc/confluent-init-container:3.1.0
  dataVolumeCapacity: 10Gi
  storageClass:
    name: managed-csi  # Change to your storage class
  podTemplate:
    resources:
      requests:
        cpu: 100m
        memory: 768Mi
      limits:
        cpu: 1000m
        memory: 2Gi
  dependencies:
    kRaftController:
      clusterRef:
        name: kraftcontroller
  metricReporter:
    enabled: true
  listeners:
    external:
      externalAccess:
        type: loadBalancer
        loadBalancer:
          domain: "kafka.demo.local"  # Change to your domain
          advertisedPort: 9092
```

**Configuration Notes:**
- `replicas`: 3 brokers for high availability
- `dataVolumeCapacity`: Size based on retention requirements
- `listeners.external`: Set `type: nodePort` if LoadBalancer unavailable
- `domain`: Can be any value, used for advertised listeners

#### 5.3 Control Center Configuration

**File: `manifests/controlcenter.yaml`**

```yaml
apiVersion: platform.confluent.io/v1beta1
kind: ControlCenter
metadata:
  name: controlcenter
  namespace: confluent
spec:
  replicas: 1
  image:
    application: confluentinc/cp-enterprise-control-center-next-gen:2.4.1
    init: confluentinc/confluent-init-container:3.1.2
  dataVolumeCapacity: 5Gi
  storageClass:
    name: managed-csi  # Change to your storage class
  podTemplate:
    resources:
      requests:
        cpu: 50m
        memory: 768Mi
      limits:
        cpu: 1000m
        memory: 2Gi
  configOverrides:
    server:
      - confluent.controlcenter.internal.topics.replication=1
      - confluent.controlcenter.command.topic.replication=1
      - confluent.monitoring.interceptor.topic.replication=1
      - confluent.metrics.topic.replication=1
      - confluent.controlcenter.streams.num.stream.threads=1
  externalAccess:
    type: loadBalancer
    loadBalancer:
      domain: "c3.demo.local"  # Change to your domain
      port: 9021
  dependencies:
    kafka:
      bootstrapEndpoint: kafka.confluent.svc.cluster.local:9071
    prometheusClient:
      url: http://controlcenter.confluent.svc.cluster.local:9090
    alertManagerClient:
      url: http://controlcenter.confluent.svc.cluster.local:9093
  services:
    prometheus:
      image: confluentinc/cp-enterprise-prometheus:2.4.1
      pvc:
        dataVolumeCapacity: 5Gi
    alertmanager:
      image: confluentinc/cp-enterprise-alertmanager:2.4.1
```

**Configuration Notes:**
- Includes Prometheus and AlertManager as sidecars
- `configOverrides`: Replication set to 1 for single-broker setups (adjust for production)
- Set replication to 3 if using 3+ Kafka brokers

**Production Configuration Changes:**

For production deployments, update `configOverrides`:

```yaml
configOverrides:
  server:
    - confluent.controlcenter.internal.topics.replication=3
    - confluent.controlcenter.command.topic.replication=3
    - confluent.monitoring.interceptor.topic.replication=3
    - confluent.metrics.topic.replication=3
    - confluent.controlcenter.streams.num.stream.threads=2
```

### Step 6: Deploy Components

**Deploy in this order** (wait for each to be ready before proceeding):

#### 6.1 Deploy KRaft Controller

```bash
# Apply KRaft Controller manifest
kubectl apply -f manifests/kraftcontroller.yaml

# Monitor deployment
kubectl get kraftcontroller -n confluent -w

# Wait for RUNNING status
# Press Ctrl+C when STATUS shows RUNNING

# Check pod status
kubectl get pods -n confluent -l app=kraftcontroller

# Expected output:
# NAME                READY   STATUS    RESTARTS   AGE
# kraftcontroller-0   1/1     Running   0          2m
```

**Wait for KRaft Controller to be fully ready:**

```bash
# Wait up to 5 minutes
kubectl wait --for=condition=ready pod \
  -l app=kraftcontroller \
  -n confluent \
  --timeout=300s
```

**Verify KRaft Controller:**

```bash
# Check logs for successful startup
kubectl logs kraftcontroller-0 -n confluent | grep -i "started"

# Check resource status
kubectl describe kraftcontroller kraftcontroller -n confluent
```

#### 6.2 Deploy Kafka Brokers

```bash
# Apply Kafka manifest
kubectl apply -f manifests/kafka.yaml

# Monitor deployment (this will take 3-5 minutes)
kubectl get kafka -n confluent -w

# Check all broker pods
kubectl get pods -n confluent -l app=kafka

# Expected output:
# NAME      READY   STATUS    RESTARTS   AGE
# kafka-0   1/1     Running   0          3m
# kafka-1   1/1     Running   0          3m
# kafka-2   1/1     Running   0          3m
```

**Wait for all Kafka brokers:**

```bash
# Wait up to 10 minutes for all brokers
kubectl wait --for=condition=ready pod \
  -l app=kafka \
  -n confluent \
  --timeout=600s
```

**Verify Kafka Cluster:**

```bash
# Check cluster status
kubectl get kafka -n confluent

# Expected output:
# NAME    REPLICAS   READY   STATUS    AGE
# kafka   3          3       RUNNING   5m

# Verify all brokers are visible
kubectl exec -n confluent kafka-0 -- \
  kafka-broker-api-versions --bootstrap-server kafka:9071 | grep id

# Expected output (all 3 brokers):
# kafka-0...id: 0...
# kafka-1...id: 1...
# kafka-2...id: 2...
```

**Get External Access IP:**

```bash
# Get LoadBalancer IP for Kafka
kubectl get svc kafka-bootstrap-lb -n confluent

# Note the EXTERNAL-IP for client access
```

#### 6.3 Deploy Control Center

```bash
# Apply Control Center manifest
kubectl apply -f manifests/controlcenter.yaml

# Monitor deployment (this will take 2-4 minutes)
kubectl get controlcenter -n confluent -w

# Check Control Center pod (should show 3/3 containers)
kubectl get pods -n confluent -l app=controlcenter

# Expected output:
# NAME              READY   STATUS    RESTARTS   AGE
# controlcenter-0   3/3     Running   0          3m
```

**Verify Control Center:**

```bash
# Check pod has all 3 containers
kubectl describe pod controlcenter-0 -n confluent | grep "Container ID"

# Should show:
# - config-init-container (init)
# - prometheus
# - alertmanager  
# - controlcenter

# Get Control Center URL
kubectl get svc controlcenter-bootstrap-lb -n confluent

# Note the EXTERNAL-IP (e.g., 20.x.x.x)
# Access at: http://<EXTERNAL-IP>:9021
```

**Wait for Control Center:**

```bash
kubectl wait --for=condition=ready pod \
  -l app=controlcenter \
  -n confluent \
  --timeout=300s
```

### Step 7: Create Deployment Summary Script

**File: `scripts/get-access-info.sh`**

```bash
#!/bin/bash

echo "==================================================="
echo "  Confluent Platform 8.1 - Access Information"
echo "==================================================="
echo ""

# Get Kafka Bootstrap
KAFKA_IP=$(kubectl get svc kafka-bootstrap-lb -n confluent -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null)
if [ -z "$KAFKA_IP" ]; then
    echo "⏳ Kafka LoadBalancer IP: Pending..."
else
    echo "✅ Kafka Bootstrap Server: $KAFKA_IP:9092"
fi

# Get Control Center
C3_IP=$(kubectl get svc controlcenter-bootstrap-lb -n confluent -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null)
if [ -z "$C3_IP" ]; then
    echo "⏳ Control Center URL: Pending..."
else
    echo "✅ Control Center URL: http://$C3_IP:9021"
fi

echo ""
echo "==================================================="
echo "  Component Status"
echo "==================================================="
kubectl get kraftcontroller,kafka,controlcenter -n confluent

echo ""
echo "==================================================="
echo "  Pod Status"
echo "==================================================="
kubectl get pods -n confluent

echo ""
echo "Installation Complete! 🎉"
```

```bash
chmod +x scripts/get-access-info.sh
./scripts/get-access-info.sh
```

---

## 6. Post-Installation Verification

### 6.1 Component Health Checks

```bash
# Check all Confluent components
kubectl get kraftcontroller,kafka,controlcenter -n confluent

# All should show STATUS: RUNNING and READY: match REPLICAS
```

### 6.2 Pod Health Checks

```bash
# List all pods
kubectl get pods -n confluent

# Check for any pods not in Running state
kubectl get pods -n confluent | grep -v Running

# If any issues, check events
kubectl get events -n confluent --sort-by='.lastTimestamp' | tail -20
```

### 6.3 Create Test Topic

```bash
# Create a test topic with replication factor 3
kubectl exec -n confluent kafka-0 -- kafka-topics \
  --bootstrap-server kafka:9071 \
  --create \
  --topic test-replication \
  --partitions 6 \
  --replication-factor 3

# Verify topic creation
kubectl exec -n confluent kafka-0 -- kafka-topics \
  --bootstrap-server kafka:9071 \
  --describe \
  --topic test-replication

# Expected output shows:
# - Partition count: 6
# - Replication factor: 3
# - All replicas in-sync (ISR)
```

### 6.4 Test Producer/Consumer

**Test Message Flow:**

```bash
# Start producer (Terminal 1)
kubectl exec -it -n confluent kafka-0 -- kafka-console-producer \
  --bootstrap-server kafka:9071 \
  --topic test-replication

# Type a few messages, press Enter after each
# Message 1
# Message 2
# Message 3
# Press Ctrl+C to exit

# Start consumer (Terminal 2)
kubectl exec -it -n confluent kafka-0 -- kafka-console-consumer \
  --bootstrap-server kafka:9071 \
  --topic test-replication \
  --from-beginning

# Should see all 3 messages
# Press Ctrl+C to exit
```

### 6.5 Verify External Access

**Test Kafka External Access:**

```bash
# Get external IP
KAFKA_EXTERNAL=$(kubectl get svc kafka-bootstrap-lb -n confluent -o jsonpath='{.status.loadBalancer.ingress[0].ip}')

echo "Kafka accessible at: $KAFKA_EXTERNAL:9092"

# Test from local machine (if kafka CLI installed)
# kafka-topics --bootstrap-server $KAFKA_EXTERNAL:9092 --list
```

**Test Control Center Access:**

```bash
# Get Control Center URL
C3_URL=$(kubectl get svc controlcenter-bootstrap-lb -n confluent -o jsonpath='{.status.loadBalancer.ingress[0].ip}')

echo "Open in browser: http://$C3_URL:9021"

# Should show Control Center login/dashboard
```

### 6.6 Verify Monitoring Stack

```bash
# Check Prometheus is running
kubectl exec controlcenter-0 -n confluent -c prometheus -- \
  wget -qO- http://localhost:9090/-/healthy

# Expected: Prometheus is Healthy.

# Check AlertManager is running
kubectl exec controlcenter-0 -n confluent -c alertmanager -- \
  wget -qO- http://localhost:9093/-/healthy

# Expected: Alertmanager is Healthy.

# Port-forward to access Prometheus UI (optional)
kubectl port-forward -n confluent controlcenter-0 9090:9090
# Open: http://localhost:9090
```

### 6.7 Performance Baseline Test

```bash
# Run producer performance test
kubectl exec -n confluent kafka-0 -- kafka-producer-perf-test \
  --topic test-replication \
  --num-records 100000 \
  --record-size 1000 \
  --throughput 10000 \
  --producer-props bootstrap.servers=kafka:9071 acks=all

# Note the results:
# - records/sec
# - MB/sec
# - avg latency

# Run consumer performance test
kubectl exec -n confluent kafka-0 -- kafka-consumer-perf-test \
  --bootstrap-server kafka:9071 \
  --topic test-replication \
  --messages 100000 \
  --threads 1

# Note the results:
# - MB/sec consumed
# - messages/sec
```

---

## 7. Accessing the Platform

### 7.1 Control Center Web UI

**URL:** `http://<CONTROL-CENTER-IP>:9021`

**Get the IP:**
```bash
kubectl get svc controlcenter-bootstrap-lb -n confluent -o jsonpath='{.status.loadBalancer.ingress[0].ip}'
```

**Features Available:**
- Cluster overview and health
- Topic management (create, configure, browse messages)
- Consumer group monitoring
- Broker metrics and performance
- Alerts and notifications
- Integrated Prometheus metrics

### 7.2 Kafka CLI Access

**Internal Access (from within cluster):**

```bash
# Execute commands inside kafka pod
kubectl exec -it -n confluent kafka-0 -- bash

# Inside the pod:
kafka-topics --bootstrap-server kafka:9071 --list
kafka-console-producer --bootstrap-server kafka:9071 --topic my-topic
kafka-console-consumer --bootstrap-server kafka:9071 --topic my-topic
```

**External Access (from client machines):**

```bash
# Get bootstrap server
KAFKA_BOOTSTRAP=$(kubectl get svc kafka-bootstrap-lb -n confluent -o jsonpath='{.status.loadBalancer.ingress[0].ip}')

# Use with kafka clients
kafka-console-producer --bootstrap-server $KAFKA_BOOTSTRAP:9092 --topic my-topic
```

### 7.3 Prometheus Access

**Port Forward Method:**

```bash
kubectl port-forward -n confluent controlcenter-0 9090:9090

# Access at: http://localhost:9090
```

**Useful Queries:**
- `kafka_server_replicamanager_leadercount` - Leaders per broker
- `kafka_server_brokertopicmetrics_messagesin_total` - Message rate
- `kafka_server_replicamanager_underreplicatedpartitions` - Under-replicated partitions

### 7.4 AlertManager Access

```bash
kubectl port-forward -n confluent controlcenter-0 9093:9093

# Access at: http://localhost:9093
```

---

## 8. Troubleshooting

### 8.1 Common Issues and Solutions

#### Issue: Pods Stuck in Pending State

**Symptoms:**
```bash
kubectl get pods -n confluent
# NAME      READY   STATUS    RESTARTS   AGE
# kafka-1   0/1     Pending   0          5m
```

**Diagnosis:**
```bash
kubectl describe pod kafka-1 -n confluent | grep -A 10 Events:
```

**Common Causes:**

1. **Insufficient CPU/Memory**
   ```
   Warning  FailedScheduling  Insufficient cpu
   ```
   **Solution:** Reduce resource requests or add more nodes
   
   ```bash
   # Reduce CPU requests in kafka.yaml
   spec:
     podTemplate:
       resources:
         requests:
           cpu: 50m  # Reduced from 100m
   ```

2. **PVC Not Binding**
   ```bash
   kubectl get pvc -n confluent
   # Shows STATUS: Pending
   ```
   **Solution:** Check storage class exists and can provision
   
   ```bash
   kubectl get storageclass
   kubectl describe pvc <PVC-NAME> -n confluent
   ```

#### Issue: Control Center Pod CrashLoopBackOff

**Symptoms:**
```bash
controlcenter-0   0/3     CrashLoopBackOff   5          10m
```

**Diagnosis:**
```bash
kubectl logs controlcenter-0 -n confluent -c controlcenter --tail=100
```

**Common Causes:**

1. **Replication Factor Mismatch**
   
   Error: `3 brokers are required but only found 1`
   
   **Solution:** Update configOverrides in controlcenter.yaml
   
   ```yaml
   configOverrides:
     server:
       - confluent.controlcenter.internal.topics.replication=1  # Match broker count
   ```

2. **Kafka Not Ready**
   
   **Solution:** Wait for Kafka to be RUNNING first
   
   ```bash
   kubectl get kafka -n confluent
   # Ensure STATUS: RUNNING before deploying Control Center
   ```

#### Issue: Image Pull Errors

**Symptoms:**
```bash
pod/kafka-0   0/1     ImagePullBackOff   0          2m
```

**Diagnosis:**
```bash
kubectl describe pod kafka-0 -n confluent | grep "Error: ImagePullBackOff"
```

**Solution:**

1. Check image name and tag are correct
2. Verify network connectivity to Docker Hub
3. Use correct init container version

```yaml
# Correct versions for CP 8.1.0:
image:
  application: confluentinc/cp-server:8.1.0
  init: confluentinc/confluent-init-container:3.1.0  # Not 2.x
```

#### Issue: LoadBalancer EXTERNAL-IP Stuck in <pending>

**Symptoms:**
```bash
kubectl get svc -n confluent
# EXTERNAL-IP shows <pending>
```

**Diagnosis:**
```bash
kubectl describe svc kafka-bootstrap-lb -n confluent
```

**Solutions:**

1. **Cloud Provider Issue:** Verify cloud provider supports LoadBalancer
2. **Quota Exceeded:** Check cloud quotas for public IPs
3. **Use NodePort Instead:**

```yaml
listeners:
  external:
    externalAccess:
      type: nodePort  # Instead of loadBalancer
```

#### Issue: Kafka Brokers Can't Form Cluster

**Symptoms:**
```bash
# Only 1 broker shows as leader for all partitions
kubectl exec -n confluent kafka-0 -- kafka-topics --bootstrap-server kafka:9071 --describe --topic test
# All partitions have same leader
```

**Diagnosis:**
```bash
# Check broker logs
kubectl logs kafka-1 -n confluent | grep -i error

# Check if all brokers are registered
kubectl exec -n confluent kafka-0 -- \
  kafka-broker-api-versions --bootstrap-server kafka:9071 | grep id
```

**Solution:**

1. Check KRaft controller is running
2. Verify network connectivity between pods
3. Check for DNS resolution issues

```bash
# Test pod-to-pod communication
kubectl exec -n confluent kafka-0 -- ping kafka-1.kafka.confluent.svc.cluster.local
```

### 8.2 Debugging Commands

```bash
# Get all resources in namespace
kubectl get all -n confluent

# Check recent events
kubectl get events -n confluent --sort-by='.lastTimestamp' | tail -20

# Describe specific resource
kubectl describe kafka kafka -n confluent
kubectl describe pod kafka-0 -n confluent

# View logs
kubectl logs kafka-0 -n confluent --tail=100
kubectl logs -n confluent -l app=confluent-operator

# Check resource usage
kubectl top nodes
kubectl top pods -n confluent

# Exec into pod
kubectl exec -it kafka-0 -n confluent -- bash

# Port forward for debugging
kubectl port-forward -n confluent kafka-0 9092:9092
```

### 8.3 Recovery Procedures

#### Restart a Failed Pod

```bash
# Delete pod (StatefulSet will recreate)
kubectl delete pod kafka-1 -n confluent

# Watch recreation
kubectl get pods -n confluent -w
```

#### Restart Entire Component

```bash
# Rollout restart (preserves data)
kubectl rollout restart statefulset/kafka -n confluent

# Or delete and reapply
kubectl delete kafka kafka -n confluent
kubectl apply -f manifests/kafka.yaml
```

#### Complete Uninstall and Reinstall

```bash
# Delete all components
kubectl delete kraftcontroller,kafka,controlcenter -n confluent --all

# Delete PVCs (WARNING: deletes data)
kubectl delete pvc -n confluent --all

# Delete namespace
kubectl delete namespace confluent

# Uninstall operator
helm uninstall confluent-operator -n confluent

# Start fresh from Step 3
```

---

## 9. Appendix

### 9.1 Component Version Matrix

| Component | Version | Image | Notes |
|-----------|---------|-------|-------|
| Confluent Platform | 8.1.0 | - | Latest major release |
| Kafka Brokers | 8.1.0 | confluentinc/cp-server:8.1.0 | Includes KRaft support |
| KRaft Controller | 8.1.0 | confluentinc/cp-server:8.1.0 | Same as broker image |
| Control Center | 2.4.1 | cp-enterprise-control-center-next-gen:2.4.1 | Next-gen UI |
| Prometheus | 2.4.1 | cp-enterprise-prometheus:2.4.1 | Sidecar |
| AlertManager | 2.4.1 | cp-enterprise-alertmanager:2.4.1 | Sidecar |
| Init Container | 3.1.0/3.1.2 | confluent-init-container:3.1.0 | Configuration helper |
| CFK Operator | 0.1514.40 | - | Via Helm chart |

### 9.2 Resource Limits Reference

**Development Environment:**
```yaml
resources:
  requests:
    cpu: 50m
    memory: 512Mi
  limits:
    cpu: 500m
    memory: 1Gi
```

**Production Environment:**
```yaml
resources:
  requests:
    cpu: 1000m
    memory: 4Gi
  limits:
    cpu: 4000m
    memory: 8Gi
```

### 9.3 Kafka Configuration Tuning

**For High Throughput:**
```yaml
configOverrides:
  server:
    - num.io.threads=16
    - num.network.threads=8
    - socket.send.buffer.bytes=102400
    - socket.receive.buffer.bytes=102400
    - socket.request.max.bytes=104857600
    - log.segment.bytes=1073741824
    - log.retention.hours=168
    - log.retention.bytes=-1
```

**For Low Latency:**
```yaml
configOverrides:
  server:
    - linger.ms=0
    - compression.type=lz4
    - acks=1
```

### 9.4 Monitoring and Alerting

**Key Metrics to Monitor:**

| Metric | Warning | Critical | Action |
|--------|---------|----------|--------|
| Under-replicated partitions | > 0 | > 10 | Check broker health |
| Offline partitions | > 0 | > 0 | Immediate action |
| ISR shrinks/sec | > 5 | > 20 | Network/broker issues |
| CPU usage | > 70% | > 90% | Scale up |
| Disk usage | > 75% | > 85% | Add storage |
| Request latency (p99) | > 100ms | > 500ms | Investigate performance |

**Prometheus Alert Rules Example:**

```yaml
groups:
  - name: kafka
    rules:
      - alert: KafkaUnderReplicatedPartitions
        expr: kafka_server_replicamanager_underreplicatedpartitions > 0
        for: 5m
        annotations:
          summary: "Kafka has under-replicated partitions"
```

### 9.5 Backup and Disaster Recovery

**Backup PVCs:**

```bash
# Create VolumeSnapshot (requires CSI driver with snapshot support)
kubectl create -f - <<EOF
apiVersion: snapshot.storage.k8s.io/v1
kind: VolumeSnapshot
metadata:
  name: kafka-backup-$(date +%Y%m%d)
  namespace: confluent
spec:
  volumeSnapshotClassName: csi-azuredisk-vsc
  source:
    persistentVolumeClaimName: data0-kafka-0
EOF
```

**Topic Backup (using MirrorMaker or Cluster Linking):**

```bash
# Export topic configuration
kubectl exec -n confluent kafka-0 -- \
  kafka-configs --bootstrap-server kafka:9071 \
  --entity-type topics --entity-name important-topic \
  --describe > topic-config-backup.txt
```

### 9.6 Scaling Guide

**Scale Kafka Brokers:**

```bash
# Edit kafka.yaml, change replicas: 3 to replicas: 5
kubectl apply -f manifests/kafka.yaml

# Wait for new brokers
kubectl get kafka -n confluent -w

# Verify all 5 brokers
kubectl exec -n confluent kafka-0 -- \
  kafka-broker-api-versions --bootstrap-server kafka:9071 | grep id
```

**Rebalance Partitions After Scaling:**

```bash
# Generate reassignment plan
kubectl exec -n confluent kafka-0 -- kafka-reassign-partitions \
  --bootstrap-server kafka:9071 \
  --topics-to-move-json-file /tmp/topics.json \
  --broker-list "0,1,2,3,4" \
  --generate

# Execute reassignment
kubectl exec -n confluent kafka-0 -- kafka-reassign-partitions \
  --bootstrap-server kafka:9071 \
  --reassignment-json-file /tmp/reassignment.json \
  --execute
```

### 9.7 Security Hardening (Future Enhancement)

**Enable TLS:**

```yaml
tls:
  enabled: true
  autoGeneratedCerts: true  # Or use your own certificates
```

**Enable SASL Authentication:**

```yaml
authentication:
  type: plain
  jaasConfig:
    secretRef: credential
```

**Enable RBAC:**

```yaml
authorization:
  type: rbac
  superUsers:
    - User:admin
```

### 9.8 Useful Links

- **Confluent Documentation**: https://docs.confluent.io/platform/current/
- **Confluent for Kubernetes**: https://docs.confluent.io/operator/current/
- **GitHub Examples**: https://github.com/confluentinc/confluent-kubernetes-examples
- **Community Forum**: https://forum.confluent.io/
- **Support Portal**: https://support.confluent.io/

---

## Document Change Log

| Version | Date | Author | Changes |
|---------|------|--------|---------|
| 1.0 | 2026-05-14 | Initial | Initial runbook creation |

---

## Support and Feedback

For issues or questions:
1. Check troubleshooting section above
2. Review Confluent documentation
3. Contact Confluent support (if enterprise license)
4. Community forum for community edition

**End of Runbook**
