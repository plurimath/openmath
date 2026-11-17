# frozen_string_literal: true

module Openmath
  module CD
    # Loaded signature documents, indexed by (cd, symbol): the STS layer
    # the application checker consults. Signatures load from XML text or
    # .sts file paths.
    class SignatureCollection
      attr_reader :documents

      def initialize
        @documents = []
        @by_cd = {}
      end

      # Loads a signature document (XML text or a .sts file path).
      # Returns self for chaining.
      def load(source)
        Configuration.register_models!
        xml = source.match?(/\A</) ? source : File.read(source)
        document = SignatureDocument.from_xml(
          xml, register: Configuration::CONTEXT_ID
        )
        add_document(document)
        self
      end

      def add_document(document)
        @documents << document
        @by_cd[document.cd] = document
        self
      end

      # The STS type object for a symbol, or nil when unsigned.
      def lookup(cd, name)
        document = @by_cd[cd]
        return nil unless document

        document.signature_value.find { |signature| signature.name == name }
          &.object
      end

      def size
        @documents.size
      end
    end

    # The signature-level API.
    module Signatures
      module_function

      def load(*sources)
        collection = SignatureCollection.new
        sources.each { |source| collection.load(source) }
        collection
      end

      def parse(source)
        SignatureCollection.new.load(source)
      end
    end
  end
end
