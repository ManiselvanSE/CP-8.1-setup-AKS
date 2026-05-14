#!/usr/bin/env zsh
# Helper to create a docker-registry secret for Confluent images and patch SAs
# Usage: export REGISTRY USERNAME PASSWORD EMAIL; ./create-confluent-secret.sh

set -euo pipefail

: ${REGISTRY:?Please set REGISTRY (e.g., https://index.docker.io/v1/ or registry.confluent.io)}
: ${USERNAME:?Please set USERNAME}
: ${PASSWORD:?Please set PASSWORD}
: ${EMAIL:?Please set EMAIL}
NAMESPACE=${NAMESPACE:-confluent}
SECRET_NAME=${SECRET_NAME:-confluent-registry}

echo "Creating docker-registry secret '$SECRET_NAME' in namespace '$NAMESPACE'..."
kubectl create secret docker-registry ${SECRET_NAME} \
  --docker-server="${REGISTRY}" \
  --docker-username="${USERNAME}" \
  --docker-password="${PASSWORD}" \
  --docker-email="${EMAIL}" \
  -n ${NAMESPACE} --dry-run=client -o yaml | kubectl apply -f -

echo "Patching serviceaccounts 'confluent-for-kubernetes' and 'default' to use the secret..."
kubectl patch serviceaccount confluent-for-kubernetes -n ${NAMESPACE} \
  -p "{\"imagePullSecrets\":[{\"name\":\"${SECRET_NAME}\"}]}"
kubectl patch serviceaccount default -n ${NAMESPACE} \
  -p "{\"imagePullSecrets\":[{\"name\":\"${SECRET_NAME}\"}]}"

echo "Done. To restart pods so images are re-pulled run: kubectl delete pods --all -n ${NAMESPACE}"
