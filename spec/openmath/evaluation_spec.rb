# frozen_string_literal: true

require "spec_helper"

# Stage 3: semantic math that evaluates. The binding table (the checksummed
# data artifact) binds content-dictionary symbols to operations; the
# evaluator walks the tree under the exactness discipline — integers and
# rationals stay exact, floats contaminate to the limited class, and
# everything unbound refuses with a typed error naming what it refused.
RSpec.describe Openmath do
  def om(body)
    %(<OMOBJ xmlns="http://www.openmath.org/OpenMath">#{body}</OMOBJ>)
  end

  def app(op_cd, op_name, *args)
    om("<OMA><OMS cd=\"#{op_cd}\" name=\"#{op_name}\"/>#{args.join}</OMA>")
  end

  def omi(n) = "<OMI>#{n}</OMI>"
  def omf_dec(d) = %(<OMF dec="#{d}"/>)
  def omv(n) = %(<OMV name="#{n}"/>)
  def oms(cd, name) = %(<OMS cd="#{cd}" name="#{name}"/>)
  def inner_app(op_cd, op_name, *args)
    "<OMA>#{oms(op_cd, op_name)}#{args.join}</OMA>"
  end

  def lambda_om(*vars, body:)
    variables = vars.map { |v| omv(v) }.join
    "<OMBIND>#{oms("fns1", "lambda")}<OMBVAR>#{variables}</OMBVAR>#{body}</OMBIND>"
  end

  def applied_lambda(lambda_node, *args)
    om("<OMA>#{lambda_node}#{args.join}</OMA>")
  end

  describe "the arithmetic core" do
    it "evaluates plus, times, minus, unary_minus and abs exactly" do
      expect(described_class.evaluate(app("arith1", "plus", omi(1), omi(1)))).to eq(2)
      expect(described_class.evaluate(app("arith1", "times", omi(2), omi(3)))).to eq(6)
      expect(described_class.evaluate(app("arith1", "minus", omi(7), omi(9)))).to eq(-2)
      expect(described_class.evaluate(app("arith1", "unary_minus", omi(5)))).to eq(-5)
      expect(described_class.evaluate(app("arith1", "abs", omi(-3)))).to eq(3)
    end

    it "keeps digit-group integers exact" do
      expect(described_class.evaluate(om(omi("1 000 000")))).to eq(1_000_000)
    end

    it "evaluates divided_by of exact operands as an exact rational" do
      result = described_class.evaluate(app("arith1", "divided_by", omi(1), omi(4)))
      expect(result).to eq(Rational(1, 4))
      expect(result).to be_a(Rational)
    end

    it "contaminates to the limited class when a float operand enters" do
      result = described_class.evaluate(app("arith1", "divided_by", omf_dec(1.0), omi(4)))
      expect(result).to be_a(Float)
      expect(result).to eq(0.25)
    end

    it "raises ZeroDivisionError for exact division by zero" do
      expect { described_class.evaluate(app("arith1", "divided_by", omi(1), omi(0))) }
        .to raise_error(ZeroDivisionError)
    end

    it "evaluates power exactly, including negative exponents as rationals" do
      expect(described_class.evaluate(app("arith1", "power", omi(2), omi(10)))).to eq(1024)
      expect(described_class.evaluate(app("arith1", "power", omi(2), omi(-2)))).to eq(Rational(1, 4))
    end

    it "evaluates max and min over many arguments" do
      expect(described_class.evaluate(app("arith1", "max", omi(3), omi(1), omi(2)))).to eq(3)
      expect(described_class.evaluate(app("arith1", "min", omi(3), omi(1), omi(2)))).to eq(1)
    end

    it "evaluates IEEE floats by their hex bits" do
      # hex for the double 2.0
      expect(described_class.evaluate(app("arith1", "plus", omf_dec(1.0), %(<OMF hex="4000000000000000"/>)))).to eq(3.0)
    end
  end

  describe "nums1 constructions" do
    it "builds exact rationals" do
      expect(described_class.evaluate(app("nums1", "rational", omi(3), omi(9))))
        .to eq(Rational(1, 3))
    end

    it "passes integers through" do
      expect(described_class.evaluate(app("nums1", "integer", omi(42)))).to eq(42)
    end
  end

  describe "the comparisons" do
    it "evaluates eq, neq, lt, gt, leq, geq to booleans" do
      expect(described_class.evaluate(app("relation1", "eq", omi(1), omi(1)))).to be(true)
      expect(described_class.evaluate(app("relation1", "neq", omi(1), omi(1)))).to be(false)
      expect(described_class.evaluate(app("relation1", "lt", omi(1), omi(2)))).to be(true)
      expect(described_class.evaluate(app("relation1", "gt", omi(1), omi(2)))).to be(false)
      expect(described_class.evaluate(app("relation1", "leq", omi(2), omi(2)))).to be(true)
      expect(described_class.evaluate(app("relation1", "geq", omi(1), omi(2)))).to be(false)
    end

    it "chains comparisons over every consecutive pair" do
      expect(described_class.evaluate(app("relation1", "lt", omi(1), omi(2), omi(3)))).to be(true)
      expect(described_class.evaluate(app("relation1", "lt", omi(1), omi(3), omi(2)))).to be(false)
    end
  end

  describe "the logic connectives" do
    true_ = %(<OMS cd="logic1" name="true"/>)

    it "evaluates the connectives over variable-bound booleans" do
      vars = { a: true, b: false }
      expect(described_class.evaluate(app("logic1", "and", omv("a"), omv("b")), variables: vars)).to be(false)
      expect(described_class.evaluate(app("logic1", "or", omv("a"), omv("b")), variables: vars)).to be(true)
      expect(described_class.evaluate(app("logic1", "xor", omv("a"), omv("b")), variables: vars)).to be(true)
      expect(described_class.evaluate(app("logic1", "not", omv("a")), variables: vars)).to be(false)
      expect(described_class.evaluate(app("logic1", "implies", omv("b"), omv("a")), variables: vars)).to be(true)
      expect { described_class.evaluate(app("logic1", "and", omv("missing")), variables: vars) }
        .to raise_error(Openmath::Evaluation::UnboundSymbolError, /\(variable\)#missing/)
    end
  end

  describe "variables and error objects" do
    it "binds OMV by name" do
      expect(described_class.evaluate(
        app("arith1", "plus", omv("x"), omi(1)), variables: { x: 41 }
      )).to eq(42)
    end

    it "evaluates an OME error constructor to an error value" do
      value = described_class.evaluate(
        om("<OME>#{oms("aritherror", "divide_by_zero")}#{omi(1)}</OME>")
      )
      expect(value).to be_a(Openmath::Evaluation::ErrorValue)
      expect(value.cd).to eq("aritherror")
      expect(value.name).to eq("divide_by_zero")
      expect(value.arguments).to eq([1])
    end

    it "evaluates strings and byte arrays to their decoded content" do
      expect(described_class.evaluate(om("<OMSTR>hello</OMSTR>"))).to eq("hello")
      expect(described_class.evaluate(om("<OMB>aGVsbG8=</OMB>"))).to eq("hello")
    end
  end

  describe "the strict refusals" do
    it "refuses an unbound symbol naming cd and name" do
      expect { described_class.evaluate(app("mycd", "f", omi(1))) }
        .to raise_error(
          Openmath::Evaluation::UnboundSymbolError,
          /unbound symbol mycd#f: not in the binding table/,
        )
    end

    it "refuses wrong arity with the operation and counts" do
      expect { described_class.evaluate(app("arith1", "divided_by", omi(1))) }
        .to raise_error(Openmath::Evaluation::ArityError, /divided_by.*expected 2\.\.2, got 1/)
    end

    it "refuses operands outside the operation's domain" do
      expect { described_class.evaluate(app("arith1", "plus", "<OMSTR>x</OMSTR>")) }
        .to raise_error(Openmath::Evaluation::OperandTypeError, /arithmetic/)
    end

    it "refuses constructs outside the evaluated surface" do
      expect { described_class.evaluate(om("<OMBIND>#{oms("fns1", "Map")}<OMBVAR>#{omv("x")}</OMBVAR>#{omi(0)}</OMBIND>")) }
        .to raise_error(Openmath::Evaluation::UnboundSymbolError, /fns1#Map/)
    end
  end

  describe "lambda application" do
    it "applies a lambda to its arguments" do
      body = inner_app("arith1", "plus", omv("x"), omi(1))

      expect(described_class.evaluate(applied_lambda(lambda_om("x", body: body), omi(2))))
        .to eq(3)
    end

    it "keeps rationals exact through a lambda body" do
      body = inner_app("arith1", "divided_by", omv("x"), omi(4))
      result = described_class.evaluate(applied_lambda(lambda_om("x", body: body), omi(1)))

      expect(result).to eq(Rational(1, 4))
      expect(result).to be_a(Rational)
    end

    it "captures the environment lexically" do
      body = inner_app("arith1", "plus", omv("x"), omv("y"))
      applied = applied_lambda(lambda_om("x", body: body), omi(2))

      expect(described_class.evaluate(applied, variables: { y: 10 })).to eq(12)
    end

    it "refuses arity mismatches naming lambda" do
      body = inner_app("arith1", "plus", omv("x"), omv("y"))
      applied = applied_lambda(lambda_om("x", body: body), omi(2), omi(3))

      expect { described_class.evaluate(applied) }
        .to raise_error(Openmath::Evaluation::ArityError, /lambda.*expected 1\.\.1, got 2/)
    end

    it "binds attributed variables by their wrapped name" do
      attvar = "<OMATTR><OMATP>#{oms("misc", "def")}#{omi(0)}</OMATP>#{omv("x")}</OMATTR>"
      body = inner_app("arith1", "times", omv("x"), omv("x"))
      binder = "<OMBIND>#{oms("fns1", "lambda")}<OMBVAR>#{attvar}</OMBVAR>#{body}</OMBIND>"

      expect(described_class.evaluate(applied_lambda(binder, omi(7))))
        .to eq(49)
    end

    it "refuses applying a non-callable value" do
      expect { described_class.evaluate(om("<OMA>#{omi(5)}</OMA>")) }
        .to raise_error(Openmath::Evaluation::UnsupportedExpressionError, /application of a? ?Integer/)
    end

    it "refuses lambda without a single body" do
      expect { described_class.evaluate(om("<OMBIND>#{oms("fns1", "lambda")}<OMBVAR>#{omv("x")}</OMBVAR>#{omi(1)}#{omi(2)}</OMBIND>")) }
        .to raise_error(Openmath::Evaluation::UnsupportedExpressionError, /2 bodies/)
    end

    it "refuses non-lambda binders through the unbound-symbol discipline" do
      binder = "<OMBIND>#{oms("fns1", "Map")}<OMBVAR>#{omv("x")}</OMBVAR>#{omi(0)}</OMBIND>"

      expect { described_class.evaluate(om(binder)) }
        .to raise_error(Openmath::Evaluation::UnboundSymbolError, /fns1#Map/)
    end
  end

  describe "OMATTR semantics" do
    it "evaluates the attributed object, ignoring presentational pairs" do
      inner = inner_app("arith1", "plus", omi(1), omi(1))
      attributed = "<OMATTR><OMATP>#{oms("present", "style")}<OMSTR>boxed</OMSTR></OMATP>#{inner}</OMATTR>"

      expect(described_class.evaluate(om(attributed))).to eq(2)
    end

    it "evaluates attributions around bindings" do
      binder = "<OMBIND>#{oms("fns1", "lambda")}<OMBVAR>#{omv("x")}</OMBVAR>" \
               "#{inner_app("arith1", "times", omv("x"), omv("x"))}</OMBIND>"
      attributed = "<OMATTR><OMATP>#{oms("misc", "def")}#{oms("mycd", "square")}</OMATP>#{binder}</OMATTR>"
      closure = described_class.evaluate(om(attributed))

      expect(closure).to be_a(Openmath::Evaluation::Closure)
      expect(described_class.evaluate(om("<OMA>#{binder}<OMI>6</OMI></OMA>"))).to eq(36)
    end

    it "refuses attributions without an attributed object" do
      expect { described_class.evaluate(om("<OMATTR><OMATP>#{oms("misc", "def")}</OMATP></OMATTR>")) }
        .to raise_error(Openmath::Evaluation::UnsupportedExpressionError, /attribution without an object/)
    end
  end

  describe "OMR reference resolution" do
    it "resolves a fragment reference to its target within the scope" do
      xml = om("<OMA>#{oms("arith1", "plus")}" \
               "<OMI id=\"answer\">42</OMI><OMR href=\"#answer\"/></OMA>")

      expect(described_class.evaluate(xml)).to eq(84)
    end

    it "resolves references reached through a lambda application" do
      binder = "<OMBIND>#{oms("fns1", "lambda")}<OMBVAR>#{omv("x")}</OMBVAR>" \
               "#{inner_app("arith1", "times", omv("x"), "<OMI id=\"seven\">7</OMI>")}</OMBIND>"
      applied = om("<OMA>#{binder}#{omi(3)}</OMA>")

      expect(described_class.evaluate(applied)).to eq(21)
    end

    it "gives both references to one target the same value" do
      xml = om("<OMA>#{oms("arith1", "plus")}" \
               "<OMI id=\"t\">6</OMI><OMR href=\"#t\"/><OMR href=\"#t\"/></OMA>")

      expect(described_class.evaluate(xml)).to eq(18)
    end

    it "refuses cyclic references typed" do
      xml = om("<OMA id=\"me\"><OMR href=\"#me\"/></OMA>")

      expect { described_class.evaluate(xml) }
        .to raise_error(Openmath::Evaluation::RecursionError, /cyclic OMR reference to "me"/)
    end

    it "refuses unresolvable references naming the id" do
      xml = om("<OMR href=\"#missing\"/>")

      expect { described_class.evaluate(xml) }
        .to raise_error(Openmath::Evaluation::UnboundSymbolError, /\(reference\)#missing/)
    end

    it "refuses non-fragment hrefs" do
      xml = om("<OMR href=\"http://example.org/obj\"/>")

      expect { described_class.evaluate(xml) }
        .to raise_error(Openmath::Evaluation::UnsupportedExpressionError, /not a fragment reference/)
    end
  end

  describe "the binding families" do
  def eval_om(inner) = described_class.evaluate(om(inner))

  it "evaluates integer1 and rounding1 exactly" do
    expect(described_class.evaluate(app("integer1", "factorial", omi(5)))).to eq(120)
    expect(described_class.evaluate(app("integer1", "quotient", omi(7), omi(2)))).to eq(3)
    expect(described_class.evaluate(app("integer1", "remainder", omi(7), omi(2)))).to eq(1)
    halves = inner_app("nums1", "rational", omi(7), omi(2))
    expect(described_class.evaluate(app("rounding1", "floor", halves))).to eq(3)
    expect(described_class.evaluate(app("rounding1", "ceiling", halves))).to eq(4)
    expect(described_class.evaluate(app("rounding1", "round", halves))).to eq(4)
  end

  it "contaminates through floats before the exact rounding step" do
    expect(described_class.evaluate(app("rounding1", "floor", omf_dec(1.5)))).to eq(1)
  end

  it "evaluates set1 and list1 as exact collections" do
    listed = inner_app("list1", "list", omi(1), omi(2), omi(3))
    expect(eval_om(listed)).to eq([1, 2, 3])
    expect(described_class.evaluate(app("set1", "set", omi(1), omi(2), omi(1))))
      .to eq([1, 2])
    expect(described_class.evaluate(app("set1", "size", listed))).to eq(3)
    expect(described_class.evaluate(app("set1", "in", omi(2), listed))).to be(true)
    expect(described_class.evaluate(app("set1", "in", omi(9), listed))).to be(false)
  end

  it "maps and filters through the lambda layer" do
    double = lambda_om("x", body: inner_app("arith1", "times", omv("x"), omi(2)))
    listed = inner_app("list1", "list", omi(1), omi(2))

    expect(described_class.evaluate(app("list1", "map", double, listed))).to eq([2, 4])

    under_three = lambda_om("x", body: inner_app("relation1", "lt", omv("x"), omi(3)))
    four = inner_app("list1", "list", omi(1), omi(2), omi(3), omi(4))
    expect(described_class.evaluate(app("set1", "suchthat", four, under_three)))
      .to eq([1, 2])
  end

  it "refuses non-boolean predicates and non-collection operands" do
    numeric = "<OMBIND>#{oms("fns1", "lambda")}<OMBVAR>#{omv("x")}</OMBVAR>#{omv("x")}</OMBIND>"
    listed = inner_app("list1", "list", omi(1))
    expect { described_class.evaluate(app("set1", "suchthat", listed, numeric)) }
      .to raise_error(Openmath::Evaluation::OperandTypeError, /logic/)
    expect { described_class.evaluate(app("set1", "size", omi(3))) }
      .to raise_error(Openmath::Evaluation::OperandTypeError, /collection size/)
  end

  it "evaluates interval1 with open and closed bounds" do
    open_low = inner_app("interval1", "interval_oc", omi(1), omi(3))
    expect(described_class.evaluate(app("set1", "in", omi(3), open_low))).to be(true)
    expect(described_class.evaluate(app("set1", "in", omi(1), open_low))).to be(false)
    closed = inner_app("interval1", "interval", omi(1), omi(3))
    expect(described_class.evaluate(app("set1", "in", omi(1), closed))).to be(true)
    rational = inner_app("nums1", "rational", omi(5), omi(2))
    expect(described_class.evaluate(app("set1", "in", rational, open_low))).to be(true)
  end

  it "evaluates linalg matrices exactly" do
    m2 = inner_app("linalg2", "matrix",
                   inner_app("linalg2", "matrixrow", omi(1), omi(2)),
                   inner_app("linalg2", "matrixrow", omi(3), omi(4)))
    expect(described_class.evaluate(app("linalg3", "determinant", m2))).to eq(-2)
    expect(described_class.evaluate(app("linalg1", "transpose", m2)))
      .to eq([[1, 3], [2, 4]])
    unit_x = inner_app("linalg2", "matrixrow", omi(1), omi(0), omi(0))
    unit_y = inner_app("linalg2", "matrixrow", omi(0), omi(1), omi(0))
    expect(described_class.evaluate(app("linalg1", "vector_product", unit_x, unit_y)))
      .to eq([0, 0, 1])
  end

  it "refuses shape contradictions with the PM extension name" do
    rectangular = inner_app("linalg2", "matrix",
                            inner_app("linalg2", "matrixrow", omi(1), omi(2), omi(3)),
                            inner_app("linalg2", "matrixrow", omi(4), omi(5), omi(6)))
    expect { described_class.evaluate(app("linalg3", "determinant", rectangular)) }
      .to raise_error(Openmath::Evaluation::DimensionMismatchError, /DimensionMismatch/)
    unit_x = inner_app("linalg2", "matrixrow", omi(1), omi(0), omi(0))
    unit_w = inner_app("linalg2", "matrixrow", omi(0), omi(0), omi(0), omi(1))
    expect { described_class.evaluate(app("linalg1", "vector_product", unit_x, unit_w)) }
      .to raise_error(Openmath::Evaluation::DimensionMismatchError, /two 3-vectors/)
  end

  it "keeps calculus1 symbolic entries outside the evaluated surface" do
    expect { described_class.evaluate(app("calculus1", "diff", omv("x"))) }
      .to raise_error(Openmath::Evaluation::UnboundSymbolError, /calculus1#diff/)
  end
end

describe "the v1 core's remaining official symbols" do
  def eval_om(inner) = described_class.evaluate(om(inner))

  def binder(body, var = "x")
    "<OMBIND>#{oms("fns1", "lambda")}<OMBVAR>#{omv(var)}</OMBVAR>#{body}</OMBIND>"
  end

  it "constructs based integers exactly" do
    expect(described_class.evaluate(app("nums1", "based_integer", omi(16), "<OMSTR>1af</OMSTR>")))
      .to eq(431)
    expect(described_class.evaluate(app("nums1", "based_integer", omi(2), "<OMSTR>-101</OMSTR>")))
      .to eq(-5)
    expect { described_class.evaluate(app("nums1", "based_integer", omi(1), "<OMSTR>1</OMSTR>")) }
      .to raise_error(Openmath::Evaluation::OperandTypeError, /base/)
  end

  it "takes exact roots over the exact ring and contaminates otherwise" do
    expect(described_class.evaluate(app("arith1", "root", omi(4), omi(2)))).to eq(2)
    expect(described_class.evaluate(app("arith1", "root", omi(-8), omi(3)))).to eq(-2)
    expect(described_class.evaluate(app("arith1", "root",
      inner_app("nums1", "rational", omi(9), omi(4)), omi(2))))
      .to eq(Rational(3, 2))
    irrational = described_class.evaluate(app("arith1", "root", omi(2), omi(2)))
    expect(irrational).to be_a(Float)
    expect(irrational).to be_within(1e-12).of(1.4142135623730951)
    expect { described_class.evaluate(app("arith1", "root", omi(8), omi(-2))) }
      .to raise_error(Openmath::Evaluation::OperandTypeError, /root index/)
  end

  it "sums and multiplies over enumerated domains through the lambda layer" do
    half = binder(inner_app("arith1", "divided_by", omv("x"), omi(2)))
    unit = inner_app("interval1", "interval", omi(1), omi(4))
    result = described_class.evaluate(app("arith1", "sum", unit, half))
    expect(result).to eq(5)
    expect(result).to be_a(Rational)

    double = binder(inner_app("arith1", "times", omv("x"), omi(2)))
    expect(described_class.evaluate(app("arith1", "product", unit, double))).to eq(384)

    listed = inner_app("list1", "list", omi(1), omi(2), omi(3))
    expect(described_class.evaluate(app("arith1", "sum", listed, binder(omv("x"))))).to eq(6)

    expect(described_class.evaluate(app("arith1", "sum",
      inner_app("interval1", "interval_oc", omi(1), omi(2)),
      binder(omv("x"))))).to eq(2)
  end

  it "refuses non-enumerable summation domains" do
    matrix = inner_app("linalg2", "matrix",
                       inner_app("linalg2", "matrixrow", omi(1)))
    expect { described_class.evaluate(app("arith1", "sum", matrix, binder(omv("x")))) }
      .to raise_error(Openmath::Evaluation::OperandTypeError, /summation domain/)
  end

  it "compares approximately with a documented tolerance" do
    expect(described_class.evaluate(app("relation1", "approx", omi(1), omi(1)))).to be(true)
    expect(described_class.evaluate(app("relation1", "approx", omi(1), omi(2)))).to be(false)
    float_sum = inner_app("arith1", "plus", %(<OMF dec="0.1"/>), %(<OMF dec="0.2"/>))
    expect(described_class.evaluate(app("relation1", "approx", float_sum, %(<OMF dec="0.3"/>))))
      .to be(true)
    expect(described_class.evaluate(app("relation1", "approx",
      inner_app("nums1", "rational", omi(355), omi(113)),
      %(<OMF dec="3.141592653589793"/>)))).to be(true)
  end
end

  describe "the binding table artifact" do
    it "pins the shipped table's checksum" do
      checksum = Openmath::Evaluation::BindingTable.default_checksum
      expect(checksum).to be_a(String)
      expect(checksum.size).to eq(64)
    end

    it "records the schema and version" do
      table = Openmath::Evaluation::BindingTable.default
      expect(table.version).to eq(5)
      expect(table.bindings.size).to be >= 50
    end
  end
end
