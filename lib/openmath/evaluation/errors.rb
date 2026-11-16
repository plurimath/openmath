# frozen_string_literal: true

module Openmath
  module Evaluation
    # The typed refusals. Every one names what it refused; none of them
    # guesses (the honest-error discipline of the PM series).
    class Error < StandardError; end

    # The symbol is not in the binding table.
    class UnboundSymbolError < Error
      attr_reader :cd, :name

      def initialize(cd, name)
        @cd = cd
        @name = name
        super("unbound symbol #{cd}##{name}: not in the binding table")
      end
    end

    # The construct is outside the evaluated surface (bindings, containers,
    # attributed operators...).
    class UnsupportedExpressionError < Error
      attr_reader :element

      def initialize(element)
        @element = element
        super("unsupported expression: #{element}")
      end
    end

    # The application's argument count contradicts the operation's signature.
    class ArityError < Error
      attr_reader :operation, :expected, :actual

      def initialize(operation, expected, actual)
        @operation = operation
        @expected = expected
        @actual = actual
        super("wrong arity for #{operation}: expected #{expected}, got #{actual}")
      end
    end

    # An operand is outside the operation's domain (e.g. a string in plus).
    class OperandTypeError < Error
      attr_reader :operation, :operand

      def initialize(operation, operand)
        @operation = operation
        @operand = operand
        super("wrong operand type for #{operation}: #{operand.class}")
      end
    end

    # The operation is bound in the table but not implemented — a build
    # error, not a caller error.
    class UnimplementedOperationError < Error
      attr_reader :operation

      def initialize(operation)
        @operation = operation
        super("binding table names unimplemented operation #{operation}")
      end
    end

    # An OMR reference resolves to a target currently under evaluation.
    class RecursionError < Error
      attr_reader :name

      def initialize(name)
        @name = name
        super("cyclic OMR reference to #{name.inspect}")
      end
    end

    # Shapes contradict (the PM error extension name).
    class DimensionMismatchError < Error
      attr_reader :context

      def initialize(context)
        @context = context
        super("DimensionMismatch: #{context}")
      end
    end

    # An application contradicts the operator's STS signature.
    class SignatureViolationError < Error
      attr_reader :detail

      def initialize(detail)
        @detail = detail
        super(detail)
      end
    end
  end
end
