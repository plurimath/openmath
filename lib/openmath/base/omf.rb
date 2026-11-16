# frozen_string_literal: true

module Openmath
  module Base
    # An IEEE floating-point literal: <OMF dec="0.5"/> or
    # <OMF hex="4008000000000000"/> (schema: exactly one of dec or hex).
    module Omf
      def self.included(klass)
        klass.class_eval do
          include Openmath::Base::Common

          attribute :dec, :string
          attribute :hex, :string

          xml do
            element "OMF"
            map_attribute "dec", to: :dec
            map_attribute "hex", to: :hex
          end
        end
      end
    end
  end
end
