# wasm-demo-app
This repository is a tutorial for setting up a WebAssembly demo application to
be executed as a container using [crun](https://github.com/containers/crun),
[podman](https://github.com/containers/podman), and
[MicroShift](https://github.com/openshift/microshift) (OpenShift optimized for
edge computing).

If you're not interested in trying out the MicroShift portion of this tutorial,
you can optionally try a slightly older version of this tutorial using Vagrant
with Fedora. If so please see the [Fedora tutorial](docs/fedora.md). Otherwise,
the rest of this tutorial will focus on RHEL 8, as that's where MicroShift is
currently supported.
