@echo off

cargo update --package esm_message
cargo update --package arma-rs

cd tools\build
bundle exec ruby esm.rb run --env=test --log-level=debug %*
