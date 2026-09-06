import { readFile } from "node:fs/promises";
import process from "node:process";
import { WASI } from "node:wasi";

const wasmPath = process.argv[2];
if (!wasmPath) {
  throw new Error("Usage: node run-node.mjs <wasm-path>");
}

const wasi = new WASI({
  version: "preview1",
  args: [wasmPath],
});
const module = await WebAssembly.compile(await readFile(wasmPath));
const instance = await WebAssembly.instantiate(module, wasi.getImportObject());
wasi.start(instance);
