# frozen_string_literal: true

module Openmath
  module Base
    # An integer literal: <OMI>10</OMI>. The schema pattern allows digit
    # groups separated by single spaces ("1 000 000"), so the text is held
    # as written.
    module Omi
      def self.included(klass)
        klass.class_eval do
          include Openmath::Base::Common

          attribute :value, :string, collection: true

          xml do
            element "OMI"
            mixed_content
            map_content to: :value
          end
        end
      end
    end
  end
end
