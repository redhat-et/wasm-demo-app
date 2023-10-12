FROM scratch
COPY ./target/wasm32-wasi/release/wasm-demo-app.wasm /
CMD ["/wasm-demo-app.wasm"]
