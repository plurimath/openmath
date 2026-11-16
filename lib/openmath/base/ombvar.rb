# frozen_string_literal: true

module Openmath
  module Base
    # The binding-variable container: <OMBVAR><OMV .../>...</OMBVAR>
    # (schema: common attributes, omvar+ where omvar = OMV | attributed OMV).
    module Ombvar
      def self.included(klass)
        klass.class_eval do
          include Openmath::Base::Common

          xml do
            element "OMBVAR"
            ordered
          end
        end
      end
    end
  end
end
