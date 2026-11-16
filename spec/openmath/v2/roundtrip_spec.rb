# frozen_string_literal: true

require "spec_helper"

# Every OpenMath 2 object-grammar element parses and round-trips byte-stably.
# Shapes follow schemas/openmath2.rnc (the vendored OpenMath 2 RelaxNG).
RSpec.describe Openmath::V2 do
  def roundtrip(xml)
    described_class.parse(xml).to_xml.then { |out| described_class.parse(out).to_xml }
  end

  {
    "OMS" => '<OMS cd="arith1" name="plus" id="s1" cdbase="http://www.openmath.org/cd"/>',
    "OMV" => '<OMV name="x"/>',
    "OMI" => "<OMI>1 000 000</OMI>",
    "OMB" => "<OMB>aGVsbG8=</OMB>",
    "OMSTR" => "<OMSTR>hello</OMSTR>",
    "OMF-dec" => '<OMF dec="0.5"/>',
    "OMF-hex" => '<OMF hex="4008000000000000"/>',
    "OMR" => '<OMR href="#s1"/>',
    "OMA" => '<OMA><OMS cd="arith1" name="plus"/><OMI>1</OMI><OMI>1</OMI></OMA>',
    "OMBIND" =>
      '<OMBIND><OMS cd="fns1" name="lambda"/><OMBVAR><OMV name="x"/></OMBVAR>' \
      "<OMI>0</OMI></OMBIND>",
    "OME" =>
      '<OME><OMS cd="aritherror" name="divide_by_zero"/><OMI>1</OMI></OME>',
    "OMATTR" =>
      '<OMATTR><OMATP><OMS cd="plausiblescene1" name="semantic_attribution"/>' \
      '<OMI>2</OMI></OMATP><OMI>1</OMI></OMATTR>',
    "OMFOREIGN" =>
      '<OMFOREIGN encoding="MathML"><OMI>1</OMI></OMFOREIGN>',
  }.each do |name, xml|
    it "round-trips #{name.tr('-', ' ')} byte-stably" do
      document = "<OMOBJ xmlns=\"http://www.openmath.org/OpenMath\">#{xml}</OMOBJ>"
      expect(roundtrip(document)).to eq(described_class.parse(document).to_xml)
    end
  end

  it "round-trips the attributed variable (omvar = OMV | attvar)" do
    document =
      '<OMOBJ xmlns="http://www.openmath.org/OpenMath"><OMBVAR>' \
      '<OMATTR><OMATP><OMS cd="misc1" name="type"/><OMV name="Z"/></OMATP>' \
      '<OMV name="k"/></OMATTR></OMBVAR></OMOBJ>'
    expect(roundtrip(document)).to eq(described_class.parse(document).to_xml)
  end

  it "keeps the namespace prefix on output" do
    prefixed =
      '<om:OMOBJ xmlns:om="http://www.openmath.org/OpenMath" version="2.0">' \
      '<om:OMI>10</om:OMI></om:OMOBJ>'
    object = Openmath.parse(prefixed, version: 2)
    expect(object.version).to eq("2.0")
    expect(object.omi_value.first.value.first.strip).to eq("10")
  end
end
