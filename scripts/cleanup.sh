#!/usr/bin/env bash
oc delete -f wasm-pod.yaml
podman rm --all
buildah rmi quay.io/ifont/wasm-demo-app
rm -rf ./container-archive
rm -rf ./target
