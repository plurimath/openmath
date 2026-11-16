# frozen_string_literal: true

require "spec_helper"

# OpenMath 2 parse and round-trip, driven by the schema and the SCSCP test
# object (spec/fixtures/scscp_example.om, vendored from OpenMath/py-openmath,
# MIT — an independent implementation's example, version="2.0", om-prefixed).
RSpec.describe Openmath do
  FIXTURE = File.expand_path("../../fixtures/scscp_example.om", __dir__)

  let(:xml) { File.read(FIXTURE) }
  let(:object) { described_class.parse(xml, version: 2) }

  it "parses the om-prefixed document with its version attribute" do
    expect(object).to be_a(Openmath::V2::Omobj)
    expect(object.version).to eq("2.0")
  end

  it "models the attributed object's alternating pairs in order" do
    omattr = object.omattr_value.first
    expect(omattr).to be_a(Openmath::V2::Omattr)
    omatp = omattr.omatp_value.first
    expect(omatp).to be_a(Openmath::V2::Omatp)
    expect(omatp.oms_value.map { |s| [s.cd, s.name] }).to eq(
      [
        ["scscp1", "call_id"],
        ["scscp1", "option_runtime"],
        ["scscp1", "option_min_memory"],
        ["scscp1", "option_max_memory"],
        ["scscp1", "option_debuglevel"],
        ["scscp1", "option_return_object"],
      ],
    )
    expect(omatp.omstr_value.first.value.first)
      .to eq("symcomp.org:26133:18668:s2sYf1pg")
    expect(omatp.omi_value.map { |i| i.value.first.strip }).to eq(
      %w[300000 40964 134217728 2],
    )
  end

  it "models nested applications" do
    omattr = object.omattr_value.first
    outer = omattr.oma_value.first
    expect(outer.oms_value.first.name).to eq("procedure_call")
    inner = outer.oma_value.first
    expect(inner.oms_value.first).to be_a(Openmath::V2::Oms)
    expect(inner.oma_value.first.oms_value.first.cd).to eq("group1")
  end

  it "round-trips the fixture byte-stably" do
    once = object.to_xml
    twice = described_class.parse(once, version: 2).to_xml
    expect(twice).to eq(once)
  end

  it "yields an empty object for input without an OMOBJ root" do
    # Root-element validation against the schema is roadmap work (#582);
    # Lutaml's reader is lenient about unknown roots.
    object = described_class.parse("<nope/>", version: 2)
    expect(object).to be_a(Openmath::V2::Omobj)
    expect(object.omi_value).to be_empty
  end

it "parses version 3 documents through the V3 hierarchy" do
  object = described_class.parse(xml, version: 3)
  expect(object).to be_a(Openmath::V3::Omobj)
  expect(object.version).to eq("2.0")
end

it "refuses an unsupported version" do
  expect { described_class.parse(xml, version: 9) }
    .to raise_error(ArgumentError, /unsupported OpenMath version/)
end

end
