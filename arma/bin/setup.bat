@echo off

rustup install stable-x86_64-pc-windows-msvc
rustup install stable-i686-pc-windows-msvc

cd tools/build
bundle install
