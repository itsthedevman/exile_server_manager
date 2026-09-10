# frozen_string_literal: true

module ESM
  module Arma
    ##
    # Rebuilds the data behind ClassLookup by asking a running server what it actually has.
    #
    # Walks three config roots through ESMs_command_sqf and writes one YAML file per mod. The SQF
    # reports flat rows and every bit of grouping happens here, because SQF is poor at building
    # nested structures and this is not.
    #
    # Output goes somewhere other than core/config/arma_classes on purpose. The first thing worth
    # doing with a generated file is diffing it against the committed one: a3 and exile are the only
    # baseline available, so reproducing them is what earns the categories any trust for the mods
    # there is nothing to check against.
    #
    # @example
    #   ESM::Arma::ClassDump.new("esm_malden").call
    #
    class ClassDump
      SECTIONS = %w[CfgWeapons CfgMagazines CfgVehicles CfgGlasses].freeze

      # How long to wait for the server to come up before giving up on it
      CONNECTION_TIMEOUT = 60

      # What a real mod's `configSourceMod` looks like. Base game content answers with a DLC name
      # instead ("mark", "enoch", "orange"), or with nothing at all, and none of those carry it.
      MOD_PREFIX = "@"

      VANILLA = ["a3", "Arma 3"].freeze

      ##
      # Which yml file a mod's classes belong in, keyed by what `configSourceMod` reports.
      #
      # Only the mods that ship as more than one directory need naming here, since those have always
      # been treated as a single entry. A mod not named gets a file of its own, so a new one shows up
      # rather than being silently folded into something else.
      #
      MOD_FILES = {
        "@exile" => ["exile", "Exile Mod"],
        "@exileserver" => ["exile", "Exile Mod"],
        "@CUP_Weapons" => ["cup", "Community Update Project (CUP)"],
        "@CUP_Vehicles" => ["cup", "Community Update Project (CUP)"],
        "@CUP_Units" => ["cup", "Community Update Project (CUP)"],
        "@CUP_Terrains" => ["cup", "Community Update Project (CUP)"],
        "@RHSUSAF" => ["rhs", "RHS"],
        "@RHSAFRF" => ["rhs", "RHS"],
        "@RHSGREF" => ["rhs", "RHS"],
        "@RHSSAF" => ["rhs", "RHS"],
        "@NIArms" => ["ni_arms", "NIArms"],
        "@Extended_Base_Mod" => ["extended_base_mod", "Extended Base Mod"]
      }.freeze

      ##
      # @param server_id [String] the ESM server to ask
      # @param output_dir [Pathname, String, nil] where the files land, defaulting to service/tmp
      #
      def initialize(server_id, output_dir = nil)
        @server_id = server_id
        @output_dir = Pathname.new(output_dir || ESM.root.join("tmp", "arma_classes"))
        @rows = []
      end

      ##
      # Runs the dump end to end.
      #
      # @return [Array<Pathname>] the files written
      #
      def call
        server = await_connection

        SECTIONS.each do |section|
          info("walking #{section}")
          @rows.concat(dump(server, section))
        end

        info("collected #{@rows.size} classes")

        write_files(group_rows)
      end

      private

      def await_connection
        server = ESM::Server.find_by(server_id: @server_id)
        raise "No server configured with server_id #{@server_id.inspect}" if server.nil?

        return server if server.connected?

        info("waiting for #{@server_id} to connect")

        deadline = Time.current + CONNECTION_TIMEOUT
        sleep(1) until server.connected? || Time.current > deadline

        raise "#{@server_id} never connected" unless server.connected?

        server
      end

      ##
      # One config root's worth of rows.
      #
      # The section is prepended as an assignment rather than passed as an argument: the payload is a
      # code string either way, so a local is the whole of the calling convention.
      #
      # @param server [ESM::Server]
      # @param section [String] a config root name
      #
      # @return [Array<Array>] rows of [class_name, display_name, source_mod, category]
      #
      def dump(server, section)
        result = server.execute_sqf!("private _section = #{section.inspect};\n#{script}")

        return result if result.is_a?(Array)

        warn("#{section} came back as #{result.class}: #{result.to_s.truncate(200)}")
        []
      end

      def script
        @script ||= ESM.root.join("..", "arma", "tools", "class_dump", "dump_classes.sqf").read
      end

      ##
      # The rows folded into the shape the YAML files are written in.
      #
      # A class already claimed is left alone rather than overwritten, matching ClassLookup's own
      # rule that the first file to name a class owns it.
      #
      # @return [Hash] file key => {name:, categories: {category => {class_name => display_name}}}
      #
      def group_rows
        seen = Set.new

        @rows.each_with_object({}) do |(class_name, display_name, source_mod, category), files|
          next unless seen.add?(class_name)

          key, mod_name = file_for(source_mod)

          settled = settled_category(class_name, category)

          file = files[key] ||= {name: mod_name, categories: {}}
          file[:categories][settled] ||= {}
          file[:categories][settled][class_name] = display_name
        end
      end

      ##
      # Where a class is filed, preferring wherever it is filed already.
      #
      # Some of these categories are not in the configs to be read. Exile's items all report the same
      # thing whether they are bandages, sandwiches or safe kits, because the split between them is
      # one Exile only makes by hand. Sorting those out again from scratch on every refresh would
      # mean losing the sorting every time, so a class that already has a home keeps it and the
      # server's answer is only used for classes nobody has filed yet.
      #
      # @param class_name [String]
      # @param reported [String] the category the server suggested
      #
      # @return [String]
      #
      def settled_category(class_name, reported)
        ESM::Arma::ClassLookup.find(class_name)&.category || reported
      end

      ##
      # The file a class belongs in, and the mod name written at the top of it.
      #
      # @param source_mod [String] whatever `configSourceMod` reported
      #
      # @return [Array<String>] the yml key and the mod's display name
      #
      def file_for(source_mod)
        return VANILLA unless source_mod.start_with?(MOD_PREFIX)

        MOD_FILES[source_mod] || [source_mod.delete_prefix(MOD_PREFIX).underscore, source_mod.delete_prefix(MOD_PREFIX)]
      end

      ##
      # Category display names, harvested from the files already on disk.
      #
      # Reusing them rather than inventing new ones is what keeps a regenerated file diffable against
      # the one it replaces. A category no file has used yet falls back to titleizing its key.
      #
      # @return [Hash] category key => display name
      #
      def category_names
        @category_names ||= ESM::Arma::ClassLookup.all.values.each_with_object({}) do |entry, names|
          names[entry.category] ||= entry.category_name
        end
      end

      def write_files(files)
        @output_dir.mkpath

        files.map do |key, file|
          path = @output_dir.join("#{key}.yml")
          path.write(render(key, file))

          count = file[:categories].sum { |_category, entries| entries.size }
          info("wrote #{path} (#{count} classes across #{file[:categories].size} categories)")

          path
        end
      end

      ##
      # One file's YAML, written by hand rather than through to_yaml.
      #
      # The committed files quote every name and entry, and a regenerated file that formats
      # differently is a diff made entirely of noise. Matching the existing shape is what makes the
      # baseline comparison readable.
      #
      def render(key, file)
        lines = ["#{key}:", "  name: #{quote(file[:name])}", "  categories:"]

        file[:categories].sort.each do |category, entries|
          lines << "    #{category}:"
          lines << "      name: #{quote(category_names[category] || category.titleize)}"
          lines << "      entries:"

          entries.sort.each { |class_name, display_name| lines << "        #{class_name}: #{quote(display_name)}" }
        end

        "#{lines.join("\n")}\n"
      end

      # Arma writes a non-breaking space between a calibre and its unit, which reads identically and
      # matches nothing: a search for "5.56 mm" misses "5.56 mm" every time. The committed files
      # already hold the plain space, so this keeps them that way.
      NON_BREAKING_SPACE = " "

      def quote(text)
        text = text.gsub(NON_BREAKING_SPACE, " ").gsub("\\", "\\\\\\\\").gsub("\"", "\\\"")

        "\"#{text}\""
      end

      def info(message)
        puts "[class_dump] #{message}"
      end

      def warn(message)
        puts "[class_dump] WARN #{message}"
      end
    end
  end
end
