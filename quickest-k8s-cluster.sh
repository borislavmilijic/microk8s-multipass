#!/bin/bash

# Set alias for multipass command
shopt -s expand_aliases
alias mp='multipass'

# Load variables from .env file
source .env

# Function to check if a node exists
node_exists() {
  local node_name=$1
  mp list | grep -q "$node_name"
}

# Function to launch instances concurrently
launch_instances() {
  if ! node_exists "$CONTROL_PLANE_NAME-1"; then
    mp launch -c "$PROCESSORS" -m "$MEMORY" -d "$DISK_SIZE" -n "$CONTROL_PLANE_NAME-1" 22.04 &
    wait
  fi
  
  if [ "$HA" == "true" ]; then
    for i in $(seq 2 3); do
      if ! node_exists "$CONTROL_PLANE_NAME-$i"; then
        mp launch -c "$PROCESSORS" -m "$MEMORY" -d "$DISK_SIZE" -n "$CONTROL_PLANE_NAME-$i" 22.04 &
      fi
    done
    wait
  else
    if ! node_exists "$CONTROL_PLANE_NAME-1"; then
      mp launch -c "$PROCESSORS" -m "$MEMORY" -d "$DISK_SIZE" -n "$CONTROL_PLANE_NAME" 22.04 &
      wait
    fi
    for i in $(seq 1 "$NUM_WORKERS"); do
      if ! node_exists "$WORKER_NAME_PREFIX-$i"; then
        mp launch -c "$PROCESSORS" -m "$MEMORY" -d "$DISK_SIZE" -n "$WORKER_NAME_PREFIX-$i" 22.04 &
      fi
    done
    wait
  fi
}

# Function to configure nodes
configure_node() {
  local node_name=$1
  mp exec "$node_name" -- bash -c "sudo snap install microk8s --classic --channel=1.30/stable"
  mp exec "$node_name" -- bash -c "sudo iptables -P FORWARD ACCEPT"
  mp exec "$node_name" -- bash -c "sudo usermod -a -G microk8s ubuntu"
  mp exec "$node_name" -- bash -c "mkdir -p ~/.kube"
  mp exec "$node_name" -- bash -c "chmod 0700 ~/.kube"
  mp exec "$node_name" -- bash -c "microk8s status --wait-ready"
}

# Function to add worker nodes to the cluster
add_nodes() {
  if [ "$HA" == "true" ]; then
    for i in $(seq 2 3); do
      join_command=$(mp exec "$CONTROL_PLANE_NAME-1" -- bash -c "microk8s add-node" | grep -m 1 "microk8s join.*")
      mp exec "$CONTROL_PLANE_NAME-$i" -- bash -c "$join_command"
      wait
    done
  else
    for i in $(seq 1 "$NUM_WORKERS"); do
      join_command=$(mp exec "$CONTROL_PLANE_NAME-1" -- bash -c "microk8s add-node" | grep -m 1 "microk8s join.*--worker")
      mp exec "$WORKER_NAME_PREFIX-$i" -- bash -c "$join_command"
      wait
    done
  fi
}

# Function to set active Kubernetes config
export_kubeconfig() {
  if [ "$EXPORT_KUBECONFIG" == "true" ]; then
    mp exec "$CONTROL_PLANE_NAME-1" -- bash -c "microk8s config" > multipass-microk8s-cluster
    echo "KUBECONFIG exported to $(pwd)/multipass-microk8s-cluster"
    echo "Now you can set it with export KUBECONFIG=./multipass-microk8s-cluster and use it with kubectl or oc commands"
  fi
}

# Function to destroy instances
destroy_instances() {
  mp delete --purge --all
  rm -rf "$(pwd)/multipass-microk8s-cluster"
}

# Check if the 'create' or 'destroy' option is provided
if [ "$1" == "create" ]; then
  # Launch instances concurrently
  launch_instances

  # Configure control plane node
  if [ "$HA" == "true" ]; then
    for i in $(seq 1 3); do
      configure_node "$CONTROL_PLANE_NAME-$i"
      if [ $? -ne 0 ]; then
        echo "Failed to configure nodes."
        exit 1
      fi
    done
  else
    configure_node "$CONTROL_PLANE_NAME-1"
    if [ $? -ne 0 ]; then
      echo "Failed to configure nodes."
      exit 1
    fi
    # Configure worker nodes
    for i in $(seq 1 "$NUM_WORKERS"); do
      configure_node "$WORKER_NAME_PREFIX-$i"
      if [ $? -ne 0 ]; then
        echo "Failed to configure nodes."
        exit 1
      fi
    done
  fi

  # Add worker nodes to the cluster
  add_nodes

  if [ $? -eq 0 ]; then
    echo "Waiting for kubernetes nodes to become ready..."
    sleep 10
    mp exec "$CONTROL_PLANE_NAME-1" -- bash -c "microk8s kubectl get nodes"
    echo "Kubernetes cluster setup completed successfully!"

    # Export Kubernetes config
    export_kubeconfig
  else
    echo "Failed to add nodes to the cluster."
    exit 1
  fi

elif [ "$1" == "destroy" ]; then
  destroy_instances
  echo "All instances have been deleted."
else
  echo "Usage: $0 create|destroy"
  echo "create - Launch and configure Kubernetes cluster"
  echo "destroy - Delete all instances"
fi