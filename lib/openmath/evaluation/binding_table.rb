# frozen_string_literal: true

require "yaml"

module Openmath
  module Evaluation
    # The CD binding table: the checksummed data artifact
    # (data/binding-table-1.yml) declaring which content-dictionary symbols
    # evaluate and which operation each binds to. The evaluator dispatches
    # on nothing this table does not bind.
    class BindingTable
      SCHEMA = "openmath-binding-table/1"
      DATA_PATH = File.expand_path("../../../data/binding-table-1.yml", __dir__)

      Binding = Struct.new(:cd, :name, :operation) do
        def key
          "#{cd}/#{name}"
        end
      end

      attr_reader :version, :bindings

      def initialize(bindings, version:)
        @version = version
        @bindings = bindings
        @by_key = bindings.to_h { |b| [b.key, b] }
      end

      # Loads the shipped table.
      def self.default
        load_file(DATA_PATH)
      end

      # Loads a table file, checking the schema declaration.
      def self.load_file(path)
        doc = YAML.safe_load_file(path, aliases: false)
        raise Error, "#{path}: schema is not #{SCHEMA}" unless doc["schema"] == SCHEMA

        bindings = doc.fetch("bindings").map do |entry|
          Binding.new(entry.fetch("cd"), entry.fetch("name"), entry.fetch("operation").to_sym)
        end
        new(bindings, version: doc.fetch("version"))
      end

      # The binding for a symbol, or nil when unbound.
      def lookup(cd, name)
        @by_key["#{cd}/#{name}"]
      end

      # The sha256 of the shipped table — the artifact's identity, pinned by
      # the specs.
      def self.default_checksum
        require "digest"
        Digest::SHA256.hexdigest(File.read(DATA_PATH))
      end
    end
  end
end
