@echo off

cd tools/build_receiver

cargo run --release -- --host esm.mshome.net:6969
