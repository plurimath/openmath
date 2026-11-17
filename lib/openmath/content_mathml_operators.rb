# frozen_string_literal: true

module Openmath
  # The Content MathML operator table (MathML 4, the content operator
  # classes): the non-strict operator elements that transform to
  # csymbol + apply, with the OpenMath content dictionary each maps to.
  # This is the element set the reader accepts beside the strict core;
  # the writer always emits the strict form.
  module ContentMathMLOperators
    # element name => [cd, name]
    TABLE = {
      "plus" => %w[arith1 plus],
      "times" => %w[arith1 times],
      "minus" => %w[arith1 minus],
      "unary_minus" => %w[arith1 unary_minus],
      "divide" => %w[arith1 divided_by],
      "power" => %w[arith1 power],
      "root" => %w[arith1 root],
      "abs" => %w[arith1 abs],
      "max" => %w[arith1 max],
      "min" => %w[arith1 min],
      "sum" => %w[arith1 sum],
      "product" => %w[arith1 product],
      "rem" => %w[integer1 remainder],
      "factorial" => %w[integer1 factorial],
      "floor" => %w[rounding1 floor],
      "ceiling" => %w[rounding1 ceiling],
      "eq" => %w[relation1 eq],
      "neq" => %w[relation1 neq],
      "gt" => %w[relation1 gt],
      "lt" => %w[relation1 lt],
      "geq" => %w[relation1 geq],
      "leq" => %w[relation1 leq],
      "approx" => %w[relation1 approx],
      "and" => %w[logic1 and],
      "or" => %w[logic1 or],
      "xor" => %w[logic1 xor],
      "not" => %w[logic1 not],
      "implies" => %w[logic1 implies],
      "identity" => %w[fns1 identity],
      "compose" => %w[fns1 left_compose],
      "inverse" => %w[fns1 inverse],
      "transpose" => %w[linalg1 transpose],
      "determinant" => %w[linalg3 determinant],
      "int" => %w[calculus1 int],
      "diff" => %w[calculus1 diff],
      "partialdiff" => %w[calculus1 partialdiff],
      "limit" => %w[calculus1 limit],
    }.freeze
  end
end
