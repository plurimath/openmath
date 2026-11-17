# frozen_string_literal: true

require "spec_helper"

# The pmquant CD family (PM 1002's quantity/uncertainty constructors as
# OpenMath data) and the deterministic Monte-Carlo layer over it.
RSpec.describe "the pmquant CD family" do
  let(:collection) { Openmath::CD::Collection.new.load(pmquant_ocd) }
  let(:signatures) { Openmath::CD::Signatures.load(pmquant_sts) }
  let(:pmquant_ocd) { File.expand_path("../../data/pmquant.ocd", __dir__) }
  let(:pmquant_sts) { File.expand_path("../../data/pmquant.sts", __dir__) }

  def om(body)
    %(<OMOBJ xmlns="http://www.openmath.org/OpenMath">#{body}</OMOBJ>)
  end

  def app(*parts)
    "<OMA>#{parts.join}</OMA>"
  end

  def evalq(inner)
    Openmath.evaluate(om(inner))
  end

  def oms(cd, name) = %(<OMS cd="#{cd}" name="#{name}"/>)
  def omf(d) = %(<OMF dec="#{d}"/>)

  it "is a schema-valid CD loading beside the official collection" do
    expect(collection["pmquant"]).to be_a(Openmath::CD::Document)
    expect(Openmath::CD::Collection.validate(File.read(pmquant_ocd))).to be_empty
    expect(collection["pmquant"].definition_for("ustd")).to be_a(Openmath::CD::Definition)
    expect(collection["pmquant"].definition_for("ucov")).to be_a(Openmath::CD::Definition)
  end

  it "ships signatures indexed per symbol" do
    expect(signatures.lookup("pmquant", "ustd")).to be_a(Openmath::V2::Omobj)
    expect(signatures.lookup("pmquant", "value")).to be_a(Openmath::V2::Omobj)
  end

  describe "the constructors" do
    it "builds the standard category" do
      quantity = evalq(app(oms("pmquant", "ustd"), omf(10.3), omf(0.2)))

      expect(quantity).to be_a(Openmath::Evaluation::Uncertain)
      expect(quantity.category).to eq(:standard)
      expect(quantity.value).to eq(10.3)
      expect(quantity.magnitude).to eq(0.2)
    end

    it "builds the expanded category with factor and probability" do
      quantity = evalq(app(oms("pmquant", "uexp"), omf(10.3), omf(0.5),
                           omf(2), omf(0.95)))

      expect(quantity.category).to eq(:expanded)
      expect(quantity.coverage_factor).to eq(2.0)
      expect(quantity.coverage_probability).to eq(0.95)
    end

    it "builds the coverage-interval category with the kind" do
      quantity = evalq(app(oms("pmquant", "ucov"), omf(10.3), omf(9.9),
                           omf(10.7), omf(0.95), "<OMSTR>shortest</OMSTR>"))

      expect(quantity.category).to eq(:coverage)
      expect(quantity.lower).to eq(9.9)
      expect(quantity.upper).to eq(10.7)
      expect(quantity.interval_kind).to eq("shortest")
    end

    it "keeps exact operands exact inside the quantity" do
      quantity = evalq(app(
        oms("pmquant", "ustd"), "<OMI>103</OMI>",
        "<OMA>#{oms("nums1", "rational")}<OMI>1</OMI><OMI>5</OMI></OMA>",
      ))

      expect(quantity.value).to eq(103)
      expect(quantity.magnitude).to eq(Rational(1, 5))
    end

    it "extracts the reported value" do
      expect(evalq(app(
        oms("pmquant", "value"),
        app(oms("pmquant", "ustd"), omf(10.3), omf(0.2)),
      ))).to eq(10.3)
    end

    it "refuses per PM 1002 clause 6" do
      expect do
        evalq(app(oms("pmquant", "uexp"), omf(1), omf(1), omf(0)))
      end.to raise_error(Openmath::Evaluation::OperandTypeError, /coverage factor/)
      expect do
        evalq(app(oms("pmquant", "uexp"), omf(1), omf(1), omf(-2)))
      end.to raise_error(Openmath::Evaluation::OperandTypeError, /coverage factor/)
      expect do
        evalq(app(oms("pmquant", "uexp"), omf(1), omf(1), omf(2), omf(1)))
      end.to raise_error(Openmath::Evaluation::OperandTypeError, /coverage probability/)
      expect do
        evalq(app(oms("pmquant", "ucov"), omf(1), omf(3), omf(2)))
      end.to raise_error(Openmath::Evaluation::OperandTypeError, /coverage interval/)
      expect do
        evalq(app(oms("pmquant", "ucov"), omf(1), omf(0), omf(2),
                  omf(0.95), "<OMSTR>other</OMSTR>"))
      end.to raise_error(Openmath::Evaluation::OperandTypeError, /interval kind/)
    end

    it "checks against its own signatures" do
      expect do
        Openmath.evaluate(om(app(oms("pmquant", "ustd"), "<OMV name=\"t\"/>",
                                 omf(0.2))),
                          variables: { t: true }, signatures: signatures)
      end.to raise_error(Openmath::Evaluation::SignatureViolationError, /pmquant#ustd/)
    end
  end

  describe "quantity arithmetic" do
    it "propagates standard uncertainties in quadrature" do
      quantity = evalq(app(
        oms("arith1", "plus"),
        app(oms("pmquant", "ustd"), omf(10), omf(0.2)),
        app(oms("pmquant", "ustd"), omf(1), omf(0.1)),
      ))

      expect(quantity.category).to eq(:standard)
      expect(quantity.value).to eq(11.0)
      expect(quantity.magnitude).to be_within(1e-12).of(Math.sqrt(0.04 + 0.01))
    end

    it "keeps exact reported values exact through propagation" do
      quantity = evalq(app(
        oms("arith1", "plus"),
        app(oms("pmquant", "ustd"), "<OMI>10</OMI>", omf(0.2)),
        app(oms("pmquant", "ustd"), "<OMI>1</OMI>", omf(0.1)),
      ))

      expect(quantity.value).to eq(11)
    end

    it "shifts by plain numbers without changing the magnitude" do
      quantity = evalq(app(
        oms("arith1", "plus"),
        app(oms("pmquant", "ustd"), omf(10), omf(0.2)),
        omf(1),
      ))

      expect(quantity.value).to eq(11.0)
      expect(quantity.magnitude).to eq(0.2)
    end

    it "refuses arithmetic on expanded and coverage categories" do
      expect do
        evalq(app(
          oms("arith1", "plus"),
          app(oms("pmquant", "uexp"), omf(10), omf(0.5), omf(2)),
          omf(1),
        ))
      end.to raise_error(Openmath::Evaluation::OperandTypeError, /arithmetic/)
    end
  end

  describe "deterministic Monte-Carlo evaluation" do
    it "reproduces the same samples under the same seed" do
      xml = om(app(oms("pmquant", "ustd"), omf(10.3), omf(0.2)))
      first = Openmath.evaluate_stochastic(xml, samples: 200, seed: 42)
      second = Openmath.evaluate_stochastic(xml, samples: 200, seed: 42)

      expect(first.samples).to eq(second.samples)
      expect(first.generator).to eq("mt19937")
      expect(first.seed).to eq(42)
      expect(first.count).to eq(200)
    end

    it "samples around the reported value with the declared spread" do
      xml = om(app(oms("pmquant", "ustd"), omf(10.3), omf(0.2)))
      result = Openmath.evaluate_stochastic(xml, samples: 2000, seed: 42)

      expect(result.value.value).to eq(10.3)
      expect(result.mean).to be_within(0.03).of(10.3)
      expect(result.standard_deviation).to be_within(0.02).of(0.2)
    end

    it "propagates two independent quantities with combined spread" do
      xml = om(app(
        oms("arith1", "plus"),
        app(oms("pmquant", "ustd"), omf(10.0), omf(0.2)),
        app(oms("pmquant", "ustd"), omf(1.0), omf(0.1)),
      ))
      result = Openmath.evaluate_stochastic(xml, samples: 2000, seed: 7)

      expect(result.mean).to be_within(0.03).of(11.0)
      expect(result.standard_deviation).to be_within(0.02).of(0.2236)
    end

    it "samples the coverage interval within its bounds" do
      xml = om(app(oms("pmquant", "ucov"), omf(10.3), omf(9.9), omf(10.7)))
      result = Openmath.evaluate_stochastic(xml, samples: 500, seed: 3)

      expect(result.samples.min).to be_between(9.9, 10.7)
      expect(result.samples.max).to be_between(9.9, 10.7)
    end

    it "divides the expanded uncertainty by the coverage factor" do
      xml = om(app(oms("pmquant", "uexp"), omf(10.0), omf(0.5), omf(2)))
      result = Openmath.evaluate_stochastic(xml, samples: 2000, seed: 11)

      expect(result.standard_deviation).to be_within(0.015).of(0.25)
    end

    it "refuses unknown generators" do
      expect do
        Openmath.evaluate_stochastic(om(app(oms("pmquant", "ustd"), omf(1),
                                            omf(1))),
                                     samples: 10, seed: 1, generator: "lcg")
      end.to raise_error(Openmath::Evaluation::UnsupportedExpressionError, /generator/)
    end
  end
end
