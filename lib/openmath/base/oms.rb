# frozen_string_literal: true

module Openmath
  module Base
    # A symbol from a content dictionary:
    # <OMS cd="arith1" name="plus"/> (schema: name and cd required NCNames,
    # plus the optional id and cdbase).
    module Oms
      def self.included(klass)
        klass.class_eval do
          include Openmath::Base::Common

          attribute :name, :string
          attribute :cd, :string
          attribute :cdbase, :string

          xml do
            element "OMS"
            map_attribute "name", to: :name
            map_attribute "cd", to: :cd
            map_attribute "cdbase", to: :cdbase
          end
        end
      end
    end
  end
end
