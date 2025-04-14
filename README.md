# Service Account Kubeconfig Generator

A Bash script that generates a kubeconfig file for a specified Kubernetes service account.

## Overview

This script creates a kubeconfig file for a Kubernetes service account in a specified namespace. It automatically handles different Kubernetes versions (pre and post 1.24) and provides options for long-lived tokens, making it useful for CI/CD pipelines and automation processes.

## Features

- Works with both newer and older Kubernetes versions
- Creates long-lived tokens for service accounts 
- Generates complete kubeconfig files with proper authentication
- Includes error handling and validation
- Multiple token generation methods based on cluster capabilities

## Prerequisites

- `kubectl` installed and configured with access to your cluster
- Bash shell environment
- Proper permissions to create and view service accounts and secrets

## Usage

```bash
./generate-kubeconfig.sh <service_account> <namespace> <kubeconfig_file>
```

### Parameters

- `service_account`: Name of the service account to create a kubeconfig for
- `namespace`: Kubernetes namespace where the service account exists
- `kubeconfig_file`: Path where the resulting kubeconfig file should be saved

### Example

```bash
./generate-kubeconfig.sh ci-cd-pipeline ci-cd ./ci-cd-kubeconfig.yaml
```

This generates a kubeconfig file for the `ci-cd-pipeline` service account in the `ci-cd` namespace and saves it to `./ci-cd-kubeconfig.yaml`.

## How It Works

The script uses the following process:

1. Verifies the service account exists in the specified namespace
2. Checks if the service account has an existing token secret
3. If no secret exists:
   - Attempts to create a long-lived token using the TokenRequest API
   - Falls back to creating a manual token secret if needed
4. Extracts the cluster connection details from your current kubectl context
5. Generates a properly formatted kubeconfig file with all required authentication information

## Security Considerations

- Long-lived tokens present a security risk if compromised
- Consider implementing token rotation for production environments
- Some Kubernetes distributions may enforce token expiration regardless of settings
- Store the generated kubeconfig file securely

## Troubleshooting

If you encounter issues:

1. Ensure your kubectl has proper permissions to access the service account
2. Check if your Kubernetes cluster has any security policies that restrict token creation
3. Verify the service account exists in the specified namespace
4. For newer Kubernetes versions, make sure the service account has proper RBAC permissions

## License

[MIT License](LICENSE)
