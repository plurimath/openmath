# frozen_string_literal: true

module Openmath
  module Base
    # A binding: <OMBIND><head/> <OMBVAR>...</OMBVAR> <body/></OMBIND>
    # (schema: compound attributes, omel, OMBVAR, omel — head, binder, body).
    module Ombind
      def self.included(klass)
        klass.class_eval do
          include Openmath::Base::Compound

          xml do
            element "OMBIND"
            ordered
          end
        end
      end
    end
  end
end
