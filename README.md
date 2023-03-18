# wasm-demo-app
This repository is a tutorial for setting up a WebAssembly demo application to
be executed as a container using [crun](https://github.com/containers/crun),
[podman](https://github.com/containers/podman), and
[MicroShift](https://github.com/openshift/microshift) (OpenShift optimized for
edge computing).

If you're not interested in trying out the MicroShift portion of this tutorial,
you can optionally try a slightly older version of this tutorial using Fedora.
If so please see the [Fedora tutorial](docs/fedora.md). Otherwise, the rest of
this tutorial will focus on RHEL 8, as that's where MicroShift is currently
supported.

## Install Dependencies
Before proceeding with this tutorial, you'll need to install various
dependencies listed below. We list out all of the steps but leave it up to the
user if they want to separate their environments between a development
environment and a deployment environment, or they could certainly be the same
system.

Additionally, not all installation steps are required below. It really depends
on which deployment examples you're interested in e.g. `wasmedge`, `crun`,
`podman`, `cri-o`, `MicroShift` or all of the above. So you may want to look at
the deployment options below in [Run WASM App](#run-wasm-app) to determine
which dependencies you should install.

### Install RHEL 8
First you'll need a RHEL 8 installation on a VM or baremetal system. Here we
focus on a VM installation using the [libvirt](https://libvirt.org/)
virtualization platform.

1. Download the Red Hat Enterprise Linux 8.X DVD ISO image for the x86-64
   architecture from the [Red Hat
   Developer](https://developers.redhat.com/products/rhel/download) site and copy
   the file to the `/var/lib/libvirt/images` directory. The latest RHEL 8 minor
   version at this time is 7. **NOTE: This has only been tested on the x86-64
   architecture.**
1. Download the OpenShift pull secret from the
   [https://console.redhat.com/openshift/downloads#tool-pull-secret](https://console.redhat.com/openshift/downloads#tool-pull-secret)
   page and save it into the `~/.pull-secret.json` file.
1. Run the following command to install the necessary components for the
   [libvirt](https://libvirt.org/) virtualization platform and its [QEMU
   KVM](https://libvirt.org/drvqemu.html) hypervisor driver.
   ```shell
   sudo dnf install -y libvirt virt-manager virt-install virt-viewer libvirt-client qemu-kvm qemu-img
   ```
1. Run the following commands to create and run the virtual machine with the
   minimum of 2 CPU cores, 2GB RAM and 20GB storage minimum. Feel free to increase the
   resources if desired.
   ```shell
   VMNAME=microshift-starter
   DVDISO=/var/lib/libvirt/images/rhel-8.7-x86_64-dvd.iso
   KICKSTART=https://raw.githubusercontent.com/openshift/microshift/microshift-4.12.5/docs/config/microshift-starter.ks
   
   sudo -b bash -c " \
   cd /var/lib/libvirt/images && \
   virt-install \
       --name ${VMNAME} \
       --vcpus 2 \
       --memory 2048 \
       --disk path=./${VMNAME}.qcow2,size=20 \
       --network network=default,model=virtio \
       --events on_reboot=restart \
       --location ${DVDISO} \
       --extra-args \"inst.ks=${KICKSTART}\" \
       --wait \
   "
   ```
   Watch the OS console of the virtual machine to see the progress of the
   installation, waiting until the machine is rebooted and the login prompt
   appears. The OS console is also accessible from the `virt-manager` GUI by
   running `sudo virt-manager`.
1. Once the virtual machine installation is complete and boots to the login
   prompt, you can now log into the machine either using the OS console, or
   using SSH (preferred) and the user credentials `redhat:redhat`. To log in
   using SSH, get the IP address of the VM with the following command:
   ```shell
   sudo virsh domifaddr microshift-starter
    Name       MAC address          Protocol     Address
    -------------------------------------------------------------------------------
     vnet2      52:54:00:d6:ab:4b    ipv4         192.168.122.111/24
   ```
1. Set an environment variable with the IP address of the virtual machine.
   ```shell
   RHEL_VM_IP_ADDR=192.168.122.111
   ```
1. Copy over your SSH public key over to the virtual machine for passwordless
   authentication.
   ```shell
   ssh-copy-id redhat@${RHEL_VM_IP_ADDR}
   ```
1. Copy your pull secret file to the MicroShift virtual machine using
   `redhat:redhat` credentials:
   ```shell
   scp ~/.pull-secret.json redhat@${RHEL_VM_IP_ADDR}:
   ```
1. Log into the MicroShift virtual machine:
   ```shell
   ssh redhat@${RHEL_VM_IP_ADDR} # when prompted, password is `redhat`
   ```
1. Once you're logged in, register your RHEL machine and attach your
   subscriptions. The credentials to use will be your username/password used
   for your Red Hat account.
   ```shell
   sudo subscription-manager register --auto-attach
   ```

### Install `rust` toolchain and add the `wasm32-wasi` target

Run these commands on your development machine:

```shell
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh
rustup target add wasm32-wasi
```

### Install `crun` with the `wasmedge` runtime and shared library

The following steps should be executed on your RHEL 8 virtual machine
installation.

1. On RHEL 8 users should first disable the `container-tools` module in order
   to avoid conflicts with packages from the Copr repos:
   ```shell
   sudo dnf module disable container-tools -y
   ```
1. You'll need to enable the following EPEL and Copr repos:
    ```shell
    sudo dnf install -y https://dl.fedoraproject.org/pub/epel/epel-release-latest-8.noarch.rpm
    sudo dnf copr enable -y copr.fedorainfracloud.org/rhcontainerbot/podman-next
    ```
1. Then install `crun` to get `crun` built with `wasmedge` support by relying
   on the `libwasmedge.so` shared library installed by the `wasmedge` package.
   Here we install the `crun-wasm` RPM as it contains all the right
   dependencies i.e. `crun` and `wasmedge`. Note that `crun-wasm` is just a
   symbolic link to `crun`.
   ```shell
   sudo dnf install -y crun-wasm
   ```
1. Verify `crun` is installed that enables support for `wasmedge`:
    ```shell
    crun --version | grep wasmedge
    ```

**NOTE**: Currently the way to do this is via EPEL and Copr repositories until we have
official releases of these RPMs.

### Install `podman`

You'll still need `crun` in order to execute the wasm app with `podman`, so be
sure to install the `crun` dependency in the previous step as well. Then run
the following command from your RHEL virtual machine:

```shell
sudo dnf install -y podman
```

### Install `buildah`

On your development system or wherever you will be buildling the OCI container
image with `buildah`, run the following command:

```shell
sudo dnf install -y buildah
```

### Install MicroShift and CRI-O

From your RHEL virtual machine, follow the below instructions to install
MicroShift and CRI-O.

1. Enable the MicroShift RPM repos and install MicroShift, `cri-o`, and the
   `oc` and `kubectl` clients:
   ```shell
   sudo subscription-manager repos \
        --enable rhocp-4.12-for-rhel-8-x86_64-rpms \
        --enable fast-datapath-for-rhel-8-x86_64-rpms
   sudo dnf install -y microshift-4.12.6 openshift-clients
   ```
1. Confgure the minimum required firewall rules:
   ```shell
   sudo firewall-cmd --permanent --zone=trusted --add-source=10.42.0.0/16
   sudo firewall-cmd --permanent --zone=trusted --add-source=169.254.169.1
   sudo firewall-cmd --reload
   ```
1. Configure `cri-o` to use the pull secret:
   ```shell
   sudo cp ~redhat/.pull-secret.json /etc/crio/openshift-pull-secret
   ```
1. Configure `cri-o` to use `crun`:
   ```shell
   sudo sed -i 's/# default_runtime =.*/default_runtime = "crun"/' /etc/crio/crio.conf
   ```
1. Start the `microshift` service:
   ```shell
   sudo systemctl enable --now microshift.service
   ```
1. Enable MicroShift access for the `redhat` user account:
   ```shell
   mkdir ~/.kube
   sudo cat /var/lib/microshift/resources/kubeadmin/kubeconfig > ~/.kube/config
   ```
1. Finally, check if MicroShift is up and running by executing the below
   `oc` commands. 

   > When started for the first time, it may take a few
   minutes to download and initialize the container images used by MicroShift.
   On subsequent restarts, all the MicroShift services should take a few
   seconds to become available.
   ```shell
   oc get cs
   oc get pods -A
   ``` 
## Build WASM App

This example uses `rust` to compile a WebAssembly module but you can use any
supported language of choice. The following instructions are executed from your
host development system where your `rust` toolchain is installed.

### `cargo new`

This example app was originally created by executing:

```shell
cargo new hello_wasm --bin
# Or if already in the root directory:
cargo init --bin
```

### `cargo build`

Compile the `rust` app to the `wasm32-wasi` target using `cargo`:

```shell
cargo build --target wasm32-wasi
```

## Build and Push WASM App Container Image

Use the `Containerfile` provided in this repo to build a container image for
this wasm demo app workload using the below instructions.

### Build Container Image

```shell
buildah build --annotation "module.wasm.image/variant=compat" --platform wasi/wasm -t <registry>/<repo>/wasm-demo-app .
```

### Push Container Image

This step is only necessary if you're deploying to a different system than
where you built the image.

```shell
buildah login <registry>
buildah push <registry>/<repo>/wasm-demo-app
```

## Run WASM App

There are several ways to run the wasm binary depending on what you're
interested in and each one is documented below:

### Using `wasmedge`

You can run the built wasm app directly with `wasmedge`. This is ideal for
quick iterative development and testing.

First, copy over the built Wasm module from your host development system to the
RHEL virtual machine:

```shell
scp ./target/wasm32-wasi/debug/wasm-demo-app.wasm redhat@${RHEL_VM_IP_ADDR}:
```

Then execute it with the following command:

```shell
wasmedge ~/wasm-demo-app.wasm
```
### Using `crun`

You can use `crun` and a `config.json` to execute your container manually.

First we need to create a directory that will house the container archive and
extract the container image into it:

```shell
mkdir container-archive
cd ./container-archive/
mkdir rootfs
podman export $(podman create <registry>/<repo>/wasm-demo-app) | tar -C rootfs -xvf -
```

Then you'll need to generate and modify a `config.json` container spec:

```shell
crun spec
sed -i 's|"sh"|"/wasm-demo-app.wasm"|' config.json
sed -i 's/"terminal": true/"terminal": false/' config.json
sed -i '/"linux": {/i \\t"annotations": {\n\t\t"module.wasm.image/variant": "compat"\n\t},' config.json
```

Then you can run the container with:

```shell
crun run wasm-demo-app
```

Additionally, you can use the container lifecycle operations:

```shell
crun create wasm-demo-app

# View the container is created and in the "created" state.
crun list

# Start the process inside the container.
crun start wasm-demo-app

# After 5 seconds view that the container has exited and is now in the stopped state.
crun list

# Now delete the container.
crun delete wasm-demo-app
```

### Using `podman`

You'll need to have `crun` installed to execute the wasm app with `podman`, so
be sure you install that first if you haven't already.

```shell
podman run --platform=wasi/wasm <registry>/<repo>/wasm-demo-app
```

### Using MicroShift

Use the `wasm-pod.yaml` Kubernetes manifest in this repository to deploy with
MicroShift. If you're using a single system for the development, building and
deployment of this example app, then skip the `scp` command. Otherwise, execute
the following command from your development system to copy over the Kubernetes
manifest to your RHEL virtual machine:

```shell
scp ./wasm-pod.yaml redhat@${RHEL_VM_IP_ADDR}:
```
Then from your RHEL virtual machine execute the below commands:

```shell
oc apply -f ~/wasm-pod.yaml
oc get pods
oc logs -f pod-with-wasm-workload
```

#### Accessing the MicroShift cluster remotely from a different host

If you're preferring to run `oc` and `kubectl` commands from your development
system to the system running your MicroShift cluster, then copy over the
`kubeconfig` and either open up port `6443` to talk to the Kube API Server, or
use SSH port forwarding from your development system to your virtual machine
system. Both methods are documented below.

##### Copy `kubeconfig`

Copy over the `kubeconfig` using the following commands:

```shell
mkdir ~/.kube
scp redhat@${RHEL_VM_IP_ADDR}:.kube/config ~/.kube/config
```

##### Opening the Firewall

From your RHEL virtual machine, open the firewall port for the Kubernetes API
server (`6443/tcp`) by running the following command:

```shell
sudo firewall-cmd --permanent --zone=public --add-port=6443/tcp && sudo firewall-cmd --reload
```

Then on your development system replace the `server` field in your `kubeconfig`
file with the name or IP address of your RHEL virtual machine running
MicroShift by running the following command:

```shell
sed -i "s|server: https://127.0.0.1:6443|server: https://${RHEL_VM_IP_ADDR}:6443|" ~/.kube/config
```

##### SSH Port Forwarding

If you don't want to open up the firewall port for the Kubernetes API server,
then forward port `6443` using SSH port forwarding by executing the following
command:

```shell
RHEL_VM_IP_ADDR=192.168.122.111
ssh -L 6443:${RHEL_VM_IP_ADDR}:6443 redhat@${RHEL_VM_IP_ADDR}
```

##### Test `oc` command from your development system

Run the following commands and verify communication is successful:

```shell
oc cluster-info
oc get pods -A
```
