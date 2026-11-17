# frozen_string_literal: true

require "lutaml/model"

module Openmath
  # Content dictionaries: the CD XML documents (namespace
  # http://www.openmath.org/OpenMathCD), their loading as data, and symbol
  # resolution. Modeled from schemas/omcd2.rng (the OpenMath 2 CD schema).
  module CD
    autoload :Namespace, "openmath/cd/namespace"
    autoload :GroupNamespace, "openmath/cd/namespace"
    autoload :CdsNamespace, "openmath/cd/cds_namespace"
    autoload :Configuration, "openmath/cd/configuration"
    autoload :Fmp, "openmath/cd/fmp"
    autoload :Example, "openmath/cd/example"
    autoload :Definition, "openmath/cd/definition"
    autoload :Document, "openmath/cd/document"
    autoload :Collection, "openmath/cd/collection"
    autoload :Validation, "openmath/cd/validation"
    autoload :GroupMember, "openmath/cd/group_document"
    autoload :GroupDocument, "openmath/cd/group_document"
    autoload :GroupCollection, "openmath/cd/group_collection"
    autoload :Group, "openmath/cd/group_collection"
    autoload :Signature, "openmath/cd/signature_document"
    autoload :SignatureDocument, "openmath/cd/signature_document"
    autoload :SignatureCollection, "openmath/cd/signatures"
    autoload :Signatures, "openmath/cd/signatures"

    module_function

    # Parses a CD document into Openmath::CD::Document.
    def parse(input)
      Configuration.register_models!
      Document.from_xml(input, register: Configuration::CONTEXT_ID)
    end
  end
end
