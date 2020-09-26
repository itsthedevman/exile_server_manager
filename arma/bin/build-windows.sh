#!/bin/bash

# Build the 32-bit DLL
rustup run stable-i686-pc-windows-msvc cargo build --target i686-pc-windows-msvc
cp ./target/i686-pc-windows-msvc/esm.dll ./esm.dll

# Build the 64-bit DLL
rustup run stable-x86_64-pc-windows-msvc cargo build --target x86_64-pc-windows-msvc
cp ./target/x86_64-pc-windows-msvc/esm.dll ./esm_x64.dll
