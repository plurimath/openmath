# frozen_string_literal: true

module Openmath
  module Base
    # A variable: <OMV name="x"/> (schema: required name NCName, id).
    module Omv
      def self.included(klass)
        klass.class_eval do
          include Openmath::Base::Common

          attribute :name, :string

          xml do
            element "OMV"
            map_attribute "name", to: :name
          end
        end
      end
    end
  end
end
