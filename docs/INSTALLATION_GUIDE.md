# Confluent Platform 8.1 with KRaft - Quick Installation Guide

**Version:** 8.1.0  
**Environment:** Kubernetes 1.25+  
**Estimated Time:** 30-45 minutes

---

## Prerequisites Verification

### Check your Kubernetes cluster is accessible

```bash
kubectl cluster-info
```

**What this does:** Verifies you can connect to your Kubernetes cluster

---

### Check cluster nodes are ready

```bash
kubectl get nodes
```

**What this does:** Lists all nodes in your cluster and their status. All nodes should show "Ready"

---

### Verify you have admin permissions

```bash
kubectl auth can-i create namespace
```

**What this does:** Checks if you have permission to create namespaces (required for installation). Should return "yes"

---

### Check available storage classes

```bash
kubectl get storageclass
```

**What this does:** Lists storage classes available in your cluster. Note the name of your default storage class (you'll need this later)

---

## Installation Steps

### Step 1: Create Namespace

```bash
kubectl create namespace confluent
```

**What this does:** Creates a dedicated namespace called "confluent" for all Confluent Platform components

---

### Step 2: Add Confluent Helm Repository

```bash
helm repo add confluentinc https://packages.confluent.io/helm
```

**What this does:** Adds Confluent's official Helm chart repository to your Helm configuration

---

### Step 3: Update Helm Repositories

```bash
helm repo update
```

**What this does:** Refreshes your local Helm repository cache to get the latest chart versions

---

### Step 4: Verify Confluent Charts are Available

```bash
helm search repo confluent
```

**What this does:** Lists all available Confluent Helm charts to confirm the repository was added correctly

---

### Step 5: Install Confluent Operator

```bash
helm upgrade --install confluent-operator \
  confluentinc/confluent-for-kubernetes \
  --namespace confluent
```

**What this does:** Installs the Confluent for Kubernetes operator, which manages the lifecycle of Confluent Platform components

---

### Step 6: Wait for Operator to be Ready

```bash
kubectl wait --for=condition=ready pod \
  -l app=confluent-operator \
  -n confluent \
  --timeout=120s
```

**What this does:** Waits up to 2 minutes for the operator pod to be fully running and ready

---

### Step 7: Verify Operator is Running

```bash
kubectl get pods -n confluent
```

**What this does:** Shows all pods in the confluent namespace. You should see the confluent-operator pod with status "Running"

---

### Step 8: Check Installed Custom Resource Definitions (CRDs)

```bash
kubectl get crd | grep confluent
```

**What this does:** Lists all Confluent-related custom resources that were installed (Kafka, KRaftController, ControlCenter, etc.)

---

## Deploy Confluent Platform Components

### Step 9: Create Working Directory and Configuration Files

```bash
mkdir -p ~/confluent-install/manifests
cd ~/confluent-install/manifests
```

**What this does:** Creates a directory to store your configuration files and navigates to it

---

### Step 10: Create KRaft Controller Configuration

**⚠️ IMPORTANT:** Replace `managed-csi` with your storage class name from Step "Check available storage classes"

```bash
cat > kraftcontroller.yaml <<'EOF'
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
    name: managed-csi
  podTemplate:
    resources:
      requests:
        cpu: 100m
        memory: 512Mi
      limits:
        cpu: 500m
        memory: 1Gi
EOF
```

**What this does:** Creates a YAML file that defines your KRaft controller configuration (replaces Zookeeper)

---

### Step 11: Deploy KRaft Controller

```bash
kubectl apply -f kraftcontroller.yaml
```

**What this does:** Deploys the KRaft controller to manage Kafka metadata

---

### Step 12: Wait for KRaft Controller to be Ready

```bash
kubectl wait --for=condition=ready pod \
  -l app=kraftcontroller \
  -n confluent \
  --timeout=300s
```

**What this does:** Waits up to 5 minutes for the KRaft controller to be fully operational

---

### Step 13: Verify KRaft Controller Status

```bash
kubectl get kraftcontroller -n confluent
```

**What this does:** Shows the status of the KRaft controller. STATUS should be "RUNNING"

---

### Step 14: Create Kafka Broker Configuration

**⚠️ IMPORTANT:** Replace `managed-csi` with your storage class name

```bash
cat > kafka.yaml <<'EOF'
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
    name: managed-csi
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
          domain: "kafka.demo.local"
          advertisedPort: 9092
EOF
```

**What this does:** Creates a YAML file that defines 3 Kafka brokers with external LoadBalancer access

---

### Step 15: Deploy Kafka Brokers

```bash
kubectl apply -f kafka.yaml
```

**What this does:** Deploys 3 Kafka broker pods with persistent storage

---

### Step 16: Wait for All Kafka Brokers to be Ready

```bash
kubectl wait --for=condition=ready pod \
  -l app=kafka \
  -n confluent \
  --timeout=600s
```

**What this does:** Waits up to 10 minutes for all 3 Kafka brokers to be fully operational

---

### Step 17: Verify Kafka Cluster Status

```bash
kubectl get kafka -n confluent
```

**What this does:** Shows Kafka cluster status. REPLICAS and READY should both show "3" and STATUS should be "RUNNING"

---

### Step 18: Check All Kafka Pods are Running

```bash
kubectl get pods -n confluent -l app=kafka
```

**What this does:** Lists all Kafka broker pods. You should see kafka-0, kafka-1, and kafka-2 all in "Running" status

---

### Step 19: Create Control Center Configuration

**⚠️ IMPORTANT:** Replace `managed-csi` with your storage class name

```bash
cat > controlcenter.yaml <<'EOF'
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
    name: managed-csi
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
      domain: "c3.demo.local"
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
EOF
```

**What this does:** Creates a YAML file for Control Center (web UI) with integrated Prometheus and AlertManager

---

### Step 20: Deploy Control Center

```bash
kubectl apply -f controlcenter.yaml
```

**What this does:** Deploys Control Center with monitoring stack (3 containers in 1 pod)

---

### Step 21: Wait for Control Center to be Ready

```bash
kubectl wait --for=condition=ready pod \
  -l app=controlcenter \
  -n confluent \
  --timeout=300s
```

**What this does:** Waits up to 5 minutes for Control Center and its sidecars to be fully operational

---

### Step 22: Verify Control Center Status

```bash
kubectl get controlcenter -n confluent
```

**What this does:** Shows Control Center status. STATUS should be "RUNNING"

---

## Get Access Information

### Step 23: Get Kafka External IP Address

```bash
kubectl get svc kafka-bootstrap-lb -n confluent -o jsonpath='{.status.loadBalancer.ingress[0].ip}'
```

**What this does:** Retrieves the external IP address for Kafka. Use this IP with port 9092 to connect clients (e.g., 20.x.x.x:9092)

---

### Step 24: Get Control Center URL

```bash
kubectl get svc controlcenter-bootstrap-lb -n confluent -o jsonpath='{.status.loadBalancer.ingress[0].ip}'
```

**What this does:** Retrieves the external IP address for Control Center. Open this in a browser with port 9021 (e.g., http://20.x.x.x:9021)

---

### Step 25: View All Component Status

```bash
kubectl get kraftcontroller,kafka,controlcenter -n confluent
```

**What this does:** Shows a summary of all Confluent components. All should show STATUS: RUNNING

---

### Step 26: View All Pods

```bash
kubectl get pods -n confluent
```

**What this does:** Lists all pods. You should see:
- confluent-operator (1/1)
- kraftcontroller-0 (1/1)
- kafka-0, kafka-1, kafka-2 (1/1 each)
- controlcenter-0 (3/3)

---

## Verification and Testing

### Step 27: Create a Test Topic

```bash
kubectl exec -n confluent kafka-0 -- kafka-topics \
  --bootstrap-server kafka:9071 \
  --create \
  --topic test-topic \
  --partitions 6 \
  --replication-factor 3
```

**What this does:** Creates a test topic named "test-topic" with 6 partitions and replication factor of 3

---

### Step 28: List All Topics

```bash
kubectl exec -n confluent kafka-0 -- kafka-topics \
  --bootstrap-server kafka:9071 \
  --list
```

**What this does:** Lists all Kafka topics. You should see "test-topic" and several internal topics

---

### Step 29: Describe the Test Topic

```bash
kubectl exec -n confluent kafka-0 -- kafka-topics \
  --bootstrap-server kafka:9071 \
  --describe \
  --topic test-topic
```

**What this does:** Shows detailed information about the test topic including partition distribution across brokers

---

### Step 30: Send Test Messages (Producer)

```bash
kubectl exec -it -n confluent kafka-0 -- kafka-console-producer \
  --bootstrap-server kafka:9071 \
  --topic test-topic
```

**What this does:** Opens an interactive producer. Type messages and press Enter. Press Ctrl+C when done.

**Example:**
```
> Hello Confluent
> Message 1
> Message 2
```

---

### Step 31: Read Test Messages (Consumer)

```bash
kubectl exec -it -n confluent kafka-0 -- kafka-console-consumer \
  --bootstrap-server kafka:9071 \
  --topic test-topic \
  --from-beginning
```

**What this does:** Opens a consumer that reads all messages from the beginning. Press Ctrl+C to exit.

---

### Step 32: Verify All Brokers are Registered

```bash
kubectl exec -n confluent kafka-0 -- \
  kafka-broker-api-versions --bootstrap-server kafka:9071 | grep id
```

**What this does:** Shows all registered Kafka brokers. You should see 3 brokers (id: 0, 1, 2)

---

## Access Control Center Web UI

### Step 33: Get Control Center Access URL

```bash
echo "Control Center URL: http://$(kubectl get svc controlcenter-bootstrap-lb -n confluent -o jsonpath='{.status.loadBalancer.ingress[0].ip}'):9021"
```

**What this does:** Prints the complete Control Center URL. Copy and paste this into your web browser.

**What you'll see:** Control Center dashboard showing:
- Cluster health
- Broker metrics
- Topics and partitions
- Consumer groups
- Message browser

---

## Performance Baseline Test (Optional)

### Step 34: Run Producer Performance Test

```bash
kubectl exec -n confluent kafka-0 -- kafka-producer-perf-test \
  --topic test-topic \
  --num-records 100000 \
  --record-size 1000 \
  --throughput 10000 \
  --producer-props bootstrap.servers=kafka:9071 acks=all
```

**What this does:** Sends 100,000 messages (1KB each) at 10,000 msg/sec to measure write performance. Shows throughput and latency metrics.

---

### Step 35: Run Consumer Performance Test

```bash
kubectl exec -n confluent kafka-0 -- kafka-consumer-perf-test \
  --bootstrap-server kafka:9071 \
  --topic test-topic \
  --messages 100000 \
  --threads 1
```

**What this does:** Consumes 100,000 messages to measure read performance. Shows throughput in MB/sec and messages/sec.

---

## Collect Support Bundle

If you need to collect diagnostic information for troubleshooting or support:

### Step 36: Create Support Bundle Directory

```bash
mkdir -p ~/confluent-support
cd ~/confluent-support
TIMESTAMP=$(date +%Y%m%d-%H%M%S)
```

**What this does:** Creates a directory for support bundle files and sets a timestamp variable

---

### Step 37: Collect All Kubernetes Resources

```bash
kubectl get pods,sts,svc,cm,kraftcontroller,kafka,controlcenter -n confluent -o yaml > support-bundle-${TIMESTAMP}.yaml
```

**What this does:** Exports all Confluent resources to a YAML file

---

### Step 38: Collect Pod Descriptions

```bash
kubectl describe pods -n confluent > support-bundle-${TIMESTAMP}-describe.txt
```

**What this does:** Captures detailed pod information including events and status

---

### Step 39: Collect Cluster Events

```bash
kubectl get events -n confluent --sort-by='.lastTimestamp' > support-bundle-${TIMESTAMP}-events.txt
```

**What this does:** Exports all recent events in the confluent namespace

---

### Step 40: Collect All Pod Logs

```bash
kubectl logs -n confluent --all-containers=true --prefix=true --tail=2000 > support-bundle-${TIMESTAMP}-logs.txt
```

**What this does:** Collects the last 2000 lines of logs from all containers in all pods

---

### Step 41: Package Support Bundle

```bash
tar -czf confluent-support-bundle-${TIMESTAMP}.tar.gz support-bundle-${TIMESTAMP}*
```

**What this does:** Compresses all collected files into a single .tar.gz archive

---

### Step 42: Verify Support Bundle Created

```bash
ls -lh confluent-support-bundle-${TIMESTAMP}.tar.gz
```

**What this does:** Shows the support bundle file size and confirms it was created successfully

---

## Common Management Commands

### View Real-time Pod Status

```bash
kubectl get pods -n confluent -w
```

**What this does:** Watches pod status with live updates. Press Ctrl+C to exit.

---

### Check Resource Usage

```bash
kubectl top pods -n confluent
```

**What this does:** Shows current CPU and memory usage for all pods

---

### View Operator Logs

```bash
kubectl logs -n confluent -l app=confluent-operator --tail=100 -f
```

**What this does:** Tails the last 100 lines of operator logs in real-time. Press Ctrl+C to exit.

---

### View Kafka Broker Logs

```bash
kubectl logs -n confluent kafka-0 --tail=100 -f
```

**What this does:** Tails logs from kafka-0 broker. Replace kafka-0 with kafka-1 or kafka-2 for other brokers.

---

### View Control Center Logs

```bash
kubectl logs -n confluent controlcenter-0 -c controlcenter --tail=100 -f
```

**What this does:** Tails Control Center application logs. Press Ctrl+C to exit.

---

### Access Prometheus (Port Forward)

```bash
kubectl port-forward -n confluent controlcenter-0 9090:9090
```

**What this does:** Forwards Prometheus to localhost. Access at http://localhost:9090. Press Ctrl+C to stop.

---

### Access AlertManager (Port Forward)

```bash
kubectl port-forward -n confluent controlcenter-0 9093:9093
```

**What this does:** Forwards AlertManager to localhost. Access at http://localhost:9093. Press Ctrl+C to stop.

---

## Cleanup and Uninstall

### Delete All Confluent Components (Keeps Data)

```bash
kubectl delete kraftcontroller,kafka,controlcenter -n confluent --all
```

**What this does:** Removes all Confluent components but preserves persistent volumes (data)

---

### Delete Persistent Volumes (Deletes Data)

**⚠️ WARNING:** This permanently deletes all Kafka data

```bash
kubectl delete pvc -n confluent --all
```

**What this does:** Deletes all persistent volume claims and their data

---

### Uninstall Confluent Operator

```bash
helm uninstall confluent-operator -n confluent
```

**What this does:** Removes the Confluent operator

---

### Delete Namespace (Complete Cleanup)

```bash
kubectl delete namespace confluent
```

**What this does:** Removes the confluent namespace and all resources in it

---

## Quick Reference

### Important Endpoints

| Component | Internal Endpoint | External Access |
|-----------|------------------|-----------------|
| Kafka Bootstrap | kafka.confluent.svc.cluster.local:9071 | \<LoadBalancer-IP\>:9092 |
| Control Center | controlcenter.confluent.svc.cluster.local:9021 | http://\<LoadBalancer-IP\>:9021 |
| Prometheus | controlcenter.confluent.svc.cluster.local:9090 | Port-forward to localhost:9090 |
| AlertManager | controlcenter.confluent.svc.cluster.local:9093 | Port-forward to localhost:9093 |

### Get External IPs

```bash
# Kafka
kubectl get svc kafka-bootstrap-lb -n confluent -o jsonpath='{.status.loadBalancer.ingress[0].ip}'

# Control Center
kubectl get svc controlcenter-bootstrap-lb -n confluent -o jsonpath='{.status.loadBalancer.ingress[0].ip}'
```

### Component Versions

- **Confluent Platform:** 8.1.0
- **Control Center:** 2.4.1 (Next-Gen)
- **Prometheus:** 2.4.1
- **AlertManager:** 2.4.1
- **Operator:** 0.1514.40

---

## Troubleshooting Quick Checks

### If Pods are Pending

```bash
kubectl describe pod <pod-name> -n confluent
```

**What to look for:** Events section at the bottom will show why (insufficient resources, PVC not binding, image pull errors)

---

### If Services Don't Have External IP

```bash
kubectl get svc -n confluent
```

**What to check:** If EXTERNAL-IP shows \<pending\>, your cloud provider may not support LoadBalancer or you've hit quota limits

---

### If Components Don't Start

```bash
kubectl get events -n confluent --sort-by='.lastTimestamp' | tail -20
```

**What to look for:** Recent error events explaining failures

---

## Support and Documentation

- **Confluent Documentation:** https://docs.confluent.io/platform/current/
- **Confluent for Kubernetes:** https://docs.confluent.io/operator/current/
- **GitHub Examples:** https://github.com/confluentinc/confluent-kubernetes-examples

---

**Installation Complete!** 🎉

You now have a fully functional Confluent Platform 8.1 cluster with:
- ✅ 3 Kafka brokers with replication
- ✅ KRaft-based metadata management (no Zookeeper)
- ✅ Control Center web UI
- ✅ Prometheus and AlertManager monitoring
- ✅ External LoadBalancer access

Access Control Center at the URL from Step 33 to manage your cluster!
