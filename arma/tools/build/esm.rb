# frozen_string_literal: true

require 'rubygems'
require "active_support"
require "active_support/all"
require 'commander/import'
require 'dotenv'
require 'faker'
require 'fileutils'
require 'file-tail'
require 'pry'
require 'yaml'

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

    # Clean the database
    Utils.clean_database

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

  def self.clean_database
    log("Cleaning database... ") do
      DatabaseCleaner.run
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


class DatabaseCleaner
  FLAG_TEXTURES = [
    "exile_assets\\texture\\flag\\flag_mate_bis_co.paa", "exile_assets\\texture\\flag\\flag_mate_vish_co.paa", "exile_assets\\texture\\flag\\flag_mate_hollow_co.paa",
    "exile_assets\\texture\\flag\\flag_mate_legion_ca.paa", "exile_assets\\texture\\flag\\flag_mate_21dmd_co.paa", "exile_assets\\texture\\flag\\flag_mate_spawny_co.paa",
    "exile_assets\\texture\\flag\\flag_mate_secretone_co.paa", "exile_assets\\texture\\flag\\flag_mate_stitchmoonz_co.paa", "exile_assets\\texture\\flag\\flag_mate_commandermalc_co.paa",
    "exile_assets\\texture\\flag\\flag_mate_jankon_co.paa", "\\A3\\Data_F\\Flags\\flag_blue_co.paa", "\\A3\\Data_F\\Flags\\flag_green_co.paa",
    "\\A3\\Data_F\\Flags\\flag_red_co.paa", "\\A3\\Data_F\\Flags\\flag_white_co.paa", "\\A3\\Data_F\\Flags\\flag_uk_co.paa",
    "exile_assets\\texture\\flag\\flag_country_de_co.paa", "exile_assets\\texture\\flag\\flag_country_at_co.paa", "exile_assets\\texture\\flag\\flag_country_sct_co.paa",
    "exile_assets\\texture\\flag\\flag_country_ee_co.paa", "exile_assets\\texture\\flag\\flag_country_cz_co.paa", "exile_assets\\texture\\flag\\flag_country_nl_co.paa",
    "exile_assets\\texture\\flag\\flag_country_hr_co.paa", "exile_assets\\texture\\flag\\flag_country_cn_co.paa", "exile_assets\\texture\\flag\\flag_country_ru_co.paa",
    "exile_assets\\texture\\flag\\flag_country_ir_co.paa", "exile_assets\\texture\\flag\\flag_country_by_co.paa", "exile_assets\\texture\\flag\\flag_country_fi_co.paa",
    "exile_assets\\texture\\flag\\flag_country_fr_co.paa", "exile_assets\\texture\\flag\\flag_country_au_co.paa", "exile_assets\\texture\\flag\\flag_country_be_co.paa",
    "exile_assets\\texture\\flag\\flag_country_se_co.paa", "exile_assets\\texture\\flag\\flag_country_pl_co.paa", "exile_assets\\texture\\flag\\flag_country_pl2_co.paa",
    "exile_assets\\texture\\flag\\flag_country_pt_co.paa", "exile_assets\\texture\\flag\\flag_mate_zanders_streched_co.paa", "exile_assets\\texture\\flag\\flag_misc_brunswik_co.paa",
    "exile_assets\\texture\\flag\\flag_misc_dorset_co.paa", "exile_assets\\texture\\flag\\flag_misc_svarog_co.paa", "exile_assets\\texture\\flag\\flag_misc_exile_co.paa",
    "exile_assets\\texture\\flag\\flag_misc_utcity_co.paa", "exile_assets\\texture\\flag\\flag_misc_dickbutt_co.paa", "exile_assets\\texture\\flag\\flag_misc_rainbow_co.paa",
    "exile_assets\\texture\\flag\\flag_misc_battleye_co.paa", "exile_assets\\texture\\flag\\flag_misc_bss_co.paa", "exile_assets\\texture\\flag\\flag_misc_skippy_co.paa",
    "exile_assets\\texture\\flag\\flag_misc_kiwifern_co.paa", "exile_assets\\texture\\flag\\flag_misc_trololol_co.paa", "exile_assets\\texture\\flag\\flag_misc_dream_cat_co.paa",
    "exile_assets\\texture\\flag\\flag_misc_pirate_co.paa", "exile_assets\\texture\\flag\\flag_misc_pedobear_co.paa", "exile_assets\\texture\\flag\\flag_misc_petoria_co.paa",
    "exile_assets\\texture\\flag\\flag_misc_smashing_co.paa", "exile_assets\\texture\\flag\\flag_misc_lemonparty_co.paa", "exile_assets\\texture\\flag\\flag_misc_rma_co.paa",
    "exile_assets\\texture\\flag\\flag_cp_co.paa", "exile_assets\\texture\\flag\\flag_trouble2_co.paa", "exile_assets\\texture\\flag\\flag_exile_city_co.paa",
    "exile_assets\\texture\\flag\\flag_misc_eraser1_co.paa", "exile_assets\\texture\\flag\\flag_misc_willbeeaten_co.paa", "exile_assets\\texture\\flag\\flag_misc_privateproperty_co.paa",
    "exile_assets\\texture\\flag\\flag_misc_nuclear_co.paa", "exile_assets\\texture\\flag\\flag_misc_lazerkiwi_co.paa", "exile_assets\\texture\\flag\\flag_misc_beardageddon_co.paa",
    "exile_assets\\texture\\flag\\flag_country_dk_co.paa", "exile_assets\\texture\\flag\\flag_country_it_co.paa", "exile_assets\\texture\\flag\\flag_misc_alkohol_co.paa",
    "exile_assets\\texture\\flag\\flag_misc_kickass_co.paa", "exile_assets\\texture\\flag\\flag_misc_knuckles_co.paa", "exile_assets\\texture\\flag\\flag_misc_snake_co.paa",
    "exile_assets\\texture\\flag\\flag_misc_weeb_co.paa"
  ].freeze

  def self.run
    @users = build_users
    players = build_players
    territories = build_territories
    constructions = build_constructions(territories)

    # Converts [["item", "item", "item"], ["item", "item", "item"]] into "(item, item, item), (item, item, item)"
    zip = lambda do |items|
      items.map { |i| i.join(",") }.map { |i| "(#{i.gsub("\"", "\\\"")})" }.join(",")
    end

    # Convert these to something MySQL can understand
    users = zip.call(@users.map(&:values))
    players = zip.call(players.map(&:values))
    territories = zip.call(territories.map(&:values))
    constructions = zip.call(constructions.map(&:values))

    sql = <<~SQL
      DELETE FROM `#{ENV["ESM_MYSQL_DATABASE"]}`.account;
      DELETE FROM `#{ENV["ESM_MYSQL_DATABASE"]}`.player;
      DELETE FROM `#{ENV["ESM_MYSQL_DATABASE"]}`.construction;
      DELETE FROM `#{ENV["ESM_MYSQL_DATABASE"]}`.container;
      DELETE FROM `#{ENV["ESM_MYSQL_DATABASE"]}`.territory;

      INSERT INTO `#{ENV["ESM_MYSQL_DATABASE"]}`.account VALUES #{users};
      INSERT INTO `#{ENV["ESM_MYSQL_DATABASE"]}`.player VALUES #{players};
      INSERT INTO `#{ENV["ESM_MYSQL_DATABASE"]}`.territory VALUES #{territories};
      INSERT INTO `#{ENV["ESM_MYSQL_DATABASE"]}`.construction VALUES #{constructions};
    SQL

    File.open("reset.sql", "w+") { |f| f.write(sql) }

    `"#{ENV["ESM_MYSQL_PATH"]}\\mysql.exe" --host=#{ENV["ESM_MYSQL_HOST"]} --user=#{ENV["ESM_MYSQL_USER"]} --port=#{ENV["ESM_MYSQL_PORT"]} --password=#{ENV["ESM_MYSQL_PASSWORD"]} #{ENV["ESM_MYSQL_DATABASE"]} < reset.sql`
  end

  def self.random_time
    "'#{Faker::Time.between(from: Time.current.beginning_of_year, to: Time.current.end_of_year).strftime("%Y-%m-%d %l:%M:%S")}'"
  end

  def self.build_users
    users = YAML.safe_load(File.read("../test_users.yml"))
    @steam_uids = users.map { |u| u["steam_uid"] }

    users.map do |user|
      {
        uid: "'#{user["steam_uid"]}'",
        clan_id: "NULL",
        name: "'#{user["steam_username"]}'",
        score: Faker::Number.between(from: 10_000, to: 9_000_000),
        kills: Faker::Number.between(from: 0, to: 1_000),
        deaths: Faker::Number.between(from: 0, to: 1_000),
        locker: Faker::Number.between(from: 10_000, to: 9_000_000),
        first_connect_at: random_time,
        last_connect_at: "NOW()",
        last_disconnect_at: random_time,
        total_connections: "'#{Faker::Number.between(from: 0, to: 5_000)}'"
      }
    end
  end

  def self.build_players
    @users.map.with_index do |user, index|
      # Randomly kill someone
      next if rand < 0.1

      {
        id: index + 1,
        name: user[:name],
        account_uid: user[:uid],
        money: Faker::Number.between(from: 10_000, to: 9_000_000),
        damage: Faker::Number.between(from: 0.0, to: 0.9),
        hunger: Faker::Number.between(from: 0, to: 100),
        thirst: Faker::Number.between(from: 0, to: 100),
        alcohol: Faker::Number.between(from: 0, to: 5), # 5 is drunk
        temperature: Faker::Number.between(from: 34, to: 37),
        wetness: Faker::Number.between(from: 0.0, to: 1.0),
        oxygen_remaining: Faker::Number.between(from: 0.4, to: 1.0),
        bleeding_remaining: Faker::Number.between(from: 0.0, to: 1.0),
        hitpoints: "'[[\"face_hub\",0],[\"neck\",0],[\"head\",0],[\"pelvis\",0],[\"spine1\",0],[\"spine2\",0],[\"spine3\",0],[\"body\",0],[\"arms\",0],[\"hands\",0],[\"legs\",0],[\"body\",0]]'",
        direction: 0,
        position_x: 9157, # Tanoa
        position_y: 10005, # Tanoa
        position_z: 0, # Tanoa
        spawned_at: random_time,
        assigned_items: "'[\"ItemMap\",\"ItemCompass\",\"Exile_Item_XM8\",\"ItemRadio\"]'",
        backpack: "'B_Carryall_oli'",
        backpack_items: "'[]'",
        backpack_magazines: "'[]'",
        backpack_weapons: "'[]'",
        current_weapon: "''",
        goggles: "''",
        handgun_items: "'[\"\",\"\",\"\",\"\"]'",
        handgun_weapon: "''",
        headgear: "''",
        binocular: "''",
        loaded_magazines: "'[]'",
        primary_weapon: "''",
        primary_weapon_items: "'[\"\",\"\",\"\",\"\"]'",
        secondary_weapon: "''",
        secondary_weapon_items: "'[\"\",\"\",\"\",\"\"]'",
        uniform: "''",
        uniform_items: "'[]'",
        uniform_magazines: "'[]'",
        uniform_weapons: "'[]'",
        vest: "''",
        vest_items: "'[]'",
        vest_magazines: "'[]'",
        vest_weapons: "'[]'",
        last_updated_at: random_time,
      }
    end.compact
  end

  def self.build_territories
    10.times.map do |index|
      stolen = Faker::Boolean.boolean
      owner_uid = @steam_uids.sample
      build_rights = [owner_uid] + @steam_uids.sample(Faker::Number.between(from: 0, to: @steam_uids.size - 1)).uniq.compact
      moderators = [owner_uid] + build_rights.sample(Faker::Number.between(from: 0, to: @steam_uids.size - 1)).uniq.compact

      {
        id: index + 1,
        custom_id: Faker::Boolean.boolean ? "'#{Faker::Internet.slug}'" : "NULL",
        owner_uid: "'#{owner_uid}'",
        name: "'#{Faker::Company.name.gsub("'", "")}'",
        position_x: Faker::Number.between(from: 0, to: 5_000).to_f,
        position_y: Faker::Number.between(from: 0, to: 5_000).to_f,
        position_z: 0.0,
        radius: Faker::Number.between(from: 0, to: 100).to_f,
        level: Faker::Number.between(from: 0, to: 100),
        flag_texture: "'#{FLAG_TEXTURES.sample.gsub("\\", "\\\\\\\\")}'",
        flag_stolen: "'#{stolen ? 1 : 0}'",
        flag_stolen_by_uid: stolen ? "'#{@steam_uids.sample}'" : "NULL",
        flag_stolen_at: stolen ? random_time : "NULL",
        created_at: random_time,
        last_paid_at: "NOW()",
        xm8_protectionmoney_notified: '0',
        build_rights: "'#{build_rights.to_json}'",
        moderators: "'#{moderators.to_json}'",
        esm_payment_counter: 0,
        deleted_at: "NULL"
      }
    end
  end

  def self.build_constructions(territories)
    territories.map.with_index do |territory, index|
      {
        id: index + 1,
        class: "'Exile_Construction_WoodWall_Static'",
        account_uid: territory[:owner_uid],
        spawned_at: random_time,
        position_x: territory[:position_x],
        position_y: territory[:position_y],
        position_z: territory[:position_z],
        direction_x: 0,
        direction_y: 0,
        direction_z: 0,
        up_x: 0,
        up_y: 0,
        up_z: 0,
        is_locked: false,
        pin_code: "'000000'",
        damage: 0,
        territory_id: territory[:id],
        last_updated_at: "NOW()",
        deleted_at: "NULL"
      }
    end
  end
end
