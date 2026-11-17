# frozen_string_literal: true

require "spec_helper"

RSpec.describe Openmath::Foreign do
  let(:mathml) do
    '<math xmlns="http://www.w3.org/1998/Math/MathML" display="block">' \
      "<apply><plus/><ci>x</ci></apply></math>"
  end
  let(:svg) { '<svg xmlns="http://www.w3.org/2000/svg"><circle r="1"/></svg>' }

  # OMFOREIGN is legal inside OME (and OMATP); OMOBJ and OMA take only omel.
  def object_with_foreign(inner, version: 2)
    <<~XML
      <OMOBJ xmlns="http://www.openmath.org/OpenMath">
        <OME>
          <OMS cd="error" name="annotation"/>
          <OMFOREIGN id="f1" encoding="MathML-Content">#{inner}</OMFOREIGN>
        </OME>
      </OMOBJ>
    XML
  end

  def first_foreign(object)
    candidates = described_class.children(object).select do |child|
      described_class.send(:omforeign?, child)
    end
    candidates.first || described_class.children(object)
      .filter_map { |child| first_foreign(child) }.first
  end

  it "captures foreign markup verbatim" do
    object = Openmath.parse(object_with_foreign(mathml), version: 2)
    foreign = first_foreign(object)

    expect(foreign.notom_value).to eq([mathml])
    expect(foreign.notom_positions).to eq([0])
  end

  it "captures interleaved foreign and OpenMath children in document order" do
    inner = "#{mathml}<OMI>5</OMI>#{svg}<OMSTR>tail</OMSTR>"
    object = Openmath.parse(object_with_foreign(inner), version: 2)
    foreign = first_foreign(object)

    expect(foreign.notom_value).to eq([mathml, svg])
    expect(foreign.notom_positions).to eq([0, 1])
    expect(foreign.omi_value.map { |v| v.value.first.strip }).to eq(["5"])
    expect(foreign.omstr_value.first.value.first.strip).to eq("tail")
  end

  it "re-serializes foreign fragments at their captured positions" do
    inner = "#{mathml}<OMI>5</OMI>#{svg}"
    output = Openmath.parse(object_with_foreign(inner), version: 2).to_xml

    math_index = output.index(mathml)
    omi_index = output.index("<OMI>")
    svg_index = output.index(svg)
    expect(math_index).to be < omi_index
    expect(omi_index).to be < svg_index
  end

  it "round-trips stably through parse and serialization" do
    inner = "#{mathml}<OMI>5</OMI>#{svg}"
    first = Openmath.parse(object_with_foreign(inner), version: 2).to_xml
    second = Openmath.parse(first, version: 2).to_xml

    expect(second).to eq(first)
  end

  it "round-trips stably under version 3" do
    inner = %(<html xmlns="http://www.w3.org/1999/xhtml"><b>bold</b></html>)
    first = Openmath.parse(object_with_foreign(inner, version: 3), version: 3).to_xml
    second = Openmath.parse(first, version: 3).to_xml

    expect(second).to eq(first)
    expect(first_foreign(Openmath.parse(first, version: 3)).notom_value)
      .to eq([inner])
  end

  it "captures foreign markup alongside OpenMath siblings" do
    inner = %(<div xmlns="http://www.w3.org/1999/xhtml"><p>text</p></div><OMI>7</OMI>)
    object = Openmath.parse(object_with_foreign(inner), version: 2)
    foreign = first_foreign(object)

    expect(foreign.notom_value).to eq(
      ['<div xmlns="http://www.w3.org/1999/xhtml"><p>text</p></div>'],
    )
    expect(foreign.omi_value.map { |v| v.value.first.strip }).to eq(["7"])
  end

  it "validates a foreign-carrying document against the schema" do
    xml = object_with_foreign(mathml)

    expect(Openmath.valid?(xml, version: 2)).to be(true)
  end

  it "leaves objects without foreign markup untouched" do
    xml = <<~XML
      <OMOBJ xmlns="http://www.openmath.org/OpenMath">
        <OMA><OMS cd="arith1" name="plus"/><OMI>1</OMI><OMI>2</OMI></OMA>
      </OMOBJ>
    XML
    object = Openmath.parse(xml, version: 2)

    expect(object.to_xml).to eq(Openmath.parse(xml, version: 2).to_xml)
    expect(described_class.contained?(object)).to be(false)
  end

  it "serializes a standalone OMFOREIGN with its fragments" do
    object = Openmath.parse(object_with_foreign(mathml), version: 2)
    output = first_foreign(object).to_xml

    expect(output).to include(mathml)
    expect(output).to include("<OMFOREIGN")
  end

  it "reports contained? for objects carrying fragments" do
    object = Openmath.parse(object_with_foreign(mathml), version: 2)

    expect(described_class.contained?(object)).to be(true)
  end
end
