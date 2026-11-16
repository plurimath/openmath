# frozen_string_literal: true

module Openmath
  module Base
    # A foreign object: <OMFOREIGN encoding="...">...</OMFOREIGN>
    # (schema: compound attributes, optional encoding, then OpenMath children
    # and foreign markup. This release models the OpenMath children and the
    # encoding; non-OpenMath markup inside is not yet represented — see the
    # roadmap issue.)
    module Omforeign
      def self.included(klass)
        klass.class_eval do
          include Openmath::Base::Compound

          attribute :foreign_encoding, :string

          xml do
            element "OMFOREIGN"
            ordered
            map_attribute "encoding", to: :foreign_encoding
          end
        end
      end
    end
  end
end
