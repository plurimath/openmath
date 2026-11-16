# frozen_string_literal: true

module Openmath
  # Semantic evaluation: content-dictionary symbols resolve through the
  # binding table and evaluate under the exactness discipline — integers
  # and rationals stay exact, floats contaminate to the limited class,
  # unbound symbols refuse with a typed error naming the symbol.
  module Evaluation
    autoload :Error, "openmath/evaluation/errors"
    autoload :UnboundSymbolError, "openmath/evaluation/errors"
    autoload :UnsupportedExpressionError, "openmath/evaluation/errors"
    autoload :ArityError, "openmath/evaluation/errors"
    autoload :OperandTypeError, "openmath/evaluation/errors"
    autoload :UnimplementedOperationError, "openmath/evaluation/errors"
    autoload :RecursionError, "openmath/evaluation/errors"
    autoload :BindingTable, "openmath/evaluation/binding_table"
    autoload :Operations, "openmath/evaluation/operations"
    autoload :ErrorValue, "openmath/evaluation/error_value"
    autoload :Closure, "openmath/evaluation/closure"
    autoload :Evaluator, "openmath/evaluation/evaluator"

    module_function

    # Evaluates an OpenMath object (or XML text) under the variable
    # bindings. The binding table is the shipped artifact unless given.
    def evaluate(object, variables: {}, table: BindingTable.default, version: nil)
      object = Openmath.parse(object, version: version || 2) if object.is_a?(String)
      Evaluator.evaluate(object, variables: variables, table: table)
    end
  end
end
