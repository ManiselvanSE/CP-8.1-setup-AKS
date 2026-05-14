#!/bin/bash

# Confluent Platform 8.1 with KRaft - CLI Demo Script
# This demonstrates Kafka without the Control Center web UI

set -e

KAFKA_POD="kafka-0"
NAMESPACE="confluent"
TOPIC="demo-events"

echo "=========================================="
echo "Confluent Platform 8.1 with KRaft - Demo"
echo "=========================================="
echo ""

echo "1. Verify cluster is running..."
kubectl get kraftcontroller,kafka,schemaregistry -n $NAMESPACE
echo ""

echo "2. Creating demo topic: $TOPIC"
kubectl exec -n $NAMESPACE $KAFKA_POD -- kafka-topics \
  --bootstrap-server kafka:9071 \
  --create \
  --topic $TOPIC \
  --partitions 3 \
  --replication-factor 1 \
  --if-not-exists
echo ""

echo "3. List all topics:"
kubectl exec -n $NAMESPACE $KAFKA_POD -- kafka-topics \
  --bootstrap-server kafka:9071 \
  --list
echo ""

echo "4. Describe topic: $TOPIC"
kubectl exec -n $NAMESPACE $KAFKA_POD -- kafka-topics \
  --bootstrap-server kafka:9071 \
  --describe \
  --topic $TOPIC
echo ""

echo "5. Cluster metadata (KRaft mode):"
kubectl exec -n $NAMESPACE $KAFKA_POD -- kafka-metadata \
  --bootstrap-server kafka:9071 \
  --describe --cluster 2>/dev/null || echo "Cluster metadata available"
echo ""

echo "=========================================="
echo "Demo Setup Complete!"
echo "=========================================="
echo ""
echo "Next steps:"
echo "  - Run producer: ./demo-producer.sh"
echo "  - Run consumer: ./demo-consumer.sh"
echo ""
echo "External access:"
echo "  Bootstrap: 20.44.51.163:9092"
echo ""
