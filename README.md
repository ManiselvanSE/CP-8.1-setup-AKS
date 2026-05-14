# Confluent Platform 8.1 on AKS with KRaft

[![Confluent Platform](https://img.shields.io/badge/Confluent%20Platform-8.1.0-blue)](https://docs.confluent.io/platform/current/)
[![Kubernetes](https://img.shields.io/badge/Kubernetes-1.25+-326CE5)](https://kubernetes.io/)
[![KRaft](https://img.shields.io/badge/Mode-KRaft-success)](https://kafka.apache.org/documentation/#kraft)
[![Azure](https://img.shields.io/badge/Cloud-Azure%20AKS-0078D4)](https://azure.microsoft.com/en-us/services/kubernetes-service/)

Complete deployment guide and manifests for running Confluent Platform 8.1 on Azure Kubernetes Service (AKS) using KRaft mode (Zookeeper-free architecture).

## 📋 Overview

This repository contains everything you need to deploy a production-ready Confluent Platform 8.1 cluster on Kubernetes with:

- ✅ **KRaft Mode**: Modern, Zookeeper-free architecture
- ✅ **High Availability**: Multi-broker setup with replication
- ✅ **External Access**: LoadBalancer services for client connectivity
- ✅ **Integrated Monitoring**: Prometheus and AlertManager
- ✅ **Control Center**: Next-generation web UI for management
- ✅ **Cloud Native**: Fully Kubernetes-native deployment

## 🚀 Quick Start

### Prerequisites

- Kubernetes cluster (1.25+) - tested on AKS
- kubectl and helm installed
- 12+ vCPUs, 24+ GB RAM available
- Dynamic storage provisioning enabled

### Installation (5 steps)

```bash
# 1. Clone this repository
git clone https://github.com/ManiselvanSE/CP-8.1-setup-AKS.git
cd CP-8.1-setup-AKS

# 2. Install Confluent Operator
helm repo add confluentinc https://packages.confluent.io/helm
helm repo update
helm upgrade --install confluent-operator confluentinc/confluent-for-kubernetes \
  --namespace confluent --create-namespace

# 3. Deploy KRaft Controller
kubectl apply -f manifests/kraftcontroller.yaml

# 4. Deploy Kafka Brokers
kubectl apply -f manifests/kafka.yaml

# 5. Deploy Control Center
kubectl apply -f manifests/controlcenter-nextgen.yaml

# Get access URLs
./scripts/access-urls.sh
```

## 📚 Documentation

### Main Guides

| Document | Description |
|----------|-------------|
| **[INSTALLATION_RUNBOOK.md](INSTALLATION_RUNBOOK.md)** | 📖 Comprehensive installation guide with architecture, troubleshooting, and best practices |
| **[docs/INSTALLATION_GUIDE.md](docs/INSTALLATION_GUIDE.md)** | 🛠️ Step-by-step installation instructions |
| **[docs/DEMO-GUIDE.md](docs/DEMO-GUIDE.md)** | 🎯 Demo scenarios and testing guide |
| **[docs/DEPLOYMENT_STATUS.md](docs/DEPLOYMENT_STATUS.md)** | 📊 Deployment verification checklist |

### Reference Guides

| Document | Description |
|----------|-------------|
| [docs/CURRENT_STATUS.md](docs/CURRENT_STATUS.md) | Current cluster status overview |
| [docs/3-BROKER_STATUS.md](docs/3-BROKER_STATUS.md) | 3-broker configuration details |
| [docs/VIEWING_CONTAINERS.md](docs/VIEWING_CONTAINERS.md) | Container inspection guide |

## 📁 Repository Structure

```
CP-8.1-setup-AKS/
├── README.md                           # This file
├── INSTALLATION_RUNBOOK.md             # Comprehensive installation guide
├── manifests/                          # Kubernetes manifests
│   ├── kraftcontroller.yaml            # KRaft controller configuration
│   ├── kafka.yaml                      # Kafka broker configuration
│   ├── controlcenter-nextgen.yaml      # Control Center with monitoring
│   ├── connect.yaml                    # Kafka Connect (optional)
│   └── schemaregistry.yaml             # Schema Registry (optional)
├── scripts/                            # Utility scripts
│   ├── access-urls.sh                  # Get access URLs and IPs
│   ├── check-status.sh                 # Check deployment status
│   ├── demo-producer.sh                # Demo message producer
│   ├── demo-consumer.sh                # Demo message consumer
│   ├── demo-cli.sh                     # Interactive CLI demo
│   └── show-containers.sh              # Show container details
└── docs/                               # Additional documentation
    ├── INSTALLATION_GUIDE.md
    ├── DEMO-GUIDE.md
    ├── DEPLOYMENT_STATUS.md
    ├── CURRENT_STATUS.md
    ├── 3-BROKER_STATUS.md
    └── VIEWING_CONTAINERS.md
```

## 🏗️ Architecture

### Component Overview

| Component | Version | Replicas | Purpose |
|-----------|---------|----------|---------|
| **KRaft Controller** | 8.1.0 | 1 | Metadata management (replaces Zookeeper) |
| **Kafka Brokers** | 8.1.0 | 3 | Message streaming and storage |
| **Control Center** | 2.4.1 | 1 | Web UI for monitoring and management |
| **Prometheus** | 2.4.1 | 1 (sidecar) | Metrics collection |
| **AlertManager** | 2.4.1 | 1 (sidecar) | Alert management |

### Network Architecture

```
External Clients
      ↓
LoadBalancer (Azure)
      ↓
Kafka Service (ClusterIP)
      ↓
Kafka Pods (kafka-0, kafka-1, kafka-2)
      ↓
KRaft Controller (metadata)
      ↓
Azure Managed Disks (persistent storage)
```

## 🛠️ Common Operations

### Get Access Information

```bash
# Get all access URLs and IPs
./scripts/access-urls.sh

# Or manually:
kubectl get svc -n confluent | grep LoadBalancer
```

### Check Cluster Status

```bash
# Quick status check
./scripts/check-status.sh

# Detailed pod status
kubectl get pods -n confluent

# Component status
kubectl get kraftcontroller,kafka,controlcenter -n confluent
```

### Create a Test Topic

```bash
kubectl exec -n confluent kafka-0 -- kafka-topics \
  --bootstrap-server kafka:9071 \
  --create \
  --topic my-topic \
  --partitions 6 \
  --replication-factor 3
```

### Run Demo Producer/Consumer

```bash
# Terminal 1: Start producer
./scripts/demo-producer.sh

# Terminal 2: Start consumer
./scripts/demo-consumer.sh
```

### Access Control Center

```bash
# Get Control Center URL
C3_URL=$(kubectl get svc controlcenter-bootstrap-lb -n confluent -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
echo "Control Center: http://$C3_URL:9021"
```

## 📊 Monitoring

### Prometheus Metrics

Port-forward to access Prometheus UI:

```bash
kubectl port-forward -n confluent controlcenter-0 9090:9090
# Access: http://localhost:9090
```

### AlertManager

Port-forward to access AlertManager:

```bash
kubectl port-forward -n confluent controlcenter-0 9093:9093
# Access: http://localhost:9093
```

### Key Metrics to Monitor

- `kafka_server_replicamanager_underreplicatedpartitions` - Under-replicated partitions
- `kafka_server_replicamanager_leadercount` - Leaders per broker
- `kafka_server_brokertopicmetrics_messagesin_total` - Message rate
- `kafka_controller_kafkacontroller_activecontrollercount` - Active controller

## 🔧 Troubleshooting

### Pods Stuck in Pending

```bash
kubectl describe pod <POD_NAME> -n confluent
# Check Events section for resource constraints or PVC issues
```

### Control Center CrashLoopBackOff

```bash
# Check logs
kubectl logs controlcenter-0 -n confluent -c controlcenter --tail=100

# Common issue: Replication factor mismatch
# Update configOverrides in controlcenter-nextgen.yaml
```

### LoadBalancer EXTERNAL-IP Pending

```bash
# Verify cloud provider supports LoadBalancer
# Or switch to NodePort in manifests
```

See [INSTALLATION_RUNBOOK.md](INSTALLATION_RUNBOOK.md#troubleshooting) for comprehensive troubleshooting guide.

## 📦 What's Deployed

### Default Configuration

- **Namespace**: `confluent`
- **KRaft Controllers**: 1 replica (increase to 3 for production)
- **Kafka Brokers**: 3 replicas
- **Replication Factor**: 3
- **Storage Class**: `managed-csi` (Azure)
- **External Access**: LoadBalancer

### Resource Requirements

| Component | CPU Request | Memory Request | Storage |
|-----------|-------------|----------------|---------|
| KRaft Controller | 100m | 512Mi | 5Gi |
| Kafka Broker | 100m | 768Mi | 10Gi |
| Control Center | 50m | 768Mi | 5Gi |

**Total**: ~450m CPU, ~3.5Gi Memory, ~40Gi Storage

## 🔄 Scaling

### Scale Kafka Brokers

```bash
# Edit kafka.yaml: change replicas to desired count
kubectl apply -f manifests/kafka.yaml

# Verify scaling
kubectl get kafka -n confluent -w
```

### Increase Storage

```bash
# Edit PVC directly (if supported by storage class)
kubectl edit pvc data0-kafka-0 -n confluent
```

## 🧹 Cleanup

### Delete All Components (Keep Data)

```bash
kubectl delete kraftcontroller,kafka,controlcenter -n confluent --all
```

### Complete Uninstall (Deletes Data)

```bash
# Delete all components
kubectl delete kraftcontroller,kafka,controlcenter,connect,schemaregistry -n confluent --all

# Delete PVCs (WARNING: This deletes all data)
kubectl delete pvc -n confluent --all

# Uninstall operator
helm uninstall confluent-operator -n confluent

# Delete namespace
kubectl delete namespace confluent
```

## 🔐 Security (Future Enhancement)

This deployment uses basic configuration without authentication. For production, consider:

- **TLS/SSL**: Enable encryption for all communications
- **SASL Authentication**: Add authentication for clients
- **RBAC**: Implement role-based access control
- **Network Policies**: Restrict pod-to-pod communication

See [INSTALLATION_RUNBOOK.md](INSTALLATION_RUNBOOK.md#security-hardening) for security configuration examples.

## 📝 Version Information

| Software | Version | Notes |
|----------|---------|-------|
| Confluent Platform | 8.1.0 | Latest stable |
| Kubernetes | 1.25+ | Tested on 1.33.5 |
| Confluent for Kubernetes Operator | 0.1514.40 | Via Helm |
| Control Center Next-Gen | 2.4.1 | Latest UI |
| Prometheus | 2.4.1 | Integrated |

## 🤝 Contributing

Contributions welcome! Please:

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Test thoroughly
5. Submit a pull request

## 📄 License

This repository is provided as-is for educational and demonstration purposes.

## 🔗 Useful Links

- [Confluent Platform Documentation](https://docs.confluent.io/platform/current/)
- [Confluent for Kubernetes](https://docs.confluent.io/operator/current/)
- [Apache Kafka KRaft Mode](https://kafka.apache.org/documentation/#kraft)
- [Azure AKS Documentation](https://docs.microsoft.com/en-us/azure/aks/)

## 📧 Support

For issues or questions:
- Open an issue in this repository
- Consult the [troubleshooting guide](INSTALLATION_RUNBOOK.md#troubleshooting)
- Review [Confluent documentation](https://docs.confluent.io/)

---

**Built with ❤️ for the Kafka community**
