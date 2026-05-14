#!/bin/bash

POD_NAME=${1:-controlcenter-0}
NAMESPACE=${2:-confluent}

echo "=== Pod: $POD_NAME ==="
echo ""

echo "INIT CONTAINERS:"
kubectl get pod $POD_NAME -n $NAMESPACE \
  -o jsonpath='{range .spec.initContainers[*]}{.name}{"\t"}{.image}{"\n"}{end}' | \
  column -t

echo ""
echo "REGULAR CONTAINERS:"
kubectl get pod $POD_NAME -n $NAMESPACE \
  -o jsonpath='{range .spec.containers[*]}{.name}{"\t"}{.image}{"\n"}{end}' | \
  column -t

echo ""
echo "CONTAINER STATUS:"
kubectl get pod $POD_NAME -n $NAMESPACE \
  -o jsonpath='{range .status.containerStatuses[*]}{.name}{"\t"}{.ready}{"\t"}{.restartCount}{"\n"}{end}' | \
  column -t -N "NAME,READY,RESTARTS"
