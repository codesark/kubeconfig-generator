#!/bin/bash

# This script generates a kubeconfig file for a specified service account in a given namespace.

# Check if exactly 3 arguments are provided
if [ $# -ne 3 ]; then
    echo "Usage: $0 <service_account> <namespace> <kubeconfig_file>"
    exit 1
fi

# Assign command-line arguments to variables
SERVICE_ACCOUNT=$1
NAMESPACE=$2
KUBECONFIG_FILE=$3

# Check if service account exists
kubectl get serviceaccount "${SERVICE_ACCOUNT}" -n "${NAMESPACE}" &> /dev/null
if [ $? -ne 0 ]; then
    echo "Error: Service account '${SERVICE_ACCOUNT}' not found in namespace '${NAMESPACE}'"
    exit 1
fi

# Try to get the secret name for the service account
SECRET_NAME=$(kubectl get serviceaccount "${SERVICE_ACCOUNT}" -n "${NAMESPACE}" -o jsonpath='{.secrets[0].name}' 2>/dev/null)

# If no secret is found, create a token manually (for K8s v1.24+)
if [ -z "$SECRET_NAME" ]; then
    echo "No token secret found for service account. Creating a long-lived token..."
    
    # Try to create a token with a very long expiration (10 years = 315360000 seconds)
    TOKEN=$(kubectl create token "${SERVICE_ACCOUNT}" -n "${NAMESPACE}" --duration=315360000s 2>/dev/null)
    
    # If token creation fails or not available in this K8s version, create a token secret manually
    if [ -z "$TOKEN" ]; then
        echo "Creating a manual token secret for the service account..."
        
        # Generate a random secret name
        SECRET_NAME="${SERVICE_ACCOUNT}-token-$(openssl rand -hex 3)"
        
        # Create a service account token secret
        cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Secret
metadata:
  name: ${SECRET_NAME}
  namespace: ${NAMESPACE}
  annotations:
    kubernetes.io/service-account.name: ${SERVICE_ACCOUNT}
type: kubernetes.io/service-account-token
EOF

        # Wait for the token controller to populate the secret
        echo "Waiting for token controller to populate the secret..."
        for i in {1..10}; do
            ENCODED_TOKEN=$(kubectl get secret "${SECRET_NAME}" -n "${NAMESPACE}" -o jsonpath='{.data.token}' 2>/dev/null)
            if [ ! -z "$ENCODED_TOKEN" ]; then
                break
            fi
            sleep 2
        done
        
        # Decode the token
        if [ ! -z "$ENCODED_TOKEN" ]; then
            TOKEN=$(echo "$ENCODED_TOKEN" | base64 --decode)
        fi
        
        if [ -z "$TOKEN" ]; then
            echo "Error: Failed to create token for service account '${SERVICE_ACCOUNT}'"
            kubectl delete secret "${SECRET_NAME}" -n "${NAMESPACE}" 2>/dev/null
            exit 1
        fi
    fi
else
    # Get the encoded token from the secret
    ENCODED_TOKEN=$(kubectl get secret "${SECRET_NAME}" -n "${NAMESPACE}" -o jsonpath='{.data.token}')
    if [ -z "$ENCODED_TOKEN" ]; then
        echo "Error: No token found in secret '${SECRET_NAME}' for service account '${SERVICE_ACCOUNT}'"
        exit 1
    fi

    # Decode the token
    TOKEN=$(echo "$ENCODED_TOKEN" | base64 --decode)
    if [ -z "$TOKEN" ]; then
        echo "Error: Failed to decode token for service account '${SERVICE_ACCOUNT}'"
        exit 1
    fi
fi

# Get the API server URL from the current kubectl config
APISERVER=$(kubectl config view --minify -o jsonpath='{.clusters[0].cluster.server}')
if [ -z "$APISERVER" ]; then
    echo "Error: Unable to retrieve API server URL from kubectl config"
    exit 1
fi

# Get the certificate authority data from the current kubectl config
CA_CERT=$(kubectl config view --minify -o jsonpath='{.clusters[0].cluster.certificate-authority-data}')
if [ -z "$CA_CERT" ]; then
    echo "Error: Unable to retrieve certificate authority data from kubectl config"
    exit 1
fi

# Create the kubeconfig file
cat <<EOF > "${KUBECONFIG_FILE}"
apiVersion: v1
kind: Config
clusters:
- name: my-cluster
  cluster:
    certificate-authority-data: ${CA_CERT}
    server: ${APISERVER}
contexts:
- name: ci-cd-context
  context:
    cluster: my-cluster
    user: ${SERVICE_ACCOUNT}
    namespace: ${NAMESPACE}
users:
- name: ${SERVICE_ACCOUNT}
  user:
    token: ${TOKEN}
current-context: ci-cd-context
EOF

echo "Kubeconfig file created: ${KUBECONFIG_FILE}"
