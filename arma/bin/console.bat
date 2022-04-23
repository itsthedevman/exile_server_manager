@echo off

SET RUST_ENV=debug
SET ESM_IS_TERMINAL=true

cargo update --package esm_message
cargo run
