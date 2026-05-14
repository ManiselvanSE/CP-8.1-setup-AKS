#!/bin/bash

echo "=== Confluent Platform Status ==="
echo ""
echo "1. Component Status:"
kubectl get kraftcontroller,kafka,schemaregistry,connect,controlcenter -n confluent
echo ""
echo "2. Pod Status:"
kubectl get pods -n confluent
echo ""
echo "3. LoadBalancer External IPs:"
kubectl get svc -n confluent | grep LoadBalancer
echo ""
echo "4. Control Center URL:"
CONTROL_CENTER_IP=$(kubectl get svc controlcenter-bootstrap-lb -n confluent -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null)
if [ ! -z "$CONTROL_CENTER_IP" ]; then
    echo "   http://$CONTROL_CENTER_IP:9021"
else
    echo "   Waiting for LoadBalancer IP assignment..."
fi
echo ""
echo "5. Kafka Bootstrap Server:"
KAFKA_IP=$(kubectl get svc kafka-bootstrap-lb -n confluent -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null)
if [ ! -z "$KAFKA_IP" ]; then
    echo "   $KAFKA_IP:9092"
else
    echo "   Waiting for LoadBalancer IP assignment..."
fi
