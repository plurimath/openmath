# frozen_string_literal: true

require "lutaml/model"

module Openmath
  module CD
    # The CD signatures XML namespace (omcdsig2.rnc).
    class CdsNamespace < Lutaml::Xml::Namespace
      uri "http://www.openmath.org/OpenMathCDS"
      prefix_default "cds"
    end
  end
end
