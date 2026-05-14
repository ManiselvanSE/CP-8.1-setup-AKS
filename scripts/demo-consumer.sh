#!/bin/bash

# Confluent Platform 8.1 with KRaft - Consumer Demo
# This script demonstrates consuming messages from a Kafka topic

TOPIC_NAME="demo-events"
CONSUMER_GROUP="demo-consumer-group"

echo "=========================================="
echo " Kafka Consumer Demo (KRaft Mode)"
echo "=========================================="
echo ""
echo "Topic: $TOPIC_NAME"
echo "Consumer Group: $CONSUMER_GROUP"
echo "Kafka: 20.44.51.163:9092"
echo ""
echo "Press Ctrl+C to exit"
echo "=========================================="
echo ""

kubectl exec -it -n confluent kafka-0 -- kafka-console-consumer \
  --bootstrap-server kafka:9071 \
  --topic $TOPIC_NAME \
  --group $CONSUMER_GROUP \
  --from-beginning \
  --property print.timestamp=true \
  --property print.key=true \
  --property print.partition=true

echo ""
echo "Consumer stopped."
echo ""
echo "To view consumer group status:"
echo "  kubectl exec -n confluent kafka-0 -- kafka-consumer-groups \\"
echo "    --bootstrap-server kafka:9071 \\"
echo "    --group $CONSUMER_GROUP \\"
echo "    --describe"
