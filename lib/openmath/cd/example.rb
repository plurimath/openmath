# frozen_string_literal: true

module Openmath
  module CD
    # A CD example: <Example><OMOBJ ...>...</OMOBJ></Example>. The worked
    # object is an OpenMath object; plain-text examples are held in the
    # same value as text.
    class Example < Openmath::CommonElements
      def self.lutaml_default_register
        Configuration::CONTEXT_ID
      end

      attribute :omobj_value, :omobj, collection: true

      xml do
        namespace Openmath::CD::Namespace
        element "Example"
        map_element "OMOBJ", to: :omobj_value
      end
    end
  end
end
