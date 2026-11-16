# frozen_string_literal: true

module Openmath
  module Base
    # An error: <OME><OMS cd="..." name="..."/> ...content</OME>
    # (schema: common attributes, one leading OMS, then objects or foreign).
    module Ome
      def self.included(klass)
        klass.class_eval do
          include Openmath::Base::Common

          xml do
            element "OME"
            ordered
          end
        end
      end
    end
  end
end
