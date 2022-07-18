@echo off

cd build/receiver
cargo run --release -- --host esm.mshome.net:54321 --database-uri mysql://root:password12345@localhost:3306/exile_test_esm
