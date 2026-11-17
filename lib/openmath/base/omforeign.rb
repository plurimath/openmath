# frozen_string_literal: true

module Openmath
  module Base
    # A foreign object: <OMFOREIGN encoding="...">...</OMFOREIGN>
    # (schema: compound attributes, optional encoding, then OpenMath
    # children and foreign markup). Foreign markup (any element outside
    # the OpenMath namespace) is captured verbatim by
    # Openmath::Foreign.capture at parse time into +notom_value+ and
    # re-emitted by the serialization override below. The interleaving
    # position of foreign fragments relative to OpenMath children is
    # normalized to OpenMath-children-first on re-serialization; the
    # fragments themselves round-trip byte-identically.
    module Omforeign
      def self.included(klass)
        klass.class_eval do
          include Openmath::Base::Compound

          attribute :foreign_encoding, :string
          attribute :notom_value, :string, collection: true
          attribute :notom_positions, :integer, collection: true

          xml do
            element "OMFOREIGN"
            ordered
            map_attribute "encoding", to: :foreign_encoding
          end

          def to_xml(**options, &block)
            result = super(**options, &block)
            fragments = Array(notom_value)
            return result if fragments.empty?

            Openmath::Foreign.inject(result, fragments)
          end
        end
      end
    end
  end
end
