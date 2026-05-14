# Confluent Platform 8.1 - Customer Demo Guide

**Target Audience:** Customers new to Confluent Platform  
**Duration:** 30-45 minutes  
**Presenter Preparation Time:** 10 minutes

---

## Table of Contents

1. [Demo Overview](#demo-overview)
2. [Pre-Demo Checklist](#pre-demo-checklist)
3. [Demo Script](#demo-script)
4. [Talking Points](#talking-points)
5. [Common Customer Questions](#common-customer-questions)

---

## Demo Overview

### What You'll Show

This demo showcases a production-ready Kafka deployment running on Kubernetes with:

- **Modern Architecture**: KRaft mode (Zookeeper-free) - the future of Kafka
- **High Availability**: 3 Kafka brokers with automatic replication
- **Enterprise Monitoring**: Built-in Prometheus and AlertManager
- **Easy Management**: Next-generation Control Center web UI
- **Cloud Native**: Fully containerized and orchestrated by Kubernetes

### Demo Flow (30 minutes)

```
5 min  → Architecture Overview
10 min → Control Center UI Walkthrough
10 min → Live Data Flow Demo (Producer/Consumer)
5 min  → Monitoring and Observability
5 min  → Q&A
```

---

## Pre-Demo Checklist

### 15 Minutes Before Demo

Run these commands to ensure everything is ready:

#### 1. Verify All Components Are Running

```bash
# Quick health check
kubectl get pods -n confluent

# Expected output: All pods should show Running
# kraftcontroller-0        1/1     Running
# kafka-0                  1/1     Running
# kafka-1                  1/1     Running
# kafka-2                  1/1     Running
# controlcenter-0          3/3     Running
```

**If any pods are not Running:**
```bash
# Check what's wrong
kubectl describe pod <pod-name> -n confluent
kubectl logs <pod-name> -n confluent
```

#### 2. Get Access URLs

```bash
# Create a quick reference file
cat > demo-urls.txt <<EOF
=== CONFLUENT PLATFORM ACCESS INFO ===

Kafka Bootstrap Server:
$(kubectl get svc kafka-bootstrap-lb -n confluent -o jsonpath='{.status.loadBalancer.ingress[0].ip}'):9092

Control Center URL:
http://$(kubectl get svc controlcenter-bootstrap-lb -n confluent -o jsonpath='{.status.loadBalancer.ingress[0].ip}'):9021

Prometheus URL (port-forward):
kubectl port-forward -n confluent controlcenter-0 9090:9090
http://localhost:9090

===================================
EOF

cat demo-urls.txt
```

**Keep this file open** - you'll reference these URLs during the demo.

#### 3. Pre-Create Demo Topic

```bash
# Create a topic for the demo
kubectl exec -n confluent kafka-0 -- kafka-topics \
  --bootstrap-server kafka:9071 \
  --create \
  --topic customer-orders \
  --partitions 6 \
  --replication-factor 3 \
  --config retention.ms=86400000

# Verify creation
kubectl exec -n confluent kafka-0 -- kafka-topics \
  --bootstrap-server kafka:9071 \
  --describe \
  --topic customer-orders
```

#### 4. Open Control Center

```bash
# Get the URL
CONTROL_CENTER_URL="http://$(kubectl get svc controlcenter-bootstrap-lb -n confluent -o jsonpath='{.status.loadBalancer.ingress[0].ip}'):9021"

echo "Control Center: $CONTROL_CENTER_URL"

# Open in browser (macOS)
open "$CONTROL_CENTER_URL"

# Or manually copy the URL and open in your browser
```

**Wait for Control Center to fully load** (may take 30 seconds on first access)

#### 5. Prepare Two Terminal Windows

- **Terminal 1**: For producer commands
- **Terminal 2**: For consumer commands

Label them clearly or use tmux/split screen.

---

## Demo Script

### Part 1: Introduction and Architecture (5 minutes)

#### Opening Statement

> "Today I'll show you Confluent Platform 8.1, the enterprise Kafka distribution, running on Kubernetes. This is a production-ready deployment that took about 30 minutes to set up, and it gives you a complete event streaming platform with built-in monitoring and management."

#### Show the Kubernetes Deployment

```bash
# Terminal Command
kubectl get all -n confluent
```

**What to Explain:**

Point to each component on screen:

1. **KRaft Controller** (kraftcontroller-0)
   - "This is the brain of the cluster - it replaced Zookeeper in Kafka 3.x+"
   - "It manages metadata: who's the leader, which brokers are alive, topic configurations"
   - "Much simpler and more scalable than old Zookeeper architecture"

2. **Kafka Brokers** (kafka-0, kafka-1, kafka-2)
   - "These 3 brokers store and serve your data"
   - "Every message is replicated across all 3 for high availability"
   - "If one broker dies, the other two keep running - zero downtime"

3. **Control Center** (controlcenter-0)
   - "This is your web-based control panel"
   - "It has 3 containers: the UI, Prometheus for metrics, and AlertManager for alerts"
   - "One pod, fully integrated monitoring stack"

#### Show Architecture Diagram

Draw or show this simple diagram:

```
       ┌─────────────────┐
       │  Applications   │
       └────────┬────────┘
                │
       ┌────────▼────────┐
       │ Load Balancer   │
       │  20.x.x.x:9092 │
       └────────┬────────┘
                │
    ┌───────────┼───────────┐
    ▼           ▼           ▼
┌────────┐ ┌────────┐ ┌────────┐
│Kafka-0 │ │Kafka-1 │ │Kafka-2 │
│Broker  │ │Broker  │ │Broker  │
└───┬────┘ └───┬────┘ └───┬────┘
    │          │          │
    └──────────┼──────────┘
               ▼
     ┌──────────────────┐
     │ KRaft Controller │
     │   (Metadata)     │
     └──────────────────┘
```

**Key Talking Point:**
> "Notice there's no Zookeeper. KRaft mode is the modern approach - simpler to operate, easier to scale, and fully supported for production since Kafka 3.3."

---

### Part 2: Control Center UI Walkthrough (10 minutes)

#### Open Control Center

Navigate to: `http://<CONTROL_CENTER_IP>:9021`

**First Screen: Cluster Overview**

Point out these sections:

1. **Cluster Health (Top)**
   - "Green status means all brokers are up"
   - "Shows broker count, topics, partitions"

2. **Brokers Section (Left Sidebar)**
   ```
   Click: Brokers
   ```
   - "Here are our 3 Kafka brokers"
   - "Each broker has metrics: throughput, storage usage, leader count"
   - Click on one broker to show details

3. **Topics Section**
   ```
   Click: Topics
   ```
   - "This is where you manage your topics"
   - "Think of topics like database tables, but for streaming data"
   
   Find the `customer-orders` topic you created:
   ```
   Click: customer-orders
   ```

#### Deep Dive: Topic Details

On the `customer-orders` topic page:

1. **Overview Tab**
   - "6 partitions - for parallel processing"
   - "Replication factor 3 - every partition has 3 copies"
   - "Retention: 1 day - how long messages are kept"

2. **Configuration Tab**
   ```
   Click: Configuration
   ```
   - "100+ settings you can tune"
   - "retention.ms, compression type, cleanup policy, etc."
   - "All configurable through this UI - no config files to edit"

3. **Messages Tab**
   ```
   Click: Messages
   ```
   - "You can browse messages directly in the UI"
   - "We'll send some messages in a moment and come back here"

4. **Consumers Tab**
   ```
   Click: Consumers
   ```
   - "See which applications are reading from this topic"
   - "Monitor consumer lag - how far behind they are"
   - "Critical for troubleshooting performance issues"

**Key Talking Point:**
> "This is why Confluent is valuable beyond open-source Kafka. You get this enterprise UI that makes management simple. No more command-line-only operations."

---

### Part 3: Live Data Flow Demo (10 minutes)

#### Set Up Producer (Terminal 1)

```bash
# Label this terminal clearly
echo "=== PRODUCER TERMINAL ==="

# Start console producer
kubectl exec -it -n confluent kafka-0 -- kafka-console-producer \
  --bootstrap-server kafka:9071 \
  --topic customer-orders \
  --property "parse.key=true" \
  --property "key.separator=:"
```

**Explain to customer:**
> "I'm connecting a producer to our Kafka cluster. In production, this would be your application sending events - orders, clicks, sensor data, whatever."

#### Set Up Consumer (Terminal 2)

```bash
# Label this terminal clearly
echo "=== CONSUMER TERMINAL ==="

# Start console consumer
kubectl exec -it -n confluent kafka-0 -- kafka-console-consumer \
  --bootstrap-server kafka:9071 \
  --topic customer-orders \
  --from-beginning \
  --property print.key=true \
  --property key.separator=" => "
```

**Explain to customer:**
> "Now I have a consumer listening. This could be your analytics service, a database sync process, or a microservice reacting to events."

#### Send Messages

In **Terminal 1** (Producer), type these messages:

```
order-001:{"customer":"Alice","amount":250.00,"product":"Laptop"}
order-002:{"customer":"Bob","amount":89.99,"product":"Mouse"}
order-003:{"customer":"Charlie","amount":1299.00,"product":"Monitor"}
```

Press Enter after each line.

**Watch Terminal 2** - messages appear instantly!

**What to Say:**
> "See that? Real-time event streaming. As soon as the producer sends, the consumer receives. This is the foundation of event-driven architectures."

#### Show Message Persistence

```bash
# In Terminal 2, press Ctrl+C to stop consumer
# Then restart it

kubectl exec -it -n confluent kafka-0 -- kafka-console-consumer \
  --bootstrap-server kafka:9071 \
  --topic customer-orders \
  --from-beginning \
  --property print.key=true \
  --property key.separator=" => "
```

**All 3 messages appear again!**

**Explain:**
> "Messages persist in Kafka. Unlike traditional message queues where messages disappear after consumption, Kafka keeps them (based on retention policy). Multiple consumers can read the same data independently."

#### Show in Control Center

Go back to Control Center:

1. **Navigate to Topics → customer-orders → Messages**
2. **Click "Jump to offset" → Partition 0, Offset 0**
3. **Click "Fetch"**

You'll see your JSON messages in the UI!

**Highlight:**
- Message keys (order-001, order-002, etc.)
- Message values (JSON payloads)
- Timestamps
- Partition assignment

**Key Talking Point:**
> "You can troubleshoot production issues right here. No need to connect to servers or run CLI commands - just browse your message history."

---

### Part 4: High Availability Demo (5 minutes)

#### Show Replication

```bash
# Show topic partitions and replicas
kubectl exec -n confluent kafka-0 -- kafka-topics \
  --bootstrap-server kafka:9071 \
  --describe \
  --topic customer-orders
```

**Explain the output:**

```
Topic: customer-orders  Partition: 0  Leader: 0  Replicas: 0,1,2  Isr: 0,1,2
Topic: customer-orders  Partition: 1  Leader: 1  Replicas: 1,2,0  Isr: 1,2,0
```

- **Leader**: Broker handling reads/writes for this partition
- **Replicas**: Which brokers have copies of this partition
- **ISR (In-Sync Replicas)**: Replicas that are fully caught up

**Say:**
> "Every partition has a leader and 2 followers. If the leader fails, one of the followers is instantly promoted. Your applications see zero downtime."

#### Demonstrate Resilience (Optional - if time permits)

```bash
# Simulate broker failure
kubectl delete pod kafka-1 -n confluent

# Watch Kubernetes restart it
kubectl get pods -n confluent -w
```

**While it's restarting:**

```bash
# Send more messages - they still work!
# Terminal 1 (Producer)
order-004:{"customer":"Diana","amount":50.00,"product":"Keyboard"}
```

**Point out:**
> "Broker 1 is down, but messages still flow. The other brokers took over. This is the high availability you get with proper replication."

Wait for kafka-1 to come back:

```bash
# Once STATUS shows Running again
kubectl get pods -n confluent
```

**Show in Control Center:**
- Go to Brokers
- kafka-1 shows green again
- "It automatically rejoined the cluster and re-synced its data"

---

### Part 5: Monitoring and Observability (5 minutes)

#### Control Center Metrics

In Control Center:

1. **Click: Brokers**
   - Show broker-level metrics graphs:
     - Messages in per second
     - Bytes in/out
     - Request latency

2. **Click: Topics → customer-orders**
   - Show topic-level metrics:
     - Production rate
     - Consumption rate
     - Storage size

**Explain:**
> "All these metrics are collected by Prometheus running as a sidecar. No additional infrastructure needed - it's all bundled in the deployment."

#### Prometheus Deep Dive

```bash
# Port-forward Prometheus
kubectl port-forward -n confluent controlcenter-0 9090:9090
```

Open browser: `http://localhost:9090`

**Show Key Queries:**

1. **Message Rate:**
   ```
   Query: rate(kafka_server_brokertopicmetrics_messagesin_total[5m])
   Click: Graph
   ```
   - "This shows messages per second across all topics"

2. **Under-Replicated Partitions (Critical Alert):**
   ```
   Query: kafka_server_replicamanager_underreplicatedpartitions
   Click: Graph
   ```
   - "This should always be zero"
   - "If it's not, you have a problem - means some data isn't fully replicated"

3. **Broker CPU:**
   ```
   Query: container_cpu_usage_seconds_total{pod=~"kafka-.*"}
   Click: Graph
   ```

**Key Talking Point:**
> "You can export these metrics to your existing Grafana dashboards, set up alerts in PagerDuty, or use them with any monitoring tool. It's just Prometheus - industry standard."

#### AlertManager

```bash
# Port-forward AlertManager
kubectl port-forward -n confluent controlcenter-0 9093:9093
```

Open browser: `http://localhost:9093`

**Show:**
- "Here's where alerts are managed"
- "You can configure alert rules: if under-replicated partitions > 0, send to Slack"
- "Out of the box integration with PagerDuty, email, webhooks"

---

### Part 6: Operations and Management (3 minutes)

#### Creating Topics (UI Method)

In Control Center:

1. **Click: Topics → + Create Topic**
2. **Fill in:**
   - Name: `sensor-data`
   - Partitions: 12
   - Replication factor: 3
3. **Click: Create**

**Show it appears immediately in the list.**

**Say:**
> "Self-service topic creation. Your development teams can create topics through the UI or API without needing infrastructure team involvement."

#### Configuration Management

Still in Control Center:

1. **Click on `sensor-data` topic**
2. **Go to Configuration tab**
3. **Click "Edit Settings"**
4. **Show options:**
   - Retention time
   - Compression type
   - Max message size
   - Cleanup policy

**Don't change anything, just point out:**
> "All configurable without touching config files or restarting brokers. Changes apply instantly."

#### Consumer Group Management

```bash
# Create a consumer group (Terminal 1)
kubectl exec -it -n confluent kafka-0 -- kafka-console-consumer \
  --bootstrap-server kafka:9071 \
  --topic customer-orders \
  --group demo-consumer-group \
  --from-beginning
```

Let it run for 5 seconds, then Ctrl+C.

**In Control Center:**

1. **Click: Consumers**
2. **Find `demo-consumer-group`**
3. **Click on it**

**Show:**
- Consumer lag (should be 0 - fully caught up)
- Which partitions it's reading from
- Current offset position

**Say:**
> "This is huge for troubleshooting. If customers report missing data, you can see exactly where their consumer is stuck and reset it if needed."

---

### Part 7: Security Overview (2 minutes)

**Current Setup:**
> "This demo uses internal Kubernetes networking without authentication for simplicity. In production, you'd enable:"

List these features:

1. **TLS Encryption**
   - "All communication encrypted"
   - "Certificates auto-generated by the operator"

2. **SASL Authentication**
   - "Username/password or Kerberos"
   - "LDAP/Active Directory integration"

3. **RBAC (Role-Based Access Control)**
   - "Control who can read/write specific topics"
   - "Audit logs of all access"

4. **Encryption at Rest**
   - "Data encrypted on disk"
   - "Uses Kubernetes storage encryption"

**Show the config (don't apply):**

```yaml
# Example configuration
spec:
  tls:
    enabled: true
    autoGeneratedCerts: true
  authentication:
    type: plain
  authorization:
    type: rbac
```

**Say:**
> "These are all configuration changes - no code to write. The Confluent Operator handles all the certificate management and configuration distribution."

---

### Part 8: Scalability Demo (3 minutes)

#### Current Capacity

```bash
# Show current state
kubectl get kafka -n confluent

# Output shows: REPLICAS: 3
```

**Say:**
> "We have 3 brokers now. Let's scale to 5 to handle more load."

#### Scale Up

```bash
# Edit the Kafka resource
kubectl patch kafka kafka -n confluent --type='json' -p='[{"op": "replace", "path": "/spec/replicas", "value": 5}]'

# Watch it scale
kubectl get pods -n confluent -w

# You'll see kafka-3 and kafka-4 being created
```

**While waiting:**
> "Kubernetes is creating 2 new brokers. They'll automatically join the cluster, and we can rebalance partitions to use them."

**Once running:**

```bash
# Verify all 5 brokers
kubectl get kafka -n confluent
# Shows: REPLICAS: 5/5
```

**In Control Center:**
- Go to Brokers
- Show all 5 brokers listed
- "They're already serving traffic"

**Explain:**
> "Scaling is this easy. Add more brokers, and Kafka automatically distributes new topics across them. Existing data can be rebalanced with one command."

#### Performance at Scale

**Show typical numbers:**

| Brokers | Partitions | Throughput (MB/s) | Messages/sec |
|---------|------------|-------------------|--------------|
| 3 | 100 | ~200 | ~200,000 |
| 5 | 200 | ~400 | ~400,000 |
| 10 | 500 | ~1,000 | ~1,000,000 |

**Say:**
> "Confluent customers run clusters with hundreds of brokers handling millions of messages per second. This scales horizontally - just add more nodes."

---

### Part 9: Enterprise Features Highlight (3 minutes)

#### What Comes with Confluent Platform vs. Open Source Kafka

Show this comparison:

| Feature | Open Source Kafka | Confluent Platform |
|---------|-------------------|-------------------|
| Kafka Brokers | ✅ | ✅ |
| Control Center UI | ❌ | ✅ |
| Schema Registry | Basic | Enterprise |
| Tiered Storage | ❌ | ✅ |
| Cluster Linking | ❌ | ✅ |
| Audit Logs | ❌ | ✅ |
| 24/7 Support | Community | ✅ |
| Operator for K8s | Basic | Enterprise |

**Explain each briefly:**

1. **Control Center**
   - "What you've been seeing today - this UI is Confluent only"

2. **Schema Registry**
   - "Manages data schemas (Avro, JSON, Protobuf)"
   - "Ensures producers and consumers agree on data format"
   - "Enterprise version has RBAC and audit logs"

3. **Tiered Storage**
   - "Store older data in cheap object storage (S3, Azure Blob)"
   - "Keep recent data on fast SSD"
   - "Reduces infrastructure costs by 70%+"

4. **Cluster Linking**
   - "Replicate data between Kafka clusters"
   - "Disaster recovery and multi-region deployments"
   - "No code required - configuration only"

5. **Support**
   - "Direct access to Kafka experts"
   - "SLAs and guaranteed response times"

#### Licensing

**Explain:**
> "Confluent Platform has a free tier for development/testing. Production requires a license based on capacity. You can start small and scale up as needed."

---

### Part 10: Real-World Use Cases (5 minutes)

Share examples relevant to the customer's industry:

#### Use Case 1: E-Commerce Order Processing

```
Customer places order
    ↓
Order Service → [Kafka: orders topic]
    ↓                    ↓                   ↓
Inventory        Payment           Shipping
Service          Service           Service
    ↓                    ↓                   ↓
Each service reacts independently in real-time
```

**Benefits:**
- Services are decoupled
- Can process orders even if one service is down
- Easy to add new services (e.g., fraud detection)

#### Use Case 2: IoT Sensor Data

```
10,000 IoT sensors → Kafka → Real-time Analytics
                          → Database (historical)
                          → Alerts (anomalies)
```

**Benefits:**
- Handle millions of events/sec
- Multiple consumers for different purposes
- Historical replay for ML training

#### Use Case 3: CDC (Change Data Capture)

```
PostgreSQL database changes → Kafka → Elasticsearch (search)
                                   → Data Warehouse (analytics)
                                   → Cache invalidation
```

**Benefits:**
- Keep multiple systems in sync
- No custom integration code
- Real-time data pipelines

**Ask the customer:**
> "Which of these scenarios resonates with your use cases? Or what specific problem are you trying to solve?"

---

## Talking Points

### Key Messages to Emphasize

1. **Simplicity**
   - "Deployed in 30 minutes on Kubernetes"
   - "No Zookeeper to manage - KRaft mode is simpler"
   - "Web UI for all operations - no CLI required"

2. **Reliability**
   - "3x replication - zero data loss"
   - "Self-healing - Kubernetes restarts failed pods automatically"
   - "No downtime during broker failures"

3. **Observability**
   - "Built-in Prometheus and AlertManager"
   - "Grafana-compatible metrics"
   - "See exactly what's happening in your cluster"

4. **Scalability**
   - "Scale from 3 to 100+ brokers"
   - "Millions of messages per second"
   - "Petabytes of data retention"

5. **Enterprise Ready**
   - "TLS, SASL, RBAC for security"
   - "Multi-tenancy support"
   - "24/7 support from Confluent"

### Positioning Statements

**When asked "Why not use managed Kafka (AWS MSK, Azure Event Hubs)?"**

> "Great question. Managed services are easier initially, but Confluent on Kubernetes gives you:
> 1. **Portability** - Run on any cloud or on-premise
> 2. **Features** - Latest Kafka features day one (managed services lag 6-12 months)
> 3. **Control** - Full access to advanced configs
> 4. **Cost** - Managed services charge premium for convenience (2-3x more expensive)
> 5. **Consistency** - Same platform across dev/staging/prod regardless of cloud"

**When asked "Why not use RabbitMQ or ActiveMQ?"**

> "Different tools for different jobs:
> - **RabbitMQ**: Great for task queues, request/response patterns. Not designed for high-throughput streaming.
> - **Kafka**: Built for event streaming, log aggregation, high throughput (millions of msgs/sec). Messages persist and can be replayed.
> - If you need pub/sub + persistence + replay + high throughput, Kafka is the industry standard."

**When asked "Can we start small and grow?"**

> "Absolutely. Start with this exact setup (3 brokers) for dev/staging. As you scale:
> - Add brokers horizontally (we showed 3 → 5)
> - Add topics for new use cases
> - Deploy Schema Registry, Connect, ksqlDB as needed
> - Kubernetes makes it all declarative - just update YAML files"

---

## Common Customer Questions

### Technical Questions

**Q: How much storage do we need?**

**A:** "Depends on your retention and throughput. Formula:

```
Storage = Messages/sec × Message size × Retention seconds × Replication factor

Example:
10,000 msg/sec × 1 KB × 7 days × 3 replicas = ~1.8 TB

Start with 500GB per broker, monitor in Control Center, expand as needed."
```

**Q: What happens if we lose all 3 brokers?**

**A:** "If all brokers in a cluster fail simultaneously:
1. Data persists on disks (Kubernetes Persistent Volumes)
2. Brokers restart and rejoin using same storage
3. No data loss unless disks fail

For multi-zone deployments, spread brokers across availability zones. For disaster recovery, use Cluster Linking to replicate to a secondary cluster."

**Q: How do we backup Kafka?**

**A:** "Three strategies:
1. **Replication** - Built-in, 3 copies of every message
2. **Cluster Linking** - Replicate to secondary cluster
3. **Tiered Storage** - Archive to S3/Azure Blob
4. **Volume Snapshots** - Backup Kubernetes persistent volumes

Most customers rely on replication + cluster linking for DR."

**Q: Can we run this on-premise?**

**A:** "Yes! This same setup works on:
- Any Kubernetes cluster (on-prem, cloud, hybrid)
- OpenShift
- Rancher
- VMware Tanzu

Just need Kubernetes 1.25+ and a storage class for persistent volumes."

**Q: What about upgrades?**

**A:** "Confluent Operator handles rolling upgrades:
1. Update the image version in YAML
2. Operator upgrades one broker at a time
3. Zero downtime - cluster stays available

Each broker restarts, rejoins, syncs up before moving to next one."

### Business Questions

**Q: What's the total cost of ownership?**

**A:** "Three components:
1. **Compute** - Kubernetes nodes (VMs or bare metal)
2. **Storage** - Persistent volumes (SSD recommended)
3. **Confluent License** - Based on capacity tier

Typical breakdown for 3-broker cluster:
- Compute: $500-1000/month (3 × 4-core VMs)
- Storage: $200-500/month (500GB per broker)
- Confluent license: Contact sales for pricing

Compare to AWS MSK: 2-3x more expensive for equivalent capacity."

**Q: Do we need dedicated Kafka team?**

**A:** "Not necessarily. With Confluent Operator + Control Center:
- Your existing Kubernetes team can manage infrastructure
- Developers can self-service (create topics, browse messages)
- Confluent support handles escalations

Many customers run Kafka with just 1-2 people part-time."

**Q: How long to get to production?**

**A:** "Timeline:
- **Week 1-2**: Deploy dev/staging cluster, train team
- **Week 3-4**: Build first use case (e.g., order processing)
- **Week 5-6**: Security hardening (TLS, RBAC), load testing
- **Week 7**: Production go-live

Total: ~6-8 weeks for first production use case."

**Q: What if we outgrow this setup?**

**A:** "Kafka scales horizontally - no hard limits:
- Add more brokers (we showed 3 → 5, can go to 100+)
- Add more clusters (dev, staging, prod, region-specific)
- Use Cluster Linking to span regions
- Tiered Storage for infinite retention

LinkedIn runs 7 trillion messages/day on Kafka. You're covered for growth."

---

## Demo Cleanup (After Customer Leaves)

```bash
# Delete demo topics
kubectl exec -n confluent kafka-0 -- kafka-topics \
  --bootstrap-server kafka:9071 \
  --delete \
  --topic customer-orders

kubectl exec -n confluent kafka-0 -- kafka-topics \
  --bootstrap-server kafka:9071 \
  --delete \
  --topic sensor-data

# Scale back to 3 brokers if you scaled up
kubectl patch kafka kafka -n confluent --type='json' -p='[{"op": "replace", "path": "/spec/replicas", "value": 3}]'

# Stop port-forwards (if running)
pkill -f "port-forward.*9090"
pkill -f "port-forward.*9093"
```

---

## Quick Demo Troubleshooting

### Issue: Control Center Not Loading

```bash
# Check pod status
kubectl get pods -n confluent -l app=controlcenter

# If not 3/3 Running, check logs
kubectl logs controlcenter-0 -n confluent -c controlcenter --tail=50

# Common fix: Restart the pod
kubectl delete pod controlcenter-0 -n confluent
```

### Issue: Messages Not Flowing

```bash
# Check producer/consumer are connected to right bootstrap server
# Internal: kafka:9071
# External: <EXTERNAL-IP>:9092

# Verify topic exists
kubectl exec -n confluent kafka-0 -- kafka-topics --bootstrap-server kafka:9071 --list
```

### Issue: Demo Running Slow

```bash
# Check resource usage
kubectl top pods -n confluent

# If high, may need to scale down demo load or wait for cooldown
```

---

## Post-Demo Follow-Up

### Send to Customer

1. **This Demo Guide** (PDF export)
2. **Installation Runbook** (the main runbook document)
3. **Architecture Diagram** (create a clean version in draw.io)
4. **Links:**
   - Confluent Documentation: https://docs.confluent.io/
   - Confluent for Kubernetes: https://docs.confluent.io/operator/
   - Free Trial: https://www.confluent.io/get-started/

### Next Steps Email Template

```
Subject: Confluent Platform Demo Follow-Up

Hi [Customer Name],

Thanks for joining the demo today! Here's a summary of what we covered:

✅ Deployed Confluent Platform 8.1 with KRaft on Kubernetes
✅ Demonstrated real-time event streaming with producers/consumers
✅ Showed Control Center for management and monitoring
✅ Highlighted high availability and scalability features

**What's Next:**

1. Review the attached runbook and try the installation yourself
2. Identify 1-2 use cases in your environment for a POC
3. Schedule a follow-up call to discuss architecture for your specific needs

**Resources:**
- Installation Runbook: [Attached]
- Demo Guide: [Attached]
- Confluent Free Trial: https://www.confluent.io/get-started/

Let me know if you have any questions!

Best regards,
[Your Name]
```

---

## Presenter Checklist

### Before Demo
- [ ] All pods Running (kubectl get pods -n confluent)
- [ ] Control Center accessible in browser
- [ ] demo-urls.txt file created and ready
- [ ] Two terminal windows prepared
- [ ] customer-orders topic created
- [ ] Internet connection stable (for live demo)

### During Demo
- [ ] Speak slowly and explain concepts (customer is new to Kafka)
- [ ] Show, don't just tell (always demo in UI or terminal)
- [ ] Pause for questions frequently
- [ ] Watch customer body language (confused? slow down)
- [ ] Keep demo moving (don't get stuck in troubleshooting)

### After Demo
- [ ] Answer all questions (or note them for follow-up)
- [ ] Share runbook and resources
- [ ] Schedule follow-up meeting
- [ ] Clean up demo artifacts

---

## Additional Demo Ideas (Time Permitting)

### 1. Schema Registry Demo

If customer needs schema management:

```bash
# Deploy Schema Registry
kubectl apply -f - <<EOF
apiVersion: platform.confluent.io/v1beta1
kind: SchemaRegistry
metadata:
  name: schemaregistry
  namespace: confluent
spec:
  replicas: 1
  image:
    application: confluentinc/cp-schema-registry:8.1.0
  dependencies:
    kafka:
      bootstrapEndpoint: kafka:9071
EOF

# Show schema evolution in Control Center
```

### 2. Multi-Region Simulation

Show cluster linking between namespaces:

```bash
# Create "DR" cluster in another namespace
kubectl create namespace confluent-dr

# Show cluster linking setup (config only, don't deploy)
```

### 3. Performance Benchmarking

Run actual perf tests:

```bash
# Producer throughput test
kubectl exec -n confluent kafka-0 -- kafka-producer-perf-test \
  --topic perf-test \
  --num-records 1000000 \
  --record-size 1000 \
  --throughput -1 \
  --producer-props bootstrap.servers=kafka:9071

# Show results live
```

---

**End of Demo Guide**

Good luck with your demo! 🚀
