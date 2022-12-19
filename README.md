# wasm-demo-app
This repository is a tutorial for setting up a WebAssembly demo application to be used within
OpenShift, such as on the Edge using MicroShift.

## Install Dependencies
Before proceeding with this tutorial, you'll need to install various
dependencies listed below. We list out all of the steps but leave it up to the
user if they want to separate their environments between a development
environment and a deployment environment, or they could certainly be the same
system.

Additionally, not all installation steps are required below. It really depends
on which deployment examples you're interested in e.g. wasmtime, crun, podman,
crio, MicroShift or all of the above. So you may want to look at the
deployment options below in [Run WASM App](#run-wasm-app) to determine which
dependencies you should install.

### Install Fedora 35
First you'll need a Fedora 35 installation on a VM or baremetal system. For
easy setup, this repo contains a [Vagrantfile](Vagrantfile) to be used for creating
a Fedora 35 virtual machine quickly and easily.
1. Install vagrant on your host e.g. Fedora:
    ```shell
    sudo dnf install vagrant
    ```

1. Enable `libvirtd` and `virtnetworkd` services:
    ```shell
    sudo systemctl enable --now libvirtd.service
    sudo systemctl enable --now virtnetworkd.service
    ```

1. Create and run virtual machine from the root of this repo i.e. where
   the `Vagrantfile` file exists:
    ```shell
    vagrant up
    ```

### Install `rust` toolchain

```shell
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh
```

### Add `wasm32-wasi` `rust` target

```shell
rustup target add wasm32-wasi
```

### Install `wasmtime` runtime

```shell
curl https://wasmtime.dev/install.sh -sSf | bash
```

### Install and run `crun` with the `wasmtime` C shared library

The following steps should be executed on your Fedora 35 installation VM or
baremetal.

1. If using `vagrant` simply run:
    ```shell
    vagrant ssh
    ```

1. You'll need to enable both of these copr repos:
    ```shell
    sudo dnf copr enable -y copr.fedorainfracloud.org/rhcontainerbot/podman-next
    ```

1. Then install `crun` and `wasmtime-c-api` to get both `crun` built with `wasmtime` support and the
   `wasmtime-c-api` package that contains the `libwastime.so` wasmtime C shared
   library:
    ```shell
    sudo dnf install -y crun wasmtime-c-api
    ```
1. Verify a `crun` is installed that enables support for `wasmtime`:
    ```shell
    crun --version | grep wasmtime
    ```

**NOTE**: Currently the way to do this is via copr repositories until we have
official releases of these RPMs.


### Install `podman` and `buildah`

You'll still need `crun` in order to execute the wasm app with `podman`, so be
sure to install the `crun` dependency as well.

```shell
sudo dnf install -y podman buildah
```

### Install and run `crio`

1. Execute the following commands to install cri-o and verify it is enabled and
running:
    ```shell
    sudo dnf module enable -y cri-o:1.22
    sudo dnf install -y cri-o cri-tools
    sudo systemctl enable crio --now
    sudo systemctl status crio
    ```

1. Enable cri-o to use crun:
    ```shell
    sudo sed -i '/^\[crio.runtime\]/a default_runtime = "crun"' /etc/crio/crio.conf
    sudo mkdir /etc/crio/crio.conf.d/
    sudo sh -c "echo -e '# Add crun runtime here\n[crio.runtime.runtimes.crun]\nruntime_path = \"/usr/bin/crun\"\nruntime_type = \"oci\"\nruntime_root = \"/run/crun\"' > /etc/crio/crio.conf.d/01-crio-crun.conf"
    ```

1. Restart cri-o to make sure it picks up the new config:
    ```shell
    sudo systemctl restart crio
    ```

### Install MicroShift

Follow the below instructions directly from the MicroShift website:
1. [Install and deploy
   MicroShift](https://microshift.io/docs/getting-started/#deploying-microshift)
1. [Install the OpenShift and/or kubectl clients](https://microshift.io/docs/getting-started/#install-clients)
1. [Copy
   Kubeconfig](https://microshift.io/docs/getting-started/#copy-kubeconfig)
1. Verify MicroShift is running (this could take a few minutes):
    ```shell
    oc get nodes
    oc get pods -A
    ```

## Build WASM App

This example uses `rust` to compile a WebAssembly module but you can use any
supported language of choice. The following instructions are executed from your
host sandbox environment i.e. outside the VM running MicroShift/cri-o/crun,
where your `rust` toolchain is installed.

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
this wasm demo app workload using the below instruction.

### Build Container Image

```shell
buildah build --annotation "run.oci.handler=wasmtime" -t <registry>/<repo>/wasm-demo-app .
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

### Using `wastime`

You can run the built wasm app directly with `wasmtime`. This is ideal for
quick iterative development and testing:

```shell
wasmtime ./target/wasm32-wasi/debug/wasm-demo-app.wasm
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
sed -i '/"linux": {/i \\t"annotations": {\n\t\t"run.oci.handler": "wasmtime"\n\t},' config.json
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
be sure you install that first.

```shell
podman run wasm-demo-app
```

### Using MicroShift

Use the `wasm-pod.yaml` Kubernetes manifest in this repository to deploy with
MicroShift. If you're using a single system for the development, building and
deployment of this example app, then execute the following:

```shell
oc apply -f wasm-pod.yaml
oc get pods
oc logs -f pod-with-wasm-workload
```

#### Running `oc` commands from a different host
If you're preferring to run `oc` and `kubectl` commands from your development
system to the system running your MicroShift cluster, then copy over the
`kubeconfig` and either open up port `6443` to talk to the Kube API Server, or
use SSH port forwarding from your development system to your deployment system.

##### Copy `kubeconfig`
If you used `vagrant` to create your MicroShift cluster, then copy over the
`kubeconfig` using the following commands:

```shell
mkdir ~/.kube
vagrant ssh-config --host f35 > ssh_config
scp -F ssh_config f35:.kube/config ~/.kube/config
```
##### SSH Port Forwarding
If you used `vagrant` to create your MicroShift cluster, then forward port
`6443` using SSH port forwarding by executing the following command:

```shell
MICROSHIFT_HOST_IP_ADDR=$(awk '/HostName/ {print $2}' ssh_config)
ssh -F ssh_config -L 6443:${MICROSHIFT_HOST_IP_ADDR}:6443 f35
```

##### Test `oc` command from your development system

Run the following command and verify it matches the output shown:

```shell
→ oc cluster-info
Kubernetes control plane is running at https://127.0.0.1:6443

To further debug and diagnose cluster problems, use 'kubectl cluster-info
dump'.
```
