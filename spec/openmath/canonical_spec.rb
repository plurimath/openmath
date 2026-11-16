# frozen_string_literal: true

require "spec_helper"

RSpec.describe Openmath::Canonical do
  let(:plus) do
    Openmath.parse(
      '<OMOBJ xmlns="http://www.openmath.org/OpenMath">' \
      '<OMA><OMS cd="arith1" name="plus"/><OMI>1</OMI><OMI>2</OMI></OMA>' \
      "</OMOBJ>",
      version: 2,
    )
  end

  it "emits a single default namespace declaration on the root" do
    canonical = plus.to_canonical_xml

    expect(canonical).to start_with(
      '<OMOBJ xmlns="http://www.openmath.org/OpenMath">',
    )
    expect(canonical.scan("xmlns").size).to eq(1)
    expect(canonical).not_to include("\n")
  end

  it "is invariant under prefix choice" do
    prefixed = Openmath.parse(
      '<om:OMOBJ xmlns:om="http://www.openmath.org/OpenMath">' \
      "<om:OMA><om:OMS om:cd=\"arith1\" om:name=\"plus\"/>" \
      "<om:OMI>1</om:OMI><om:OMI>2</om:OMI></om:OMA></om:OMOBJ>",
      version: 2,
    )

    expect(prefixed.to_canonical_xml).to eq(plus.to_canonical_xml)
  end

  it "is invariant under whitespace between elements and inside OMI/OMB" do
    spaced = Openmath.parse(
      <<~XML,
        <OMOBJ xmlns="http://www.openmath.org/OpenMath">
          <OMA>
            <OMS cd="arith1" name="plus" />
            <OMI>
              1
            </OMI>
            <OMI>2</OMI>
          </OMA>
        </OMOBJ>
      XML
      version: 2,
    )

    expect(spaced.to_canonical_xml).to eq(plus.to_canonical_xml)
  end

  it "orders attributes canonically" do
    object = Openmath.parse(
      '<OMOBJ xmlns="http://www.openmath.org/OpenMath">' \
      '<OMS cd="nums1" name="rational" cdbase="http://example.org" id="s1"/>' \
      "</OMOBJ>",
      version: 2,
    )

    expect(object.to_canonical_xml).to include(
      '<OMS cdbase="http://example.org" cd="nums1" id="s1" name="rational"/>',
    )
  end

  it "keeps OMSTR text verbatim" do
    object = Openmath.parse(
      '<OMOBJ xmlns="http://www.openmath.org/OpenMath">' \
      "<OMSTR>  spaced  text </OMSTR></OMOBJ>",
      version: 2,
    )

    expect(object.to_canonical_xml).to include("<OMSTR>  spaced  text </OMSTR>")
  end

  it "preserves OMF dec spellings" do
    object = Openmath.parse(
      '<OMOBJ xmlns="http://www.openmath.org/OpenMath">' \
      '<OMF dec="1.5"/></OMOBJ>',
      version: 2,
    )

    expect(object.to_canonical_xml).to include('<OMF dec="1.5"/>')
  end

  it "hashes stably across parse cycles and versions" do
    [2, 3].each do |version|
      object = Openmath.parse(plus.to_xml, version: version)
      expect(object.canonical_sha256).to eq(plus.canonical_sha256)
    end
  end

  it "includes foreign fragments in the canonical form" do
    xml = '<OMOBJ xmlns="http://www.openmath.org/OpenMath"><OME>' \
          '<OMS cd="error" name="annotation"/>' \
          '<OMFOREIGN encoding="X">' \
          '<math xmlns="http://www.w3.org/1998/Math/MathML"><ci>y</ci></math>' \
          "</OMFOREIGN></OME></OMOBJ>"
    object = Openmath.parse(xml, version: 2)
    reparsed = Openmath.parse(object.to_xml, version: 2)

    expect(object.to_canonical_xml).to include(
      '<math xmlns="http://www.w3.org/1998/Math/MathML"><ci>y</ci></math>',
    )
    expect(reparsed.canonical_sha256).to eq(object.canonical_sha256)
  end

  describe "Openmath.canonical_equal?" do
    it "is true for syntactic variants of one object" do
      variant = Openmath.parse(
        '<om:OMOBJ xmlns:om="http://www.openmath.org/OpenMath">' \
        "<om:OMA><om:OMS om:name=\"plus\" om:cd=\"arith1\"/>" \
        "<om:OMI> 1 </om:OMI><om:OMI>2</om:OMI></om:OMA></om:OMOBJ>",
        version: 2,
      )

      expect(Openmath.canonical_equal?(plus, variant)).to be(true)
    end

    it "is false for different objects" do
      other = Openmath.parse(
        '<OMOBJ xmlns="http://www.openmath.org/OpenMath">' \
        '<OMA><OMS cd="arith1" name="plus"/><OMI>1</OMI><OMI>3</OMI></OMA>' \
        "</OMOBJ>",
        version: 2,
      )

      expect(Openmath.canonical_equal?(plus, other)).to be(false)
    end

    it "treats ids as data" do
      with_id = Openmath.parse(
        '<OMOBJ xmlns="http://www.openmath.org/OpenMath">' \
        '<OMA id="x"><OMS cd="arith1" name="plus"/><OMI>1</OMI><OMI>2</OMI>' \
        "</OMA></OMOBJ>",
        version: 2,
      )

      expect(Openmath.canonical_equal?(plus, with_id)).to be(false)
    end
  end
end
