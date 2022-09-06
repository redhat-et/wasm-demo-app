FROM scratch
COPY ./target/wasm32-wasi/debug/wasm-demo-app.wasm /
CMD ["/wasm-demo-app.wasm"]
