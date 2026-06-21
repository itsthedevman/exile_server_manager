# frozen_string_literal: true

require "pathname"

#
# Centralized eager-loading for ESM code that lives outside any Zeitwerk root.
#
# Two primitives, one named procedure:
#
#   Loader.file("core", "lib", "esm", "application_record.rb")
#   Loader.dir("core", "lib", "esm", except: ["/command/", "/extensions/"])
#   Loader.load_commands
#
# The first segment names a monorepo component ("core", "service", "website",
# "arma", "root") and resolves through `ESM_*_PATH` env vars exported by the
# flake.nix shellHook. Anything outside that tree should call `require`
# directly.
#
class Loader
  COMPONENT_ENVS = {
    "root" => "ESM_ROOT_PATH",
    "core" => "ESM_CORE_PATH",
    "service" => "ESM_SERVICE_PATH",
    "website" => "ESM_WEBSITE_PATH",
    "arma" => "ESM_ARMA_PATH"
  }.freeze

  class << self
    ##
    # Absolute, symlink-resolved path to a monorepo component. Sourced from
    # the `ESM_*_PATH` env vars and realpath'd at first access so downstream callers,
    # especially Zeitwerk, see consistent paths even when the env var
    # points at symlinks.
    #
    # Memoized. Raises if the env var is unset or the directory doesn't exist.
    #
    # @return [Pathname] frozen
    #
    def root_path = path_for("root")
    def core_path = path_for("core")
    def service_path = path_for("service")
    def website_path = path_for("website")
    def arma_path = path_for("arma")

    ##
    # Loads a single file. `method:` is :require (default) or :load.
    #
    # @example
    #   Loader.file("core", "lib", "esm", "logger.rb")
    #
    def file(component, *segments, method: :require)
      path = resolve(component, segments).to_s

      case method
      when :require
        require path
      when :load
        load path
      else
        raise ArgumentError, "method: must be :require or :load, got #{method.inspect}"
      end
    end

    ##
    # Recursively loads every `.rb` under the given path. Files matching any
    # substring in `except:` are skipped.
    #
    # @example
    #   Loader.dir("core", "lib", "esm",
    #     except: ["/command/", "/extensions/", "/application_record.rb"])
    #
    def dir(component, *segments, method: :require, except: [])
      excludes = Array(except).map(&:to_s)

      Dir[resolve(component, segments).join("**", "*.rb")].sort.each do |path|
        next if excludes.any? { |pattern| path.include?(pattern) }

        case method
        when :require
          require path
        when :load
          load path
        else
          raise ArgumentError, "method: must be :require or :load, got #{method.inspect}"
        end
      end
    end

    ##
    # Loads the command framework in dependency order:
    #
    #   1. Modules mixed into `Command::Base` (must precede Base itself)
    #   2. `ESM::Command` namespace module
    #   3. `Command::Base` parent class
    #   4. `ApplicationCommand` (subclass of Base, parent of every concrete command)
    #   5. Concrete commands under `command/`
    #
    # Extra `except:` patterns are ANDed with the framework-internal exclusions
    # so callers can suppress specific commands without re-stating the base
    # framework excludes.
    #
    def load_commands(method: :require, except: [])
      dir("core", "lib", "esm", "command", "base", method: method)

      file("core", "lib", "esm", "command.rb", method: method)
      file("core", "lib", "esm", "command", "base.rb", method: method)
      file("core", "lib", "esm", "application_command.rb", method: method)

      dir("core", "lib", "esm", "command",
        method: method,
        except: ["/command/base.rb", "/command/base/", *Array(except)])
    end

    # TODO: Docs
    def load_rails_extensions(method: :require)
      dir("core", "lib", "types", method:)

      ActiveSupport::Inflector.inflections(:en) do |inflect|
        inflect.acronym("ESM")
        inflect.acronym("ID")
        inflect.acronym("UID")
      end

      ActiveRecord::Type.register(:hash, HashType)
    end

    private

    def resolve(component, segments)
      path_for(component).join(*segments.map(&:to_s))
    end

    def path_for(component)
      @paths ||= {}

      @paths[component] ||= begin
        env_var = COMPONENT_ENVS.fetch(component) do
          raise ArgumentError,
            "unknown component #{component.inspect}; expected one of #{COMPONENT_ENVS.keys.inspect}"
        end

        Pathname.new(ENV.fetch(env_var)).realpath.freeze
      end
    end
  end
end
