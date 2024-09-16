#!/bin/bash

# Exit immediately if a command exits with a non-zero status
set -e

# Variables for OS and Architecture
OS="darwin"
ARCH="arm64"

# Default values
CLUSTER_NAME="pacp"
KIND_CONFIG_FILE="kind-cluster.yaml"

# Function to display usage instructions
usage() {
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  -n, --name       Name of the Kind cluster (default: my-cluster)"
    echo "  -c, --config     Path to Kind configuration file"
    echo "  -h, --help       Display this help message"
    echo ""
    echo "Example:"
    echo "  $0 --name custom-cluster --config path/to/config.yaml"
    exit 1
}

# Function to parse command-line arguments
parse_args() {
    while [[ "$#" -gt 0 ]]; do
        case $1 in
            -n|--name)
                if [[ -n "$2" && ! "$2" =~ ^- ]]; then
                    CLUSTER_NAME="$2"
                    shift 2
                else
                    echo "Error: --name requires a non-empty option argument."
                    usage
                fi
                ;;
            -c|--config)
                if [[ -n "$2" && ! "$2" =~ ^- ]]; then
                    KIND_CONFIG_FILE="$2"
                    shift 2
                else
                    echo "Error: --config requires a non-empty option argument."
                    usage
                fi
                ;;
            -h|--help)
                usage
                ;;
            --) # End of all options
                shift
                break
                ;;
            -*|--*) # Unknown option
                echo "Unknown option: $1"
                usage
                ;;
            *) # No more options
                break
                ;;
        esac
    done
}

# Function to install prerequisites
install_prerequisites() {
    echo "Installing prerequisites: kind, kubectl, Helm, K9s, and KOTS..."

    # Install Kind
    if ! command -v kind &> /dev/null; then
        echo "Installing Kind..."
        curl -Lo ./kind "https://kind.sigs.k8s.io/dl/v0.20.0/kind-${OS}-${ARCH}"
        chmod +x ./kind
        sudo mv ./kind /usr/local/bin/kind
        echo "Kind installed successfully."
    else
        echo "Kind is already installed."
    fi

    # Install kubectl
    if ! command -v kubectl &> /dev/null; then
        echo "Installing kubectl..."
        KUBECTL_VERSION=$(curl -s https://storage.googleapis.com/kubernetes-release/release/stable.txt)
        curl -LO "https://dl.k8s.io/release/${KUBECTL_VERSION}/bin/${OS}/${ARCH}/kubectl"
        chmod +x kubectl
        sudo mv kubectl /usr/local/bin/
        echo "kubectl installed successfully."
    else
        echo "kubectl is already installed."
    fi

    # Install Helm
    if ! command -v helm &> /dev/null; then
        echo "Installing Helm..."
        curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
        echo "Helm installed successfully."
    else
        echo "Helm is already installed."
    fi

    # Install K9s
    if ! command -v k9s &> /dev/null; then
        echo "Installing K9s..."
        # Fetch the latest version of K9s from GitHub Releases
        K9S_VERSION=$(curl -s https://api.github.com/repos/derailed/k9s/releases/latest | grep tag_name | cut -d '"' -f 4)
        if [[ -z "$K9S_VERSION" ]]; then
            echo "Failed to fetch K9s version."
            exit 1
        fi
        echo "Latest K9s version: $K9S_VERSION"

        # Construct download URL
        K9S_TARBALL="k9s_${K9S_VERSION#v}_darwin_${ARCH}.tar.gz"
        DOWNLOAD_URL="https://github.com/derailed/k9s/releases/download/${K9S_VERSION}/${K9S_TARBALL}"
        echo "Downloading K9s from: $DOWNLOAD_URL"

        # Download the tarball
        curl -LO "$DOWNLOAD_URL"

        # Extract the tarball
        tar -xzf "$K9S_TARBALL"

        # Move the binary to /usr/local/bin/
        sudo mv k9s /usr/local/bin/
        chmod +x /usr/local/bin/k9s

        # Clean up
        rm "$K9S_TARBALL"

        echo "K9s installed successfully."
    else
        echo "K9s is already installed."
    fi

    # Install KOTS
    if ! command -v kots &> /dev/null; then
        echo "Installing KOTS..."
        # Fetch the latest version of KOTS from GitHub Releases
        KOTS_VERSION=$(curl -s https://api.github.com/repos/replicatedhq/kots/releases/latest | grep tag_name | cut -d '"' -f 4)
        if [[ -z "$KOTS_VERSION" ]]; then
            echo "Failed to fetch KOTS version."
            exit 1
        fi
        echo "Latest KOTS version: $KOTS_VERSION"

        # Construct download URL
        KOTS_TARBALL="kots_${KOTS_VERSION#v}_darwin_${ARCH}.tar.gz"
        DOWNLOAD_URL="https://github.com/replicatedhq/kots/releases/download/${KOTS_VERSION}/${KOTS_TARBALL}"
        echo "Downloading KOTS from: $DOWNLOAD_URL"

        # Download the tarball
        curl -LO "$DOWNLOAD_URL"

        # Extract the tarball
        tar -xzf "$KOTS_TARBALL"

        # Move the binary to /usr/local/bin/
        sudo mv kots /usr/local/bin/
        chmod +x /usr/local/bin/kots

        # Clean up
        rm "$KOTS_TARBALL"

        echo "KOTS installed successfully."
    else
        echo "KOTS is already installed."
    fi
}

# Function to create a Kind cluster
create_kind_cluster() {
    echo "Creating a Kind cluster named '${CLUSTER_NAME}'..."

    if [[ -n "$KIND_CONFIG_FILE" ]]; then
        if [[ -f "$KIND_CONFIG_FILE" ]]; then
            echo "Using Kind configuration file: $KIND_CONFIG_FILE"
            kind create cluster --name "${CLUSTER_NAME}" --config "${KIND_CONFIG_FILE}"
        else
            echo "Error: Configuration file '$KIND_CONFIG_FILE' not found."
            exit 1
        fi
    else
        kind create cluster --name "${CLUSTER_NAME}"
    fi
}

# Function to install Kubernetes components using Helm
install_k8s_components() {
    echo "Installing Kubernetes components with Helm..."

    # Example: Install NGINX Ingress Controller using Helm
    helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
    helm repo update
    helm install nginx-ingress ingress-nginx/ingress-nginx \
        --set controller.publishService.enabled=true

    echo "NGINX Ingress Controller installed successfully."

    # Add more Kubernetes components here as needed...
}

# Main function to execute all tasks
main() {
    parse_args "$@"
    install_prerequisites
    create_kind_cluster
    install_k8s_components
    echo "Kind cluster '${CLUSTER_NAME}' setup complete with Helm, K9s, KOTS, and Kubernetes components installed!"
    echo "You can now use K9s by running 'k9s' in your terminal."
    echo "KOTS is installed and ready to use. Refer to KOTS documentation for further setup."
}

# Run the main function with all passed arguments
main "$@"

