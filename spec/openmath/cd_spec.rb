# frozen_string_literal: true

require "spec_helper"

# Stage 2: the content-dictionary pipeline. The CD documents load as data
# (the fixture set is vendored from OpenMath/CDs cd/Official; provenance in
# the collection loader), symbols resolve, and malformed CDs refuse.
RSpec.describe Openmath::CD do
  FIXTURES = File.expand_path("../fixtures/cds", __dir__)

  it "parses a CD document into its typed model" do
    document = Openmath.parse_cd(File.read(File.join(FIXTURES, "arith1.ocd")))
    expect(document.cd_name).to eq("arith1")
    expect(document.cd_base).to eq("http://www.openmath.org/cd")
    expect(document.cd_status).to eq("official")
    expect(document.symbol_names.first).to eq("lcm")
  end

  it "models the formal properties as OpenMath objects" do
    document = Openmath.parse_cd(File.read(File.join(FIXTURES, "arith1.ocd")))
    lcm = document.definition_for("lcm")
    expect(lcm.role).to eq("application")
    expect(lcm.cmp_value.join).to include("gcd(a,b)")
    head = lcm.fmp_objects.first.oma_value.first
    expect(head.oms_value.first.cd).to eq("relation1")
    expect(head.oms_value.first.name).to eq("eq")
    expect(head.oma_value.size).to eq(2)
  end

  it "validates CD documents against omcd2.rng" do
    expect(described_class::Collection.validate(
      File.read(File.join(FIXTURES, "arith1.ocd")),
    )).to be_empty
    expect do
      described_class::Collection.validate!("<CD><CDName>x</CDName></CD>")
    end.to raise_error(Openmath::Validation::ValidationError)
  end

  describe "a collection" do
    let(:collection) do
      described_class::Collection.new.load(FIXTURES)
    end

    it "loads every .ocd file in a directory" do
      expect(collection.size).to eq(Dir[File.join(FIXTURES, "*.ocd")].size)
    end

    it "resolves a symbol to its definition" do
      resolved = collection.resolve(cd: "nums1", name: "rational")
      expect(resolved).to be_a(described_class::Definition)
      expect(resolved.name).to eq("rational")
    end

    it "returns nil for an unbound symbol and never guesses" do
      expect(collection.resolve(cd: "nums1", name: "nosuch")).to be_nil
      expect(collection.resolve(cd: "nosuchcd", name: "plus")).to be_nil
    end

    it "honors the cdbase when both sides declare one" do
      expect(collection.resolve(cd: "arith1", name: "plus",
                                cdbase: "http://www.openmath.org/cd")).to be_a(described_class::Definition)
      expect(collection.resolve(cd: "arith1", name: "plus",
                                cdbase: "http://elsewhere.example/cd")).to be_nil
    end

    it "loads the document's own embedded objects back through the object model" do
      plus = collection.resolve(cd: "arith1", name: "plus")
      objects = plus.fmp_objects + plus.example_objects
      expect(objects).not_to be_empty
      objects.each do |object|
        expect(object).to be_a(Openmath::V2::Omobj)
      end
    end
  end

describe "the full official collection" do
  it "loads every official CD" do
    root = ENV.fetch("OPENMATH_CDS_REF") do
      skip "set OPENMATH_CDS_REF to a CDs checkout"
    end

      collection = described_class::Collection.new.load(File.join(root, "cd/Official"))
      expect(collection.size).to be > 90
      arith1 = collection["arith1"]
      expect(arith1.definition_for("plus")).to be_a(described_class::Definition)
    end
  end
end
