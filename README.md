# Oneliner (HA) Kubernetes Cluster Setup with Multipass and Microk8s

This Bash script automates the setup of a Kubernetes cluster using Multipass, a lightweight virtual machine manager. 
It allows you to create a single control plane node + configurable number of worker nodes 
or a high-availability (HA) cluster with three control plane nodes.

## Requirements

Before running the script, ensure that you have Multipass installed on your system. 
Multipass is a command-line tool for launching and managing Ubuntu virtual machines on various platforms.

### Installing Multipass on macOS

1. Open the Terminal app.
2. Run the following command to install Multipass:

   ```bash
   brew install --cask multipass
   ```

### Installing Multipass on Linux

1. Open your terminal.
2. Run the following command to install Multipass:

   #### On Ubuntu
   ```bash
   sudo snap install multipass --classic
   ```
   #### On RHEL9
   ```bash
   sudo dnf install https://dl.fedoraproject.org/pub/epel/epel-release-latest-9.noarch.rpm
   sudo dnf upgrade
   sudo yum install snapd
   sudo systemctl enable --now snapd.socket
   sudo ln -s /var/lib/snapd/snap /snap
   ### Either log out and back in again or restart your system to ensure snap’s paths are updated correctly.
   sudo snap install multipass
   ```

## Usage

1. Clone this repository or download the script file.
2. Edit the `.env` file that is in the same directory as the script and set the following variables:

   ```
   PROCESSORS=2  # Number of processors for each instance
   MEMORY=4G     # Memory allocation for each instance
   DISK_SIZE=20G # Disk size for each instance
   CONTROL_PLANE_NAME=k8s-control-plane  # Base name for control plane nodes
   WORKER_NAME_PREFIX=k8s-worker  # Base name for worker nodes
   NUM_WORKERS=3  # Number of worker nodes
   HA=true  # Set to 'true' for high-availability mode (three control plane nodes), or 'false' for single control plane node
   ```

3. Make the script executable:

   ```bash
   chmod +x script.sh
   ```

4. Run the script with the `create` option to launch and configure the Kubernetes cluster:

   ```bash
   ./script.sh create
   ```

   This will launch the instances, configure the control plane and worker nodes, and add the worker nodes to the cluster.

5. To destroy all instances, run the script with the `destroy` option:

   ```bash
   ./script.sh destroy
   ```

   This will delete all instances created by the script.

## Script Functionality

The script performs the following tasks:

- Launches the specified number of control plane and worker nodes using Multipass.
- Installs Microk8s on all nodes and configures the necessary settings.
- Joins the worker nodes to the Kubernetes cluster using the join command obtained from the control plane node(s).
- Displays the list of nodes in the Kubernetes cluster after successful setup.