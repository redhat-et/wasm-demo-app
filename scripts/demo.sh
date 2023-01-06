# Recorded with the doitlive recorder
#doitlive shell: /bin/bash
#doitlive prompt: damoekri
#doitlive speed: 3
#doitlive commentecho: true

# This is a demonstration on how to run WebAssebmly workloads using crun, podman, and MicroShift.
# Here are the contents of the repo:
tree

# Here is the code for our simple demo app:
cat src/main.rs

# Compile the rust app to the wasm32-wasi target using cargo:
cargo build --target wasm32-wasi

# Run the built wasm app directly with wasmtime to quickly test it:
wasmtime ./target/wasm32-wasi/debug/wasm-demo-app.wasm

# Using the Containerfile provided in this repo we build a container image for this wasm demo app workload using the following command:
buildah build --annotation "run.oci.handler=wasmtime" -t quay.io/ifont/wasm-demo-app .

# We can use crun and a config.json to execute the container manually.
# First we need to create a directory that will house the container archive and extract the container image into it:
mkdir container-archive
cd ./container-archive/
mkdir rootfs
podman export $(podman create quay.io/ifont/wasm-demo-app) | tar -C rootfs -xvf -

# Then we'll need to generate and modify a config.json container spec:
crun spec

# Modify the first and only argument to provide the path to our WASM module within the image:
sed -i 's|"sh"|"/wasm-demo-app.wasm"|' config.json

# We don't need a terminal.
sed -i 's/"terminal": true/"terminal": false/' config.json

# Set the annotation to specify the wasmtime handler. This tells crun the exact handler to use to execute the WASM module inside this container.
sed -i '/"linux": {/i \\t"annotations": {\n\t\t"run.oci.handler": "wasmtime"\n\t},' config.json

# Run the WASM module container and we can see the output from the WASM module:
crun run wasm-demo-app

# We can use also use podman to directly execute the WASM module container image without having to bother generating and modifying the config.json. Here podman will still use crun to execute the container:
podman run quay.io/ifont/wasm-demo-app

# Now let's deploy to MicroShift using the Kubernetes manifest in this repository.
cd ..

# Here we show the contents of the Kubernetes manifest. We can see it specifies the image along with the annotation that we specified when we built the image:
cat wasm-pod.yaml

# Create the pod:
oc apply -f wasm-pod.yaml

# Verify the pod is being created:
oc get pods

# Here we show the logs of the pod to see the same WASM module output and we've successfully executed a WASM module within MicroShift using crun.
oc logs -f pod-with-wasm-workload
