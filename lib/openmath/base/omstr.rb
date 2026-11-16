# frozen_string_literal: true

module Openmath
  module Base
    # A string: <OMSTR>text</OMSTR> (schema: text content).
    module Omstr
      def self.included(klass)
        klass.class_eval do
          include Openmath::Base::Common

          attribute :value, :string, collection: true

          xml do
            element "OMSTR"
            mixed_content
            map_content to: :value
          end
        end
      end
    end
  end
end
