@echo off

cd tools\build
bundle exec ruby esm.rb run %*
