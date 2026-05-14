#!/bin/bash

# Confluent Platform Access URLs
# Created: 2026-05-14

echo "==========================================================="
echo "   Confluent Platform 8.1 - Browser Access Information"
echo "==========================================================="
echo ""

# Control Center
C3_IP=$(kubectl get svc controlcenter-bootstrap-lb -n confluent -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
echo "✅ CONTROL CENTER (Web UI)"
echo "   URL: http://$C3_IP:9021"
echo "   - Cluster monitoring and management"
echo "   - Topic management"
echo "   - Consumer group monitoring"
echo ""

# Kafka Bootstrap
KAFKA_IP=$(kubectl get svc kafka-bootstrap-lb -n confluent -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
echo "✅ KAFKA BOOTSTRAP SERVER"
echo "   URL: $KAFKA_IP:9092"
echo "   - Use for producer/consumer connections"
echo ""

# Prometheus (requires port-forward)
echo "⚙️  PROMETHEUS (Metrics)"
echo "   Port-forward command:"
echo "   kubectl port-forward -n confluent controlcenter-0 9090:9090"
echo "   Then access: http://localhost:9090"
echo ""

# AlertManager (requires port-forward)
echo "⚙️  ALERTMANAGER (Alerts)"
echo "   Port-forward command:"
echo "   kubectl port-forward -n confluent controlcenter-0 9093:9093"
echo "   Then access: http://localhost:9093"
echo ""

echo "==========================================================="
echo "   Quick Access Commands"
echo "==========================================================="
echo ""
echo "# Open Control Center in browser (macOS):"
echo "open http://$C3_IP:9021"
echo ""
echo "# Start Prometheus port-forward in background:"
echo "kubectl port-forward -n confluent controlcenter-0 9090:9090 &"
echo "open http://localhost:9090"
echo ""
echo "# Start AlertManager port-forward in background:"
echo "kubectl port-forward -n confluent controlcenter-0 9093:9093 &"
echo "open http://localhost:9093"
echo ""
