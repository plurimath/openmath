# frozen_string_literal: true

module Openmath
  module Base
    # The OpenMath object root:
    # <OMOBJ cdbase="..." version="2.0"> ... </OMOBJ>
    # (schema: compound attributes, optional version, one object element).
    module Omobj
      def self.included(klass)
        klass.class_eval do
          include Openmath::Base::Compound

          attribute :version, :string

          xml do
            element "OMOBJ"
            ordered
            map_attribute "version", to: :version
          end

          def to_xml(**options, &block)
            result = super(**options, &block)
            return result unless Openmath::Foreign.contained?(self)

            Openmath::Foreign.inject_tree(self, result)
          end
        end
      end
    end
  end
end
