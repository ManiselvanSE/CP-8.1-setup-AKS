# Confluent Platform 8.1.0 with KRaft - Deployment Status

## ✅ Successfully Deployed

**Platform Version**: Confluent Platform 8.1.0  
**Kafka Mode**: KRaft (Zookeeper-free)  
**Cluster Type**: Single-node demo/POC setup  
**Deployment Date**: May 14, 2026

---

## 🎯 Running Components

### KRaft Controller
- **Status**: ✅ RUNNING (1/1)
- **Pod**: kraftcontroller-0
- **Image**: confluentinc/cp-server:8.1.0
- **Purpose**: Metadata management for Kafka cluster (replaces Zookeeper)

### Kafka Broker
- **Status**: ✅ RUNNING (1/1)
- **Pod**: kafka-0
- **Image**: confluentinc/cp-server:8.1.0
- **Bootstrap Server**: **20.44.51.163:9092** (External LoadBalancer)
- **Internal Endpoint**: kafka.confluent.svc.cluster.local:9071

### Schema Registry
- **Status**: ✅ RUNNING (1/1)
- **Pod**: schemaregistry-0
- **Image**: confluentinc/cp-schema-registry:8.1.0
- **Endpoint**: http://schemaregistry.confluent.svc.cluster.local:8081

---

## ❌ Components NOT Deployed

### Control Center (Web UI)
- **Reason**: Docker image `cp-enterprise-control-center:8.1.0` not yet available
- **Impact**: No web-based monitoring UI - use CLI tools instead
- **Alternative**: Use kafka-topics, kafka-console-producer, kafka-console-consumer commands

### Kafka Connect
- **Reason**: Removed due to AKS cluster CPU constraints
- **Impact**: No pre-built connectors available
- **Can Add**: If more CPU capacity is allocated

---

## 🔗 Access Information

### External Access
```bash
# Kafka Bootstrap Server (from outside cluster)
KAFKA_BOOTSTRAP_SERVER=20.44.51.163:9092

# Individual Broker
KAFKA_BROKER_0=20.219.100.61:9092
```

### Internal Access (from within cluster)
```bash
# Kafka
kafka.confluent.svc.cluster.local:9071

# Schema Registry
http://schemaregistry.confluent.svc.cluster.local:8081
```

---

## 🛠️ CLI-Based Demo Commands

### 1. Create a Topic
```bash
kubectl exec -n confluent kafka-0 -- kafka-topics \
  --bootstrap-server kafka:9071 \
  --create \
  --topic demo-events \
  --partitions 3 \
  --replication-factor 1
```

### 2. List Topics
```bash
kubectl exec -n confluent kafka-0 -- kafka-topics \
  --bootstrap-server kafka:9071 \
  --list
```

### 3. Describe Topic
```bash
kubectl exec -n confluent kafka-0 -- kafka-topics \
  --bootstrap-server kafka:9071 \
  --describe \
  --topic demo-events
```

### 4. Produce Messages (Interactive)
```bash
kubectl exec -it -n confluent kafka-0 -- kafka-console-producer \
  --bootstrap-server kafka:9071 \
  --topic demo-events
```

### 5. Consume Messages
```bash
kubectl exec -it -n confluent kafka-0 -- kafka-console-consumer \
  --bootstrap-server kafka:9071 \
  --topic demo-events \
  --from-beginning \
  --property print.timestamp=true
```

### 6. Consume with Consumer Group
```bash
kubectl exec -it -n confluent kafka-0 -- kafka-console-consumer \
  --bootstrap-server kafka:9071 \
  --topic demo-events \
  --group demo-consumer-group \
  --from-beginning
```

### 7. List Consumer Groups
```bash
kubectl exec -n confluent kafka-0 -- kafka-consumer-groups \
  --bootstrap-server kafka:9071 \
  --list
```

### 8. Describe Consumer Group
```bash
kubectl exec -n confluent kafka-0 -- kafka-consumer-groups \
  --bootstrap-server kafka:9071 \
  --group demo-consumer-group \
  --describe
```

### 9. Check Broker Logs
```bash
kubectl logs -n confluent kafka-0 --tail=100 -f
```

### 10. Check Cluster Metadata
```bash
kubectl exec -n confluent kafka-0 -- kafka-metadata \
  --bootstrap-server kafka:9071 \
  --describe --all
```

---

## 🎪 Demo Script for Customer

### Quick Demo Flow (10 minutes)

1. **Show KRaft Architecture**
   ```bash
   kubectl get kraftcontroller,kafka -n confluent
   kubectl get pods -n confluent
   ```

2. **Create Topic**
   ```bash
   kubectl exec -n confluent kafka-0 -- kafka-topics \
     --bootstrap-server kafka:9071 \
     --create --topic customer-events --partitions 3 --replication-factor 1
   ```

3. **Terminal 1: Start Producer**
   ```bash
   kubectl exec -it -n confluent kafka-0 -- kafka-console-producer \
     --bootstrap-server kafka:9071 \
     --topic customer-events
   
   # Type messages:
   {"event": "signup", "user": "alice", "timestamp": "2026-05-14T10:00:00Z"}
   {"event": "login", "user": "alice", "timestamp": "2026-05-14T10:05:00Z"}
   ```

4. **Terminal 2: Start Consumer**
   ```bash
   kubectl exec -it -n confluent kafka-0 -- kafka-console-consumer \
     --bootstrap-server kafka:9071 \
     --topic customer-events \
     --from-beginning
   ```

5. **Show Real-time Data Flow**
   - Type messages in producer terminal
   - See them appear instantly in consumer terminal

6. **Show Consumer Groups**
   ```bash
   kubectl exec -n confluent kafka-0 -- kafka-consumer-groups \
     --bootstrap-server kafka:9071 \
     --list --describe
   ```

---

## 🔍 Monitoring & Operations

### Check Component Health
```bash
# All Confluent components
kubectl get kraftcontroller,kafka,schemaregistry -n confluent

# Pods
kubectl get pods -n confluent

# Services
kubectl get svc -n confluent
```

### View Logs
```bash
# KRaft Controller
kubectl logs -n confluent kraftcontroller-0 -f

# Kafka Broker
kubectl logs -n confluent kafka-0 -f

# Schema Registry
kubectl logs -n confluent schemaregistry-0 -f
```

### Resource Usage
```bash
# Node resources
kubectl top nodes

# Pod resources
kubectl top pods -n confluent
```

---

## 📦 What's New in Confluent Platform 8.1 with KRaft

### KRaft Benefits (vs Zookeeper)
1. **Simplified Architecture** - One less component to manage
2. **Faster Metadata Updates** - Lower latency for topic/partition operations
3. **Better Scalability** - Supports millions of partitions
4. **Unified Log** - Metadata stored in Kafka itself
5. **Easier Operations** - No separate Zookeeper cluster to maintain

### Talking Points
- ✅ Production-ready since Kafka 3.3+ (Confluent Platform 7.5+)
- ✅ Recommended for all new deployments
- ✅ Simplified disaster recovery
- ✅ Lower operational overhead
- ✅ Foundation for future Kafka features

---

## 🚀 Performance Testing

### Producer Performance Test
```bash
kubectl exec -n confluent kafka-0 -- kafka-producer-perf-test \
  --topic perf-test \
  --num-records 100000 \
  --record-size 1000 \
  --throughput 10000 \
  --producer-props bootstrap.servers=kafka:9071
```

### Consumer Performance Test
```bash
kubectl exec -n confluent kafka-0 -- kafka-consumer-perf-test \
  --bootstrap-server kafka:9071 \
  --topic perf-test \
  --messages 100000 \
  --threads 1
```

---

## 🔄 Scaling Considerations

### To Scale to Production:

1. **Increase Replicas**
   ```yaml
   # kraftcontroller.yaml & kafka.yaml
   spec:
     replicas: 3  # Change from 1 to 3
   ```

2. **Add More CPU/Memory**
   ```yaml
   podTemplate:
     resources:
       requests:
         cpu: 2000m
         memory: 4Gi
       limits:
         cpu: 4000m
         memory: 8Gi
   ```

3. **Increase Replication Factor**
   - Topics: replication-factor 3
   - Critical topics: min.insync.replicas 2

4. **Enable Security**
   - TLS encryption
   - SASL authentication
   - RBAC authorization

---

## 📝 Files

- `kraftcontroller.yaml` - KRaft controller configuration
- `kafka.yaml` - Kafka broker configuration  
- `schemaregistry.yaml` - Schema Registry configuration
- `connect.yaml` - Kafka Connect (not deployed)
- `controlcenter.yaml` - Control Center (image unavailable)

---

## 🆘 Troubleshooting

### Kafka Not Starting
```bash
kubectl describe kafka kafka -n confluent
kubectl logs kafka-0 -n confluent
```

### Check KRaft Controller
```bash
kubectl logs kraftcontroller-0 -n confluent
```

### Network Issues
```bash
kubectl get svc -n confluent
kubectl describe svc kafka-bootstrap-lb -n confluent
```

---

## 🧹 Cleanup

```bash
# Delete all components
kubectl delete kraftcontroller,kafka,schemaregistry -n confluent --all

# Delete namespace
kubectl delete namespace confluent

# Uninstall operator
helm uninstall confluent-operator -n confluent
```
