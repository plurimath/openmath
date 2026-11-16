# frozen_string_literal: true

require "lutaml/model"

module Openmath
  # Content dictionaries: the CD XML documents (namespace
  # http://www.openmath.org/OpenMathCD), their loading as data, and symbol
  # resolution. Modeled from schemas/omcd2.rng (the OpenMath 2 CD schema).
  module CD
    autoload :Namespace, "openmath/cd/namespace"
    autoload :Configuration, "openmath/cd/configuration"
    autoload :Fmp, "openmath/cd/fmp"
    autoload :Example, "openmath/cd/example"
    autoload :Definition, "openmath/cd/definition"
    autoload :Document, "openmath/cd/document"
    autoload :Collection, "openmath/cd/collection"
    autoload :Validation, "openmath/cd/validation"

    module_function

    # Parses a CD document into Openmath::CD::Document.
    def parse(input)
      Configuration.register_models!
      Document.from_xml(input, register: Configuration::CONTEXT_ID)
    end
  end
end
