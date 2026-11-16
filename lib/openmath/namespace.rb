# frozen_string_literal: true

require "lutaml/model"

module Openmath
  # The OpenMath XML namespace: http://www.openmath.org/OpenMath.
  # Documents may use it unprefixed (the default form) or with a prefix
  # such as om:.
  class Namespace < Lutaml::Xml::Namespace
    uri "http://www.openmath.org/OpenMath"
    prefix_default "om"
  end
end
