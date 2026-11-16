# frozen_string_literal: true

require "lutaml/model"

module Openmath
  # The root of every OpenMath element class hierarchy. Version-scoped
  # subclasses (e.g. Openmath::V2::CommonElements) declare the child object
  # collections and their element maps for their version's grammar.
  class CommonElements < Lutaml::Model::Serializable
  end
end
