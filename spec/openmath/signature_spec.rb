# frozen_string_literal: true

require "spec_helper"

# The STS layer: the official CD collection's signature files load and
# index, well-signed applications pass, and a documented violation
# refuses with the signature named.
RSpec.describe Openmath::CD::Signatures do
  let(:sts_dir) { File.expand_path("../fixtures/sts", __dir__) }
  let(:signatures) do
    described_class.load(
      File.join(sts_dir, "arith1.sts"),
      File.join(sts_dir, "relation1.sts"),
    )
  end

  def om(body)
    %(<OMOBJ xmlns="http://www.openmath.org/OpenMath">#{body}</OMOBJ>)
  end

  def app(cd, name, *args)
    om("<OMA><OMS cd=\"#{cd}\" name=\"#{name}\"/>#{args.join}</OMA>")
  end

  def omi(n) = "<OMI>#{n}</OMI>"

  it "loads the official signature files and indexes per symbol" do
    expect(signatures.size).to eq(2)
    expect(signatures.lookup("arith1", "plus")).to be_a(Openmath::V2::Omobj)
    expect(signatures.lookup("relation1", "eq")).to be_a(Openmath::V2::Omobj)
    expect(signatures.lookup("arith1", "unsigned_symbol")).to be_nil
  end

  it "records the signed cd and signature type" do
    document = signatures.documents.first

    expect(document.cd).to eq("arith1")
    expect(document.signature_type).to eq("sts")
    expect(document.signature_value.map(&:name)).to include("plus", "lcm", "gcd")
  end

  it "passes well-signed applications" do
    expect(Openmath.evaluate(app("arith1", "plus", omi(1), omi(2)), signatures: signatures))
      .to eq(3)
  end

  it "refuses plus(1, true) with the signature named" do
    expect do
      Openmath.evaluate(app("arith1", "plus", omi(1), "<OMV name=\"t\"/>"),
                        variables: { t: true }, signatures: signatures)
    end.to raise_error(
      Openmath::Evaluation::SignatureViolationError,
      /signature violation for arith1#plus.*argument 2 \(true\).*carrier/,
    )
  end

  it "refuses arity violations naming the declared count" do
    expect do
      Openmath.evaluate(app("relation1", "eq", omi(1)), signatures: signatures)
    end.to raise_error(
      Openmath::Evaluation::SignatureViolationError,
      /relation1#eq.*declares 3 argument\(s\), the application has 1/,
    )
  end

  it "checks setname domains" do
    expect do
      Openmath.evaluate(app("relation1", "lt", omi(1), omi(2)), signatures: signatures)
    end.not_to raise_error
  end

  it "stays advisory for unsigned symbols" do
    expect(Openmath.evaluate(app("list1", "list", omi(1)), signatures: signatures))
      .to eq([1])
  end

  it "never checks without supplied signatures" do
    expect(Openmath.evaluate(app("arith1", "plus", omi(1), omi(2)))).to eq(3)
  end

  it "keeps rationals exact through a checked application" do
    rational = "<OMA><OMS cd=\"nums1\" name=\"rational\"/><OMI>1</OMI><OMI>4</OMI></OMA>"
    expect(Openmath.evaluate(app("arith1", "plus", rational, rational),
                             signatures: signatures))
      .to eq(Rational(1, 2))
  end
end
