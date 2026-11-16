# frozen_string_literal: true

module Openmath
  module CD
    # A symbol definition: <CDDefinition> with Name, optional Role,
    # Description, and any number of CMPs (commented properties, text),
    # FMPs (formal properties, OpenMath objects) and Examples.
    class Definition < Openmath::CommonElements
      def self.lutaml_default_register
        Configuration::CONTEXT_ID
      end

      attribute :name, :string
      attribute :role, :string
      attribute :description, :string, collection: true
      attribute :cmp_value, :string, collection: true
      attribute :fmp_value, Fmp, collection: true
      attribute :example_value, Example, collection: true

      xml do
        namespace Openmath::CD::Namespace
        element "CDDefinition"
        map_element "Name", to: :name
        map_element "Role", to: :role
        map_element "Description", to: :description
        map_element "CMP", to: :cmp_value
        map_element "FMP", to: :fmp_value
        map_element "Example", to: :example_value
      end

      # The formal properties' OpenMath objects, in document order.
      def fmp_objects
        fmp_value.flat_map(&:omobj_value)
      end

      # The worked objects, in document order.
      def example_objects
        example_value.flat_map(&:omobj_value)
      end
    end
  end
end
