# frozen_string_literal: true

module Openmath
  module Evaluation
    # The value of evaluating an OME error constructor: an error object that
    # carries its cd, name and evaluated content — the honest answer to
    # evaluating an expression whose meaning is an error.
    class ErrorValue
      attr_reader :cd, :name, :arguments

      def initialize(cd, name, arguments)
        @cd = cd
        @name = name
        @arguments = arguments
      end

      def ==(other)
        other.is_a?(ErrorValue) && other.cd == cd &&
          other.name == name && other.arguments == arguments
      end

      def to_s
        "#{cd}##{name}(#{arguments.join(', ')})"
      end
    end
  end
end
