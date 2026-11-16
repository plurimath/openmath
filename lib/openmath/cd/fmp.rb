# frozen_string_literal: true

module Openmath
  module CD
    # A formal mathematical property: <FMP><OMOBJ ...>...</OMOBJ></FMP>.
    # The property statement is an OpenMath object.
    class Fmp < Openmath::CommonElements
      def self.lutaml_default_register
        Configuration::CONTEXT_ID
      end

      attribute :omobj_value, :omobj, collection: true

      xml do
        namespace Openmath::CD::Namespace
        element "FMP"
        map_element "OMOBJ", to: :omobj_value
      end
    end
  end
end
