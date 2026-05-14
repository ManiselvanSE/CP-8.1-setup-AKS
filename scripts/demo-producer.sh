#!/bin/bash

# Confluent Platform 8.1 with KRaft - Producer Demo
# This script demonstrates producing messages to a Kafka topic

TOPIC_NAME="demo-events"

echo "=========================================="
echo " Kafka Producer Demo (KRaft Mode)"
echo "=========================================="
echo ""
echo "Topic: $TOPIC_NAME"
echo "Kafka: 20.44.51.163:9092"
echo ""
echo "Sample messages to send:"
echo '  {"event": "customer_signup", "id": "C001", "timestamp": "2026-05-14T12:00:00Z"}'
echo '  {"event": "customer_login", "id": "C001", "timestamp": "2026-05-14T12:05:00Z"}'
echo '  {"event": "purchase", "id": "C001", "amount": 99.99, "timestamp": "2026-05-14T12:10:00Z"}'
echo ""
echo "Type messages and press Enter. Press Ctrl+C to exit."
echo "=========================================="
echo ""

kubectl exec -it -n confluent kafka-0 -- kafka-console-producer \
  --bootstrap-server kafka:9071 \
  --topic $TOPIC_NAME

echo ""
echo "Producer stopped. Messages sent to topic: $TOPIC_NAME"
