@echo off

cargo update --package esm_message

cd tools\build
bundle exec ruby esm.rb run --env=test --log-level=debug %*
