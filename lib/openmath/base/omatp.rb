# frozen_string_literal: true

module Openmath
  module Base
    # An attribute-pair list: <OMATP><OMS .../> <value/> ...</OMATP>
    # (schema: compound attributes, (OMS, value)+ — the pairs alternate, and
    # the document order is the pairing).
    module Omatp
      def self.included(klass)
        klass.class_eval do
          include Openmath::Base::Compound

          xml do
            element "OMATP"
            ordered
          end
        end
      end
    end
  end
end
