@echo off

cd build/receiver
cargo run --release -- --host esm.mshome.net:54321
