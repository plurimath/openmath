# frozen_string_literal: true

require "leptris"

module Openmath
  module CD
    # A loaded set of content dictionaries, indexed by CDName for symbol
    # resolution. Load a single document, a file, or a directory of .ocd
    # files.
    class Collection
      attr_reader :documents

      def initialize
        @documents = []
        @by_name = {}
      end

      # Loads a CD document (XML text), a .ocd file path, or a directory of
      # .ocd files. Returns self for chaining.
      def load(source)
        Configuration.register_models!
        if source.match?(/\A</)
          add_xml(source)
        elsif File.directory?(source)
          Dir[File.join(source, "*.ocd")].sort.each do |path|
            add_xml(File.read(path))
          end
        elsif File.exist?(source)
          add_xml(File.read(source))
        else
          add_xml(source)
        end
        self
      end

      def add_xml(xml)
        add_document(Document.from_xml(xml, register: Configuration::CONTEXT_ID))
      end

      def add_document(document)
        @documents << document
        @by_name[document.cd_name] = document
        self
      end

      # The dictionary for a CD name, or nil.
      def [](name)
        @by_name[name]
      end

      def size
        @documents.size
      end

      # Resolves a symbol reference to its CDDefinition: the CD by name, the
      # definition by symbol name. When a cdbase is given, the loaded
      # dictionary's own cdbase must match (OpenMath 2, §cdbase).
      # Returns nil when the symbol is not in the collection — callers
      # refuse unbound symbols; this class never guesses.
      def resolve(cd:, name:, cdbase: nil)
        document = @by_name[cd]
        return nil unless document
        return nil if cdbase && document.cd_base && document.cd_base != cdbase

        document.definition_for(name)
      end

      # Validates a CD document against the vendored omcd2.rng. Returns the
      # list of Openmath::Validation::Error objects; empty when valid.
      def self.validate(xml)
        @schema ||= Leptris::XML::RelaxNG.parse_file(
          File.expand_path("../../../schemas/omcd2.rng", __dir__),
        )
        begin
          document = Leptris::XML.parse(xml, strict: true)
        rescue Leptris::XML::ParseError
          raise Openmath::Validation::ValidationError,
                [Openmath::Validation::Error.new("malformed XML", "/")]
        end

        @schema.validate(document).map do |e|
          Openmath::Validation::Error.new(e, nil)
        end
      end

      # Validates and raises ValidationError on any violation.
      def self.validate!(xml)
        errors = validate(xml)
        raise Openmath::Validation::ValidationError, errors unless errors.empty?

        true
      end
    end
  end
end
