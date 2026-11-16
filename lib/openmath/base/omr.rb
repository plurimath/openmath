# frozen_string_literal: true

module Openmath
  module Base
    # A reference: <OMR href="#id"/> (schema: common attributes + href
    # anyURI).
    module Omr
      def self.included(klass)
        klass.class_eval do
          include Openmath::Base::Common

          attribute :href, :string

          xml do
            element "OMR"
            map_attribute "href", to: :href
          end
        end
      end
    end
  end
end
