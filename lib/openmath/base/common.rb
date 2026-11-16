# frozen_string_literal: true

module Openmath
  module Base
    # Attributes common to all OpenMath 2 elements: the optional id.
    module Common
      def self.included(klass)
        klass.class_eval do
          attribute :id, :string
          xml { map_attribute "id", to: :id }
        end
      end
    end
  end
end
