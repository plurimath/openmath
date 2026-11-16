# frozen_string_literal: true

require "lutaml/model"

module Openmath
  module CD
    # The Content Dictionary XML namespace.
    class Namespace < Lutaml::Xml::Namespace
      uri "http://www.openmath.org/OpenMathCD"
      prefix_default "cd"
    end

    # The CDGroup XML namespace (omcdgroup2.rnc).
    class GroupNamespace < Lutaml::Xml::Namespace
      uri "http://www.openmath.org/OpenMathCDG"
      prefix_default "cdg"
    end
  end
end
