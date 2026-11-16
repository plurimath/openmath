# frozen_string_literal: true

require "lutaml/model"

module Openmath
  autoload :VERSION, "openmath/version"
  autoload :CommonElements, "openmath/common_elements"
  autoload :Namespace, "openmath/namespace"
  autoload :V2, "openmath/v2"
  autoload :V3, "openmath/v3"
  autoload :Validation, "openmath/validation"

  module CD
    autoload :Namespace, "openmath/cd/namespace"
    autoload :Configuration, "openmath/cd/configuration"
    autoload :Fmp, "openmath/cd/fmp"
    autoload :Example, "openmath/cd/example"
    autoload :Definition, "openmath/cd/definition"
    autoload :Document, "openmath/cd/document"
    autoload :Collection, "openmath/cd/collection"
    autoload :Validation, "openmath/cd/validation"
  end

  module Base
    autoload :Oms, "openmath/base/oms"
    autoload :Omv, "openmath/base/omv"
    autoload :Omi, "openmath/base/omi"
    autoload :Omf, "openmath/base/omf"
    autoload :Oma, "openmath/base/oma"
    autoload :Ombind, "openmath/base/ombind"
    autoload :Omb, "openmath/base/omb"
    autoload :Omstr, "openmath/base/omstr"
    autoload :Ombvar, "openmath/base/ombvar"
    autoload :Ome, "openmath/base/ome"
    autoload :Omattr, "openmath/base/omattr"
    autoload :Omatp, "openmath/base/omatp"
    autoload :Omr, "openmath/base/omr"
    autoload :Omforeign, "openmath/base/omforeign"
    autoload :Common, "openmath/base/common"
    autoload :Compound, "openmath/base/compound"
    autoload :Omobj, "openmath/base/omobj"
  end

  # Parses an OpenMath XML document into the typed model of the requested
  # version. OpenMath 2 is the published standard; OpenMath 3 arrives with
  # its own versioned hierarchy (plurimath/plurimath#582).
  def parse(input, version: 2)
    case version
    when 2 then V2.parse(input)
    when 3 then V3.parse(input)
    else raise ArgumentError, "unsupported OpenMath version #{version.inspect}"
    end
  end

  # Validates the document against the version's schema and raises
  # Openmath::Validation::ValidationError on any violation.
  def validate!(xml, version: 2)
    Validation.validate!(xml, version: version)
  end

  def valid?(xml, version: 2)
    Validation.valid?(xml, version: version)
  end

  # Parses a CD document into Openmath::CD::Document.
  def parse_cd(input)
    CD::Configuration.register_models!
    CD::Document.from_xml(input)
  end

  module_function :parse, :validate!, :valid?, :parse_cd
end
