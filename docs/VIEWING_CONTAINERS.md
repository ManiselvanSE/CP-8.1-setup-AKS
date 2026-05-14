# How to View Init Containers and Sidecar Containers in Kubernetes

## Quick Summary

**Current Confluent Platform Deployment:**

| Pod | Init Containers | Sidecar Containers | Total Containers |
|-----|-----------------|-------------------|------------------|
| controlcenter-0 | 1 (config-init) | 3 (prometheus, alertmanager, controlcenter) | 4 |
| kafka-0/1/2 | 1 (config-init) | 1 (kafka) | 2 |
| kraftcontroller-0 | 1 (config-init) | 1 (kraft) | 2 |
| confluent-operator | 0 | 1 (operator) | 1 |

---

## Method 1: Quick List of All Containers

### List Init Containers
```bash
kubectl get pod <POD_NAME> -n confluent -o jsonpath='{.spec.initContainers[*].name}'
```

### List Regular Containers (Sidecars)
```bash
kubectl get pod <POD_NAME> -n confluent -o jsonpath='{.spec.containers[*].name}'
```

### Combined View with Images
```bash
# Init containers
kubectl get pod controlcenter-0 -n confluent \
  -o jsonpath='{range .spec.initContainers[*]}{.name}{"\t"}{.image}{"\n"}{end}'

# Regular containers
kubectl get pod controlcenter-0 -n confluent \
  -o jsonpath='{range .spec.containers[*]}{.name}{"\t"}{.image}{"\n"}{end}'
```

**Output for controlcenter-0:**
```
INIT CONTAINERS:
config-init-container    confluentinc/confluent-init-container:3.1.2

REGULAR CONTAINERS:
prometheus              confluentinc/cp-enterprise-prometheus:2.4.1
alertmanager            confluentinc/cp-enterprise-alertmanager:2.4.1
controlcenter           confluentinc/cp-enterprise-control-center-next-gen:2.4.1
```

---

## Method 2: kubectl describe (Most Detailed)

```bash
kubectl describe pod <POD_NAME> -n confluent
```

This shows:
- ✅ Init container details (completed)
- ✅ All regular containers
- ✅ Container IDs
- ✅ Images and image IDs
- ✅ Ports
- ✅ Resource requests/limits
- ✅ Environment variables
- ✅ Volume mounts
- ✅ Liveness/readiness probes
- ✅ Container status

### View Specific Sections

**Init Containers Only:**
```bash
kubectl describe pod controlcenter-0 -n confluent | grep -A 30 "^Init Containers:"
```

**Regular Containers Only:**
```bash
kubectl describe pod controlcenter-0 -n confluent | grep -A 50 "^Containers:"
```

---

## Method 3: kubectl get with Custom Columns

```bash
kubectl get pods -n confluent \
  -o custom-columns='POD:.metadata.name,READY:.status.containerStatuses[*].ready,CONTAINERS:.spec.containers[*].name'
```

---

## Method 4: JSON/YAML Output (Programmatic)

### JSON Format
```bash
kubectl get pod controlcenter-0 -n confluent -o json | \
  jq '{
    initContainers: [.spec.initContainers[] | {name, image}],
    containers: [.spec.containers[] | {name, image}]
  }'
```

**Output:**
```json
{
  "initContainers": [
    {
      "name": "config-init-container",
      "image": "confluentinc/confluent-init-container:3.1.2"
    }
  ],
  "containers": [
    {
      "name": "prometheus",
      "image": "confluentinc/cp-enterprise-prometheus:2.4.1"
    },
    {
      "name": "alertmanager",
      "image": "confluentinc/cp-enterprise-alertmanager:2.4.1"
    },
    {
      "name": "controlcenter",
      "image": "confluentinc/cp-enterprise-control-center-next-gen:2.4.1"
    }
  ]
}
```

### YAML Format
```bash
kubectl get pod controlcenter-0 -n confluent -o yaml | \
  yq '.spec.initContainers[] | {name, image}'

kubectl get pod controlcenter-0 -n confluent -o yaml | \
  yq '.spec.containers[] | {name, image}'
```

---

## Method 5: Check Container Logs

### View Logs from Specific Container

**Init Container (while running or after completion):**
```bash
kubectl logs <POD_NAME> -n confluent -c config-init-container
```

**Sidecar Containers:**
```bash
# Prometheus logs
kubectl logs controlcenter-0 -n confluent -c prometheus --tail=50

# AlertManager logs
kubectl logs controlcenter-0 -n confluent -c alertmanager --tail=50

# Control Center logs
kubectl logs controlcenter-0 -n confluent -c controlcenter --tail=50
```

### Follow Logs in Real-Time
```bash
kubectl logs controlcenter-0 -n confluent -c prometheus -f
```

### View Previous Container Logs (if crashed)
```bash
kubectl logs controlcenter-0 -n confluent -c prometheus --previous
```

---

## Method 6: Execute Commands in Specific Containers

### Shell into a Sidecar Container
```bash
# Prometheus container
kubectl exec -it controlcenter-0 -n confluent -c prometheus -- /bin/sh

# AlertManager container
kubectl exec -it controlcenter-0 -n confluent -c alertmanager -- /bin/sh

# Control Center container
kubectl exec -it controlcenter-0 -n confluent -c controlcenter -- /bin/bash
```

### Run Command in Specific Container
```bash
# Check Prometheus config
kubectl exec controlcenter-0 -n confluent -c prometheus -- cat /etc/prometheus/prometheus.yml

# Check process list
kubectl exec controlcenter-0 -n confluent -c prometheus -- ps aux
```

---

## Method 7: Check Container Status

### Container Readiness
```bash
kubectl get pod controlcenter-0 -n confluent \
  -o jsonpath='{range .status.containerStatuses[*]}{.name}{"\t"}{.ready}{"\t"}{.state}{"\n"}{end}' | column -t
```

### Init Container Status
```bash
kubectl get pod controlcenter-0 -n confluent \
  -o jsonpath='{range .status.initContainerStatuses[*]}{.name}{"\t"}{.state}{"\n"}{end}'
```

---

## Method 8: Count Containers Across All Pods

```bash
kubectl get pods -n confluent -o json | \
  jq -r '.items[] | 
    "\(.metadata.name): Init=\(.spec.initContainers | length), Regular=\(.spec.containers | length), Total=\((.spec.initContainers | length) + (.spec.containers | length))"'
```

**Output:**
```
confluent-operator-867565b77f-xr2p8: Init=0, Regular=1, Total=1
controlcenter-0: Init=1, Regular=3, Total=4
kafka-0: Init=1, Regular=1, Total=2
kafka-1: Init=1, Regular=1, Total=2
kafka-2: Init=1, Regular=1, Total=2
kraftcontroller-0: Init=1, Regular=1, Total=2
```

---

## Understanding the Output

### READY Column
- `3/3` = 3 out of 3 containers are ready (doesn't count init containers)
- `0/3` = 0 out of 3 containers are ready
- `1/1` = single container pod

### Container Types

**Init Containers:**
- Run **before** regular containers
- Run **sequentially** (one after another)
- Must **complete successfully** before regular containers start
- Used for: setup, configuration, waiting for dependencies
- In Confluent: `config-init-container` prepares configuration files

**Regular Containers (Sidecars):**
- Run **concurrently** (all at the same time)
- Share the same pod network and storage
- Can communicate via `localhost`
- Keep running for the pod's lifetime

---

## Practical Examples for Confluent Platform

### Check if Prometheus is Running
```bash
kubectl exec controlcenter-0 -n confluent -c prometheus -- wget -qO- http://localhost:9090/-/healthy
```

### Check Prometheus Targets
```bash
kubectl exec controlcenter-0 -n confluent -c prometheus -- \
  wget -qO- http://localhost:9090/api/v1/targets
```

### Check AlertManager Status
```bash
kubectl exec controlcenter-0 -n confluent -c alertmanager -- \
  wget -qO- http://localhost:9093/-/healthy
```

### Port Forward to Access Prometheus UI
```bash
kubectl port-forward -n confluent controlcenter-0 9090:9090
# Then open: http://localhost:9090
```

### Port Forward to Access AlertManager UI
```bash
kubectl port-forward -n confluent controlcenter-0 9093:9093
# Then open: http://localhost:9093
```

---

## Quick Reference Script

Save this as `show-containers.sh`:

```bash
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
```

**Usage:**
```bash
chmod +x show-containers.sh
./show-containers.sh controlcenter-0 confluent
./show-containers.sh kafka-0 confluent
```

---

## Summary for Your Deployment

**controlcenter-0 Pod:**
```
Init Containers:
  └─ config-init-container (completed) ✅

Regular Containers (Sidecars):
  ├─ prometheus        (port 9090) ✅
  ├─ alertmanager      (port 9093) ✅
  └─ controlcenter     (port 9021) ✅
```

**Why Sidecars?**
- Prometheus scrapes metrics from Kafka brokers
- AlertManager handles alerts from Prometheus  
- Control Center displays metrics from Prometheus
- All components share pod networking (can talk via localhost)
- Lifecycle managed together (all start/stop together)

This is the **standard Confluent architecture** for integrated monitoring!
