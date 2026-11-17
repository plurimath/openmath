# frozen_string_literal: true

require "lutaml/model"

module Openmath
  autoload :VERSION, "openmath/version"
  autoload :CommonElements, "openmath/common_elements"
  autoload :Namespace, "openmath/namespace"
  autoload :V2, "openmath/v2"
  autoload :V3, "openmath/v3"
  autoload :Validation, "openmath/validation"
  autoload :Evaluation, "openmath/evaluation"
  autoload :Foreign, "openmath/foreign"
  autoload :Canonical, "openmath/canonical"
  autoload :Binary, "openmath/binary"
  autoload :ContentMathML, "openmath/content_mathml"
  autoload :ContentMathMLOperators, "openmath/content_mathml_operators"
  autoload :Tagged, "openmath/tagged"
  autoload :CD, "openmath/cd"

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
    CD.parse(input)
  end

  # Parses a CDGroup document into Openmath::CD::GroupDocument.
  def parse_cdgroup(input)
    CD::Group.parse(input)
  end

  def validate_cdgroup!(xml)
    CD::Group.validate!(xml)
  end

  # Evaluates an OpenMath object (or XML text) under the variable bindings.
  # When STS signatures are supplied, applications check against their
  # operator's signature and violations refuse typed.
  def evaluate(object, variables: {}, table: nil, version: nil, signatures: nil)
    args = { variables: variables, version: version, signatures: signatures }.compact
    args[:table] = table if table
    Evaluation.evaluate(object, **args)
  end

  # Deterministic Monte-Carlo evaluation over uncertainty-carrying
  # objects: every pmquant quantity draws from its category's documented
  # distribution under the seeded generator; the result carries the
  # generator, seed, sample count, samples, mean and standard deviation,
  # so the same seed reproduces the same run.
  def evaluate_stochastic(object, samples:, seed:, generator: "mt19937",
                          variables: {}, table: nil, version: nil)
    args = { variables: variables, version: version }.compact
    args[:table] = table if table
    Evaluation::Stochastic.evaluate(object, samples: samples, seed: seed,
                                    generator: generator, **args)
  end

  # Canonical equality: two objects are canonically equal when their
  # canonical serializations hash identically (see Openmath::Canonical).
  def canonical_equal?(left, right)
    Canonical.equal?(left, right)
  end

  module_function :parse, :validate!, :valid?, :parse_cd, :canonical_equal?,
                  :parse_cdgroup, :validate_cdgroup!, :evaluate,
                  :evaluate_stochastic
end
