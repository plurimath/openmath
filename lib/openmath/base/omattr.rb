# frozen_string_literal: true

module Openmath
  module Base
    # An attributed object: <OMATTR><OMATP>...</OMATP> <object/></OMATTR>
    # (schema: compound attributes, OMATP, omel).
    module Omattr
      def self.included(klass)
        klass.class_eval do
          include Openmath::Base::Compound

          xml do
            element "OMATTR"
            ordered
          end
        end
      end
    end
  end
end
