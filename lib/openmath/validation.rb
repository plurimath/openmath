# frozen_string_literal: true

require "leptris"

module Openmath
  module Validation
    # A schema violation: the message plus the node path it occurred at.
    Error = Struct.new(:message, :path) do
      alias to_s message
    end

    class ValidationError < StandardError
      attr_reader :errors

      def initialize(errors)
        @errors = errors
        super(errors.map(&:message).join("; "))
      end
    end

    SCHEMA_FILES = {
      2 => "openmath2.rng",
      3 => "openmath3.rng",
    }.freeze

    module_function

    # The vendored RelaxNG schema for the version, parsed once per process.
    def schema(version)
      file = SCHEMA_FILES.fetch(version) do
        raise ArgumentError, "unsupported OpenMath version #{version.inspect}"
      end
      @schemas ||= {}
      @schemas[version] ||= Leptris::XML::RelaxNG.parse_file(
        File.expand_path("../../schemas/#{file}", __dir__),
      )
    end

    # Validates the document against the version's schema. Returns the list
    # of Error objects; empty when the document is valid.
    def validate(xml, version: 2)
      document = Leptris::XML.parse(xml, strict: true)
      schema(version).validate(document).map do |e|
        Error.new(e, nil)
      end
    rescue Leptris::XML::ParseError
      raise ValidationError, [Error.new("malformed XML", "/")]
    end

    # Validates and raises ValidationError carrying every violation.
    def validate!(xml, version: 2)
      errors = validate(xml, version: version)
      raise ValidationError, errors unless errors.empty?

      true
    end

    def valid?(xml, version: 2)
      validate(xml, version: version).empty?
    end
  end
end
