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
        # integer1 / rounding1 — exact integer semantics
        factorial:    [->(args) { factorial(args) }, 1..1],
        quotient:     [->(args) { quotient(args) }, 2..2],
        remainder:    [->(args) { remainder(args) }, 2..2],
        floor:        [->(args) { rounding(args, :floor) }, 1..1],
        ceiling:      [->(args) { rounding(args, :ceil) }, 1..1],
        round:        [->(args) { rounding(args, :round) }, 1..1],
        # set1 / list1 — exact collections; suchthat/map ride the lambda layer
        list:         [->(args) { args }, 0..],
        set:          [->(args) { dedup(args) }, 0..],
        in:           [->(args) { member(args) }, 2..2],
        size:         [->(args) { collection(args).size }, 1..1],
        map:          [->(args) { map_over(args) }, 2..2],
        suchthat:     [->(args) { suchthat(args) }, 2..2],
        # interval1 — exact domains (Interval values; Range cannot carry an
        # open lower bound)
        interval:     [->(args) { interval(args, closed_low: true, closed_high: true) }, 2..2],
        interval_oo:  [->(args) { interval(args, closed_low: false, closed_high: false) }, 2..2],
        interval_oc:  [->(args) { interval(args, closed_low: false, closed_high: true) }, 2..2],
        interval_co:  [->(args) { interval(args, closed_low: true, closed_high: false) }, 2..2],
        # linalg — exact matrices as rectangular nested arrays over rationals
        matrix:       [->(args) { matrix(args) }, 1..],
        matrixrow:    [->(args) { require_numeric(args); args }, 0..],
        transpose:    [->(args) { matrix_arg(args).transpose }, 1..1],
        determinant:  [->(args) { determinant(matrix_arg(args)) }, 1..1],
        vector_product: [->(args) { vector_product(args) }, 2..2],
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

      # integer1 / rounding1 — exact integer semantics; a float operand
      # contaminates through Float arithmetic before the final exact step.
      def factorial(args)
        n = args.fetch(0)
        unless n.is_a?(Integer) && n >= 0
          raise OperandTypeError.new("factorial", n)
        end

        (1..n).reduce(1, :*)
      end

      def quotient(args)
        numerator, denominator = args
        require_numeric(args)
        (numerator.is_a?(Float) || denominator.is_a?(Float) ? numerator / denominator : Rational(numerator, denominator)).floor
      end

      def remainder(args)
        numerator, denominator = args
        numerator - denominator * quotient(args)
      end

      def rounding(args, method)
        require_numeric(args)
        value = args.fetch(0)
        value.is_a?(Integer) ? value : value.public_send(method)
      end

      # set1 / list1 — exact collections
      def dedup(args)
        result = []
        args.each { |arg| result << arg unless result.any? { |kept| arg == kept } }
        result
      end

      def member(args)
        value, collection = args
        case collection
        when Array then collection.any? { |kept| value == kept }
        when Range then collection.cover?(value)
        when Interval then collection.member?(value)
        else raise OperandTypeError.new("in", collection)
        end
      end

      def collection(args)
        value = args.fetch(0)
        case value
        when Array, Range then value
        else raise OperandTypeError.new("collection size", value)
        end
      end

      def map_over(args)
        closure, elements = args
        apply_elementwise(closure, collection([elements])) { |value, result| result }
      end

      def suchthat(args)
        collection_arg, closure = args
        elements = collection([collection_arg])
        apply_elementwise(closure, elements) do |value, result|
          require_boolean([result])
          result ? value : nil
        end.compact
      end

      # The lambda layer rides here: an elementwise application merges the
      # element over the closure's captured environment and evaluates the
      # body (the evaluator's discipline, one element at a time).
      def apply_elementwise(closure, elements)
        unless closure.is_a?(Closure) && closure.names.size == 1
          raise ArityError.new("lambda", 1..1, closure.is_a?(Closure) ? closure.names.size : 0)
        end

        elements.map do |element|
          environment = closure.environment.merge(closure.names[0] => element)
          result = Evaluator.evaluate(closure.body, variables: environment,
                                                    table: closure.table)
          yield element, result
        end
      end

      # interval1
      def interval(args, closed_low:, closed_high:)
        require_numeric(args)
        Interval.new(low: args.fetch(0), high: args.fetch(1),
                     low_closed: closed_low, high_closed: closed_high)
      end

      # linalg — exact matrices as rectangular nested arrays (the stdlib
      # matrix gem is not a bundled gem in current Rubies; the value model
      # stays plain data and the arithmetic stays exact).
      def matrix(args)
        args.each do |row|
          unless row.is_a?(Array) && row.size == args.first.size
            raise DimensionMismatchError, "matrix rows must be rectangular"
          end
        end
        args
      end

      def matrix_arg(args)
        matrix = args.fetch(0)
        unless matrix.is_a?(Array) && matrix.first.is_a?(Array) &&
            matrix.all? { |row| row.is_a?(Array) && row.size == matrix.first.size }
          raise OperandTypeError.new("matrix", matrix)
        end

        matrix
      end

      # Cofactor expansion over the exact ring: integers and rationals
      # never convert through floats.
      def determinant(rows)
        size = rows.size
        unless size == rows.first.size
          raise DimensionMismatchError, "determinant needs a square matrix"
        end
        return rows[0][0] if size == 1

        (0...size).sum do |column|
          minor = rows.drop(1).map { |row| row.reject.with_index { |_, i| i == column } }
          term = rows[0][column] * determinant(minor)
          column.even? ? term : -term
        end
      end

      def vector_product(args)
        left, right = args
        require_numeric(left + right)
        unless left.size == 3 && right.size == 3
          raise DimensionMismatchError, "vector_product needs two 3-vectors"
        end

        [
          left[1] * right[2] - left[2] * right[1],
          left[2] * right[0] - left[0] * right[2],
          left[0] * right[1] - left[1] * right[0],
        ]
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
