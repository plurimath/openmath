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
      expect { described_class.evaluate(om("<OMBIND>#{oms("fns1", "lambda")}<OMBVAR>#{omv("x")}</OMBVAR>#{omi(0)}</OMBIND>")) }
        .to raise_error(Openmath::Evaluation::UnsupportedExpressionError, /OMBIND/)
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
      expect(table.version).to eq(1)
      expect(table.bindings.size).to be >= 21
    end
  end
end
