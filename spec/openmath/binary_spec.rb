# frozen_string_literal: true

require "spec_helper"
require "base64"

# The OpenMath 2 binary encoding (omstd20): the vectors below come from the
# standard's own examples and tables; the corpus lane runs every CD-collection
# object through XML → model → binary → model → XML and demands a binary
# fixed point.
RSpec.describe Openmath::Binary do
  def om(body)
    %(<OMOBJ xmlns="http://www.openmath.org/OpenMath">#{body}</OMOBJ>)
  end

  def round_trip(body)
    described_class.decode(described_class.encode(om(body)))
  end

  def value_of(object, attribute)
    object.public_send(attribute).first
  end

  describe "integers" do
    {
      "-128" => "-128", "127" => "127", "128" => "128", "0" => "0",
      "-2147483648" => "-2147483648",
      "8589934592" => "8589934592",
      "-99999999999999999999" => "-99999999999999999999",
    }.each do |text, expected|
      it "decodes #{text} to its value" do
        expect(value_of(round_trip("<OMI>#{text}</OMI>"), :omi_value).value.first)
          .to eq(expected)
      end
    end

    it "keeps 300-digit integers exact" do
      digits = "9" * 300
      expect(value_of(round_trip("<OMI>#{digits}</OMI>"), :omi_value).value.first)
        .to eq(digits)
    end

    it "normalizes digit grouping to the integer's value" do
      expect(value_of(round_trip("<OMI>1 000 000</OMI>"), :omi_value).value.first)
        .to eq("1000000")
    end
  end

  it "encodes the standard's application example to a fixed point" do
    xml = om('<OMA><OMS cd="arith1" name="times"/>' \
             '<OMA><OMS cd="arith1" name="plus"/><OMV name="x"/><OMV name="y"/></OMA>' \
             '<OMA><OMS cd="arith1" name="plus"/><OMV name="x"/><OMV name="z"/></OMA></OMA>')
    bytes = described_class.encode(xml)
    decoded = described_class.decode(bytes).to_xml

    expect(described_class.encode(Openmath.parse(decoded, version: 2))).to eq(bytes)
  end

  it "round-trips IEEE floats" do
    object = round_trip(%(<OMF dec="0.1"/>))

    expect(value_of(object, :omf_value).dec.to_f).to eq(0.1)
  end

  it "round-trips utf-16 strings through the two-byte tags" do
    expect(value_of(round_trip("<OMSTR>héllo wörld</OMSTR>"), :omstr_value).value.first)
      .to eq("héllo wörld")
  end

  it "round-trips byte arrays" do
    object = round_trip("<OMB>aGVsbG8=</OMB>")

    expect(Base64.decode64(value_of(object, :omb_value).value.first)).to eq("hello")
  end

  it "round-trips foreign objects with encoding and payload" do
    xml = om('<OME><OMS cd="error" name="annotation"/>' \
             '<OMFOREIGN encoding="MathML-Content">' \
             '<math xmlns="http://www.w3.org/1998/Math/MathML"><ci>y</ci></math>' \
             "</OMFOREIGN></OME>")
    object = described_class.decode(described_class.encode(xml))
    foreign = object.ome_value.first.omforeign_value.first

    expect(foreign.foreign_encoding).to eq("MathML-Content")
    expect(foreign.notom_value.first)
      .to include('<math xmlns="http://www.w3.org/1998/Math/MathML"><ci>y</ci></math>')
  end

  describe "references" do
    it "shares the referenced target and reconstructs the reference" do
      object = round_trip('<OMA><OMS cd="arith1" name="plus"/>' \
                          '<OMI id="t">6</OMI><OMR href="#t"/></OMA>')

      application = object.oma_value.first
      expect(value_of(application, :omi_value).id).to eq("omr-0")
      expect(value_of(application, :omr_value).href).to eq("#omr-0")
      expect(described_class.decode(described_class.encode(object.to_xml)).to_xml)
        .to eq(object.to_xml)
    end

    it "refuses references to unshared targets" do
      bytes = [0x58, 0x02, 0x00, 0x1E, 0x00].pack("C*")

      expect { described_class.decode(bytes) }
        .to raise_error(Openmath::Binary::Error, /internal reference 0 exceeds/)
    end

    it "refuses forward references at write time" do
      xml = om("<OMR href=\"#later\"/><OMI id=\"later\">1</OMI>")

      expect { described_class.encode(xml) }
        .to raise_error(Openmath::Binary::Error, /forward reference/)
    end
  end

  it "round-trips attributions, bindings and errors" do
    attributed = round_trip('<OMATTR><OMATP><OMS cd="misc" name="def"/><OMI>1</OMI></OMATP>' \
                            '<OMA><OMS cd="arith1" name="abs"/><OMI id="q">7</OMI></OMA></OMATTR>')
    expect(value_of(attributed.omattr_value.first.omatp_value.first, :omi_value).value.first)
      .to eq("1")

    binder = round_trip('<OMBIND><OMS cd="fns1" name="lambda"/><OMBVAR><OMV name="x"/></OMBVAR>' \
                        '<OMA><OMS cd="arith1" name="abs"/><OMV name="x"/></OMA></OMBIND>')
    expect(binder.ombind_value.first.ombvar_value.first.omv_value.first.name).to eq("x")

    error = round_trip('<OME><OMS cd="aritherror" name="divide_by_zero"/><OMI>1</OMI></OME>')
    expect(error.ome_value.first.oms_value.first.name).to eq("divide_by_zero")
  end

  it "uses the plain framing for objects without a version" do
    object = Openmath.parse(om("<OMI>5</OMI>"), version: 2)
    object.version = nil
    bytes = described_class.encode(object)

    expect(bytes.getbyte(0)).to eq(24)
    expect(described_class.decode(bytes).omi_value.first.value.first).to eq("5")
  end

  describe "refusals" do
    it "refuses truncation typed" do
      expect { described_class.decode([0x58, 0x02, 0x00, 0x10].pack("C*")) }
        .to raise_error(Openmath::Binary::Error, /truncated/)
    end

    it "refuses an unknown framing tag" do
      expect { described_class.decode([0x00].pack("C*")) }
        .to raise_error(Openmath::Binary::Error, /object start tag/)
    end

    it "refuses trailing bytes" do
      bytes = described_class.encode(om("<OMI>5</OMI>")) + "\x00"

      expect { described_class.decode(bytes) }
        .to raise_error(Openmath::Binary::Error, /trailing bytes/)
    end

    it "refuses an empty big integer" do
      bytes = [0x58, 0x02, 0x00, 0x02, 0x00].pack("C*")

      expect { described_class.decode(bytes) }
        .to raise_error(Openmath::Binary::Error, /sign\/base byte/)
    end
  end
end
