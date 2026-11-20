# frozen_string_literal: true

require "spec_helper"

# Schema validation against the vendored RelaxNG schemas
# (schemas/PROVENANCE.md records their sources). Validation is always
# available: Openmath.valid? and Openmath.validate! work without parsing.
RSpec.describe Openmath do
  NS = 'xmlns="http://www.openmath.org/OpenMath"'

  it "accepts a well-formed OM2 object" do
    expect(described_class.valid?(<<~XML, version: 2)).to be(true)
      <OMOBJ #{NS} version="2.0">
        <OMA><OMS cd="arith1" name="plus"/><OMI>1</OMI><OMI>1</OMI></OMA>
      </OMOBJ>
    XML
  end

  it "accepts an om-prefixed document" do
    expect(described_class.valid?(<<~XML, version: 2)).to be(true)
      <om:OMOBJ xmlns:om="http://www.openmath.org/OpenMath">
        <om:OMV name="x"/>
      </om:OMOBJ>
    XML
  end

  it "refuses a foreign root, naming the expectation" do
    expect(described_class.valid?("<nope/>", version: 2)).to be(false)
    expect { described_class.validate!("<nope/>", version: 2) }
      .to raise_error(
        Openmath::Validation::ValidationError,
        /element "nope" not allowed anywhere; expected element "OMOBJ"/,
      )
  end

  it "refuses an OMF carrying both dec and hex" do
    xml = "<OMOBJ #{NS}><OMF dec=\"0.5\" hex=\"A\"/></OMOBJ>"
    expect { described_class.validate!(xml, version: 2) }
      .to raise_error(Openmath::Validation::ValidationError, /attribute combination matches no branch/
  end

  it "refuses an OME without a leading symbol" do
    xml = "<OMOBJ #{NS}><OME><OMI>1</OMI></OME></OMOBJ>"
    expect(described_class.valid?(xml, version: 2)).to be(false)
  end

  it "refuses a bad base64 byte array" do
    skip "leptris#2080: an attribute-prefixed <data> leaf skips the lexical check"
    xml = "<OMOBJ #{NS}><OMB>not-base64!!!</OMB></OMOBJ>"
    expect(described_class.valid?(xml, version: 2)).to be(false)
  end

  it "validates against the OM3 draft schema" do
    expect(described_class.valid?(<<~XML, version: 3)).to be(true)
      <OMOBJ #{NS} version="3.0">
        <OMBIND>
          <OMS cd="fns1" name="lambda"/>
          <OMBVAR><OMV name="x"/></OMBVAR>
          <OMA><OMS cd="arith1" name="times"/><OMV name="x"/><OMI>2</OMI></OMA>
        </OMBIND>
      </OMOBJ>
    XML
  end

  it "refuses an unsupported version" do
    expect { described_class.valid?("<OMOBJ/>", version: 9) }
      .to raise_error(ArgumentError, /unsupported OpenMath version/)
  end

  it "carries every violation, not only the first" do
    xml = "<OMOBJ #{NS}><OMF dec=\"0.5\" hex=\"A\"/><OMF dec=\"x\"/></OMOBJ>"
    expect { described_class.validate!(xml, version: 2) }
      .to raise_error do |error|
        expect(error).to be_a(Openmath::Validation::ValidationError)
        expect(error.errors.size).to be >= 2
      end
  end
end
