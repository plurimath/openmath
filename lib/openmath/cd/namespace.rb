# frozen_string_literal: true

require "lutaml/model"

module Openmath
  module CD
    # The Content Dictionary XML namespace.
    class Namespace < Lutaml::Xml::Namespace
      uri "http://www.openmath.org/OpenMathCD"
      prefix_default "cd"
    end
  end
end
