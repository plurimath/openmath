# frozen_string_literal: true

module Openmath
  module Base
    # An application: <OMA><OMS cd="arith1" name="plus"/> ...args</OMA>
    # (schema: compound attributes, omel+; the first child is the operator).
    module Oma
      def self.included(klass)
        klass.class_eval do
          include Openmath::Base::Compound

          xml do
            element "OMA"
            ordered
          end
        end
      end
    end
  end
end
