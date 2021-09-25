# frozen_string_literal: true

require 'rubygems'
require 'commander/import'
require 'dotenv'
require 'fileutils'
require 'file-tail'
require 'pry'

# Load the ENV
Dotenv.load("../run.env")

program :name, 'esm'
program :version, '0.0.1'
program :description, 'CLI utility to build @esm'

command :build do |c|
  c.syntax = 'esm build [options]'
  c.summary = ''
  c.description = ''
  c.example 'description', 'command example'
  c.option '--use-x32', 'Build the x32 version of the extension'
  c.action do |args, options|
    # Set some build flags
    Utils.flags(os: :windows, arch: options.use_x32 ? :x86 : :x64, env: :debug)

    # Log to the terminal
    Utils.print_info

    # Kill Arma server
    Utils.kill_arma_server

    # Clean up the build and destination directories
    Utils.clean_directories

    # Compile and copy over the DLL into the @esm mod locally
    Utils.build_and_copy_extension

    # Build the addons
    Utils.build_addons
  end
end

command :run do |c|
  c.syntax = 'esm run [options]'
  c.summary = ''
  c.description = ''
  c.example 'description', 'command example'
  c.option '--use-x32', 'Build the x32 version of the extension and start the x32 version of the server'
  c.option '--target=TARGET', String, 'The target OS to build to. Valid options: linux, windows. Defaults to: windows'
  c.action do |args, options|
    build_target =
      if options.target == "linux"
        :linux
      else
        :windows
      end

    # Set some build flags
    Utils.flags(os: build_target, arch: options.use_x32 ? :x86 : :x64, env: :debug)

    # Check for required stuff
    next say("Server path is missing, please set it using `ESM_SERVER_PATH` environment variable") if Utils::SERVER_DIRECTORY.empty?
    next say("Deployment path is missing, please set it using `ESM_SERVER_PATH` environment variable") if Utils.deployment_directory.empty?

    # Log to the terminal
    Utils.print_info

    # Kill Arma server
    Utils.kill_arma_server

    # Clean up the build and destination directories
    Utils.clean_directories

    # Compile and copy over the DLL into the @esm mod locally
    Utils.build_and_copy_extension

    # Build and copy the mod to destination
    Utils.build_and_copy_mod

    # Start the server
    Utils.start_server

    # Pull up the logs
    Utils.open_logs
  end
end

class Utils
  GIT_DIRECTORY = File.expand_path("../../")
  BUILD_DIRECTORY = "#{GIT_DIRECTORY}/target/arma"
  SERVER_DIRECTORY = ENV["ESM_SERVER_PATH"] || ""
  REMOTE_HOST = ENV["ESM_REMOTE_HOST"] || ""
  ADDONS = [
    "exile_server_manager",
    "exile_server_overwrites",
    "exile_server_xm8",
    "exile_server_hacking",
    "exile_server_grinding",
    "exile_server_charge_plant_started",
    "exile_server_flag_steal_started",
    "exile_server_player_connected"
  ].freeze

  TARGETS = {
    windows: {
      x86: "i686-pc-windows-msvc",
      x64: "x86_64-pc-windows-msvc"
    },
    linux: {
      x86: "i686-unknown-linux-gnu",
      x64: "x86_64-unknown-linux-gnu"
    }
  }.freeze

  def self.print_info
    puts <<~STRING
      | ESM Build Tool
      |   OS: #{@os}
      |   ARCH: #{@arch}
      |   ENV: #{@env}
      |   GIT_DIRECTORY: #{GIT_DIRECTORY}
      |   BUILD_DIRECTORY: #{BUILD_DIRECTORY}
      |   SERVER_DIRECTORY: #{SERVER_DIRECTORY}
      |   REMOTE_HOST: #{REMOTE_HOST}
    STRING
  end

  def self.flags(os:, arch:, env:)
    @os = os
    @arch = arch
    @env = env
  end

  def self.deployment_directory
    @deployment_directory ||= lambda do
      path = ENV["ESM_DEPLOYMENT_PATH"] || ""
      return "" if path.empty?

      if @arch == :x64
        path + "_x64"
      else
        path
      end
    end.call
  end

  def self.target
    @target ||= TARGETS[@os][@arch]
  end

  def self.server_directory
    @server_directory ||= SERVER_DIRECTORY.gsub("\\", "/")
  end

  def self.local_deployment?
    REMOTE_HOST.empty?
  end

  def self.kill_arma_server
    log("Killing Arma Server... ") do
      if @os == :windows
        if @arch == :x64
          `taskkill /IM "arma3server_x64.exe" /F`
        else
          `taskkill /IM "arma3server.exe" /F`
        end
      else
        if @arch == :x64
          `ssh #{REMOTE_HOST} "killall arma3server_x64"`
        else
          `ssh #{REMOTE_HOST} "killall arma3server"`
        end
      end
    end
  end

  def self.clean_directories
    log("Cleaning directories... ") do
      # Remove the @esm in target/arma
      if File.directory?("#{BUILD_DIRECTORY}/@esm")
        FileUtils.remove_dir("#{BUILD_DIRECTORY}/@esm")
      end

      # Recreate the directory
      FileUtils.mkdir_p("#{BUILD_DIRECTORY}/@esm")

      # Copy the @esm into target/arma (Except addons)
      FileUtils.cp_r("#{GIT_DIRECTORY}/@esm", BUILD_DIRECTORY)
      FileUtils.remove_dir("#{BUILD_DIRECTORY}/@esm/addons")

      # Create the addons folder in target/arma/@esm
      FileUtils.mkdir_p("#{BUILD_DIRECTORY}/@esm/addons")

      # Delete the esm.log if it exists
      FileUtils.rm("#{BUILD_DIRECTORY}/@esm/log/esm.log")
    end
  end

  def self.build_and_copy_extension
    build_extension
    copy_extension
  end

  # This is Windows only for now...
  def self.build_extension
    log("Compiling client... ") do
      command =
        if @os == :windows
          "rustup run stable-#{target} cargo build --target #{target}"
        else
          "cargo build --target #{target}"
        end

      command += " --release" if @env == :release

      `#{command}`
    end
  end

  def self.copy_extension
    log("Copying client to @esm... ") do
      path =
        if @os == :windows
          "#{GIT_DIRECTORY}/target/#{target}/#{@env}/esm_client.dll"
        else
          "#{GIT_DIRECTORY}/target/#{target}/#{@env}/libesm_client.so"
        end

      if @os == :windows
        filename = @arch == :x64 ? "esm_x64.dll" : "esm.dll"
        FileUtils.move(path, "#{BUILD_DIRECTORY}/@esm/#{filename}")
      else
        FileUtils.cp_r(path, "#{BUILD_DIRECTORY}/@esm/esm.so")
      end
    end
  end

  def self.build_and_copy_mod
    build_addons
    copy_mod
  end

  def self.build_addons
    log("Building addons... ") do
      ADDONS.each do |addon|
        source = "#{GIT_DIRECTORY}/@esm/addons/#{addon}"
        destination = "#{BUILD_DIRECTORY}/@esm/addons/#{addon}"

        if @os == :windows
          `"C:\\Program Files\\PBO Manager v.1.4 beta\\PBOConsole.exe" -pack "#{source}" "#{destination}.pbo"`
        else
          `makepbo -P -@=#{addon} "#{source}" "#{destination}"`
        end
      end
    end
  end

  def self.copy_mod
    log("Copying @esm to server... ") do
      # Remove the @esm mod in the destination
      remove_dir("#{deployment_directory}/@esm")
      copy_dir("#{BUILD_DIRECTORY}/@esm", "#{deployment_directory}/@esm")
    end
  end

  def self.start_server
    log("Starting Arma 3... ") do
      if @os == :windows
        if @arch == :x64
          `cd #{server_directory} && START Deploy_ESM_x64.bat && EXIT`
        else
          `cd #{server_directory} && START Deploy_ESM.bat && EXIT`
        end
      else
        script = @arch == :x64 ? "esm_arma_x64.sh" : "esm_arma.sh"

        command = <<~STRING
          cd ~/arma_server && \
          rm -rf @esm && \
          rm -rf @exile && \
          rm -rf @exileserver && \
          rm -rf mpmissions && \
          cp -r #{deployment_directory}/* ~/arma_server/ && \
          cd ~/ && ./#{script}
        STRING

        `ssh #{REMOTE_HOST} "#{command}"`
      end
    end
  end

  def self.remove_dir(path)
    if local_deployment?
      FileUtils.remove_dir(path)
    else
      `ssh #{REMOTE_HOST} "rm -rf #{path}"`
    end
  end

  def self.copy_dir(source_path, destination_path)
    if local_deployment?
      FileUtils.cp_r(source_path, destination_path)
    else
      `scp -r #{source_path} #{REMOTE_HOST}:#{destination_path}`
    end
  end

  def self.open_logs
    log("Opening server.rpt... ") do
      path = "#{server_directory}/ArmAServer/ArmAServer/*.rpt"
      50.times do
        rpt = Dir.glob(path).first
        next sleep(0.5) if rpt.nil?

        break system("code #{rpt}")
      end
    end

    log("Opening esm.log... ") do
      path = "#{server_directory}/ArmAServer/@esm/log/esm.log"
      50.times do
        next sleep(0.5) if !File.exist?(path)

        File.open(path) do |log|
          log.extend(File::Tail)
          log.interval = 1
          log.backward(1000)
          log.tail { |line| puts line }
        end
      end
    end

    puts "<esm_bt> Failed to open esm.log"
  rescue SystemExit, Interrupt
    puts "cancelled"
    kill_arma_server
    exit
  end

  def self.log(message, &block)
    print "<esm_bt> - #{message}"
    result = yield
    puts "done"
    result
  end
end
