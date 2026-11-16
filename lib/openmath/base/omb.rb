# frozen_string_literal: true

module Openmath
  module Base
    # A byte array: <OMB>base64</OMB> (schema: xsd:base64Binary content).
    module Omb
      def self.included(klass)
        klass.class_eval do
          include Openmath::Base::Common

          attribute :value, :string, collection: true

          xml do
            element "OMB"
            mixed_content
            map_content to: :value
          end
        end
      end
    end
  end
end
