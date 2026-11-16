# frozen_string_literal: true

require "yaml"

module Openmath
  module Evaluation
    # Content-dictionary bindings discovered from descriptor-owned fragments.
    # The evaluator dispatches only on symbols this data binds. The legacy
    # single-file loader and checksum remain available for compatibility.
    class BindingTable
      SCHEMA = "openmath-binding-table/1"
      DATA_PATH = File.expand_path("../../../data/binding-table-1.yml", __dir__)

      DEFAULT_CDBASE = "http://www.openmath.org/cd"

      Binding = Struct.new(:cd, :name, :operation, :cdbase, :signature) do
        def key
          "#{cd}/#{name}"
        end
      end

      attr_reader :version, :bindings

      def initialize(bindings, version:)
        @version = version
        @bindings = bindings
        @by_key = {}
        bindings.each do |binding|
          key = [binding.cdbase || DEFAULT_CDBASE, binding.cd, binding.name]
          raise BindingArtifactError, "duplicate binding #{key.join('#')}" if @by_key.key?(key)
          @by_key[key] = binding
        end
      end

      # Loads the shipped table.
      def self.default
        load_fragments(Openmath::Extensions.registry.binding_paths)
      end

      # Loads a table file, checking the schema declaration.
      def self.load_file(path)
        doc = YAML.safe_load_file(path, aliases: false)
        raise Error, "#{path}: schema is not #{SCHEMA}" unless doc["schema"] == SCHEMA

        bindings = doc.fetch("bindings").map do |entry|
          Binding.new(entry.fetch("cd"), entry.fetch("name"), entry.fetch("operation").to_sym)
        end
        new(bindings, version: doc.fetch("version"))
      rescue Psych::Exception, KeyError, SystemCallError => e
        raise BindingArtifactError, "#{path}: #{e.message}"
      end

      # Each fragment owns its signature links; duplicate symbol keys across
      # fragments refuse rather than silently overwriting another feature.
      def self.load_fragments(paths)
        schema_path = File.expand_path("../../../data/binding-schema.json", __dir__)
        schema = Extensions::Schema.load(schema_path)
        bindings = paths.flat_map do |path|
          doc = Extensions::Schema.validate(Extensions::Schema.yaml(path), schema, path)
          doc.fetch("bindings").map do |entry|
            signature = doc.fetch("signatures")[entry.fetch("signature")]
            unless signature && signature.fetch("operation") == entry.fetch("operation")
              raise BindingArtifactError, "#{path}: rejected signature #{entry['signature']} for #{entry['cdbase']}##{entry['cd']}##{entry['name']}"
            end
            Binding.new(entry.fetch("cd"), entry.fetch("name"), entry.fetch("operation").to_sym,
                        entry.fetch("cdbase"), entry.fetch("signature"))
          end
        end
        new(bindings, version: 1)
      rescue Psych::Exception, Extensions::DescriptorError, SystemCallError => e
        raise BindingArtifactError, e.message
      end

      # The binding for a symbol, or nil when unbound.
      def lookup(cd, name, cdbase: DEFAULT_CDBASE)
        @by_key[[cdbase, cd, name]]
      end

      # Checksum of the legacy single-file artifact (compatibility API).
      def self.default_checksum
        require "digest"
        Digest::SHA256.hexdigest(File.read(DATA_PATH))
      end
    end
  end
end
