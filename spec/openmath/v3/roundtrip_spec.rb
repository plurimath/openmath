# frozen_string_literal: true

require "spec_helper"

# The OpenMath 3 hierarchy parses and round-trips the same object grammar
# (the OM3 draft schema, schemas/openmath3.rng, is the OM2 shape; the
# versioned hierarchy carries the distinction).
RSpec.describe Openmath::V3 do
  NS = 'xmlns="http://www.openmath.org/OpenMath"'

  def roundtrip(xml)
    described_class.parse(xml).to_xml.then do |out|
      described_class.parse(out).to_xml
    end
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
      document = "<OMOBJ #{NS} version=\"3.0\">#{xml}</OMOBJ>"
      expect(roundtrip(document)).to eq(described_class.parse(document).to_xml)
    end
  end

  it "keeps V3 objects apart from V2 objects" do
    xml = "<OMOBJ #{NS}><OMI>1</OMI></OMOBJ>"
    expect(described_class.parse(xml)).to be_a(Openmath::V3::Omobj)
    expect(Openmath::V2.parse(xml)).to be_a(Openmath::V2::Omobj)
    expect(described_class.parse(xml)).not_to eq(Openmath::V2.parse(xml))
  end
end
