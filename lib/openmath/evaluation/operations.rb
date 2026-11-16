# frozen_string_literal: true

module Openmath
  module Evaluation
    # The operations the binding table can name, with their signatures and
    # the exactness discipline: integers and rationals stay exact; a float
    # operand contaminates the result to the limited class; divided_by of
    # exact operands is an exact rational, never a float.
    module Operations
      module_function

      # [implementation, arity spec] where arity spec is an Integer or a
      # Range. The implementation receives the evaluated arguments.
      REGISTRY = {
        identity:     [->(args) { args.fetch(0) }, 1..1],
        rational:     [->(args) { rational(args) }, 2..2],
        plus:         [->(args) { numeric_fold(args, :+) }, 1..],
        times:        [->(args) { numeric_fold(args, :*) }, 1..],
        minus:        [->(args) { numeric_pair(args) { |a, b| a - b } }, 2..2],
        unary_minus:  [->(args) { require_numeric(args); -args.fetch(0) }, 1..1],
        divided_by:   [->(args) { divided_by(args) }, 2..2],
        power:        [->(args) { power(args) }, 2..2],
        abs:          [->(args) { args.fetch(0).abs }, 1..1],
        max:          [->(args) { require_numeric(args); args.max }, 1..],
        min:          [->(args) { require_numeric(args); args.min }, 1..],
        eq:           [->(args) { compare_chain(args, :==) }, 2..],
        neq:          [->(args) { args[0] != args[1] }, 2..2],
        gt:           [->(args) { compare_chain(args, :>) }, 2..],
        lt:           [->(args) { compare_chain(args, :<) }, 2..],
        geq:          [->(args) { compare_chain(args, :>=) }, 2..],
        leq:          [->(args) { compare_chain(args, :<=) }, 2..],
        and:          [->(args) { boolean_fold(args) { |a, b| a && b } }, 1..],
        or:           [->(args) { boolean_fold(args) { |a, b| a || b } }, 1..],
        xor:          [->(args) { boolean_fold(args, :^) }, 2..],
        not:          [->(args) { !args.fetch(0) }, 1..1],
        implies:      [->(args) { !args.fetch(0) || args.fetch(1) }, 2..2],
      }.freeze

      def implementation(operation)
        entry = REGISTRY[operation]
        return entry if entry

        raise UnimplementedOperationError, operation
      end

      def arity(operation)
        REGISTRY.fetch(operation).last
      end

      def rational(args)
        numerator, denominator = args
        if numerator.is_a?(Float) || denominator.is_a?(Float)
          require_contaminated(numerator, denominator)
          numerator / denominator
        else
          Rational(numerator, denominator)
        end
      end

      def numeric_fold(args, operator)
        require_numeric(args)
        args.reduce { |a, b| a.public_send(operator, b) }
      end

      def numeric_pair(args, &block)
        require_numeric(args)
        block.call(args.fetch(0), args.fetch(1))
      end

      def divided_by(args)
        require_numeric(args)
        numerator, denominator = args
        if numerator.is_a?(Float) || denominator.is_a?(Float)
          numerator / denominator
        elsif denominator.zero?
          raise ZeroDivisionError, "exact division by zero"
        else
          Rational(numerator, denominator)
        end
      end

      def power(args)
        base, exponent = args
        if base.is_a?(Float) || exponent.is_a?(Float)
          base**exponent
        elsif exponent.is_a?(Integer) && exponent >= 0
          base**exponent
        else
          Rational(base)**exponent
        end
      end

      def compare_chain(args, operator)
        require_numeric(args)
        args.each_cons(2).all? { |a, b| a.public_send(operator, b) }
      end

      def boolean_fold(args, operator = nil)
        require_boolean(args)
        return args.reduce { |a, b| yield a, b } unless operator

        args.reduce { |a, b| a.public_send(operator, b) }
      end

      def require_numeric(args)
        args.each do |arg|
          unless arg.is_a?(Numeric)
            raise OperandTypeError.new("arithmetic", arg)
          end
        end
      end

      def require_boolean(args)
        args.each do |arg|
          raise OperandTypeError.new("logic", arg) unless arg == true || arg == false
        end
      end

      def require_contaminated(*args)
        args.each do |arg|
          raise OperandTypeError.new("float arithmetic", arg) unless arg.is_a?(Numeric)
        end
      end
    end
  end
end
