# frozen_string_literal: true

module Openmath
  module Base
    # Attributes common to all elements that construct compound objects:
    # id plus the optional cdbase.
    module Compound
      def self.included(klass)
        klass.class_eval do
          include Openmath::Base::Common

          attribute :cdbase, :string
          xml { map_attribute "cdbase", to: :cdbase }
        end
      end
    end
  end
end
