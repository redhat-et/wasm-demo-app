# wasm-demo-app
This repository is a tutorial for setting up a WebAssembly demo application to be used within
OpenShift, such as on the Edge using MicroShift.

## Install Dependencies
Before proceeding with this tutorial, you'll need to install various
dependencies listed below.

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
   `Vagrantfile` exists:
    ```shell
    vagrant up
    ```

### Install and run crun with the wasmtime C shared library

The following steps should be executed on your Fedora 35 installation VM or
baremetal.

1. If using `vagrant` simply run:
    ```shell
    vagrant ssh
    ```

1. You'll need to enable both of these copr repos:
    ```shell
    sudo dnf copr enable copr.fedorainfracloud.org/lsm5/wasmtime
    sudo dnf copr enable copr.fedorainfracloud.org/rhcontainerbot/playground
    ```

1. Then install `crun` to get both `crun` built with `wasmtime` support and the
   `wasmtime-c-api` package that contains the `libwastime.so` wasmtime C shared
   library:
    ```shell
    sudo dnf install crun
    ```

**NOTE**: Currently the way to do this is via copr repositories until we have
official releases of these RPMs.

### Install and run cri-o

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
    sudo sh -c "echo -e \"# Add crun runtime here\n[crio.runtime.runtimes.crun]\nruntime_path = \"/usr/local/bin/crun\"\nruntime_type = \"oci\"\nruntime_root = \"/run/crun\"\" > /etc/crio/crio.conf.d/01-crio-crun.conf"
    ```

1. Restart cri-o to make sure it picks up the new config:
    ```shell
    sudo systemctl restart crio
    ```
