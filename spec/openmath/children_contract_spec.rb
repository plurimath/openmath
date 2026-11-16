# frozen_string_literal: true

require "spec_helper"
require "json"
require "digest"
require "stringio"

RSpec.describe Openmath::Evaluation::Children do
  let(:namespace) { "http://www.openmath.org/OpenMath" }

  def parsed(body, version: 2)
    Openmath.parse(%(<OMOBJ xmlns="#{namespace}">#{body}</OMOBJ>), version: version)
  end

  def children(container)
    described_class.ordered(container)
  end

  [2, 3].each do |version|
    it "captures interleaved repeated and mixed-content children in version #{version}" do
      root = parsed('<OMA><OMS cd="arith1" name="minus"/><OMI>10</OMI><OMSTR>s</OMSTR><OMI>2</OMI><OMB>YQ==</OMB><OMV name="x"/></OMA>', version: version)
      application = children(root).first
      expect(children(application).map { |child| child.class.name.split("::").last })
        .to eq(%w[Oms Omi Omstr Omi Omb Omv])
      expect(Openmath::Evaluation::Evaluator.ordered_children(application)).to eq(children(application))
    end

    it "preserves nested noncommutative operands in version #{version}" do
      xml = %(<OMOBJ xmlns="#{namespace}"><OMA><OMS cd="arith1" name="minus"/><OMI>10</OMI><OMA><OMS cd="arith1" name="minus"/><OMI>4</OMI><OMI>1</OMI></OMA></OMA></OMOBJ>)
      expect(Openmath.evaluate(xml, version: version)).to eq(7)
    end
  end

  it "checks the owned corpus and its expected evaluation" do
    directory = File.expand_path("../../corpora/children", __dir__)
    manifest = JSON.parse(File.read(File.join(directory, "manifest.json")))
    manifest.fetch("files").each do |relative, checksum|
      path = File.join(directory, relative)
      expect(Digest::SHA256.file(path).hexdigest).to eq(checksum)
      expect(Openmath.evaluate(File.read(path))).to eq(manifest.fetch("expected"))
    end
  end

  it "captures order when parsing an IO source" do
    source = StringIO.new(%(<OMOBJ xmlns="#{namespace}"><OMI>7</OMI></OMOBJ>))
    expect(Openmath.evaluate(Openmath.parse(source))).to eq(7)
  end

  it "captures direct versioned model from_xml calls after registration" do
    Openmath::V2.register_models!
    application = Openmath::V2::Oma.from_xml(%(<OMA xmlns="#{namespace}"><OMI>1</OMI><OMV name="x"/><OMI>2</OMI></OMA>))
    expect(children(application).map { |child| child.class.name.split("::").last }).to eq(%w[Omi Omv Omi])
    expect(application.instance_variable_defined?(described_class::SLOT_VARIABLE)).to be(true)
  end

  it "uses namespace URIs rather than prefixes" do
    root = Openmath.parse(%(<o:OMOBJ xmlns:o="#{namespace}"><o:OMA><o:OMI>1</o:OMI><o:OMV name="a"/><o:OMI>2</o:OMI></o:OMA></o:OMOBJ>))
    expect(children(children(root).first).map { |child| child.class.name.split("::").last }).to eq(%w[Omi Omv Omi])
  end

  it "refuses foreign namespace children even when local names match" do
    expect { parsed('<OMI xmlns="urn:foreign">1</OMI>') }
      .to raise_error(Openmath::Evaluation::ChildrenOrderError, /urn:foreign.*OMI/)
  end

  it "treats OMFOREIGN as opaque" do
    root = parsed('<OMFOREIGN><x:thing xmlns:x="urn:foreign"><x:OMI>1</x:OMI></x:thing></OMFOREIGN>')
    expect(children(root).first).to be_a(Openmath::V2::Omforeign)
  end

  it "refuses a stale source slot after collection mutation" do
    root = parsed('<OMI>1</OMI>')
    root.omi_value << Openmath::V2::Omi.new(value: ["2"])
    expect { children(root) }.to raise_error(Openmath::Evaluation::ChildrenOrderError, /Omobj.*slots/)
  end

  it "requires explicit slots for builders lacking complete metadata" do
    root = Openmath::V2::Omobj.new
    value = Openmath::V2::Omi.new(value: ["3"])
    root.omi_value = [value]
    expect { Openmath.evaluate(root) }.to raise_error(Openmath::Evaluation::ChildrenOrderError, /Omobj.*slots/)
    described_class.assign(root, [value])
    expect(Openmath.evaluate(root)).to eq(3)
    expect { described_class.assign(root, [value, value]) }
      .to raise_error(Openmath::Evaluation::ChildrenOrderError, /slots/)
  end

  it "accepts complete element_order without source and refuses incomplete metadata" do
    root = parsed('<OMI>1</OMI><OMV name="x"/><OMI>2</OMI>')
    root.remove_instance_variable(described_class::SLOT_VARIABLE)
    order = Struct.new(:name)
    root.element_order = [order.new("OMI"), order.new("OMV"), order.new("OMI")]
    expect(children(root)).to eq([root.omi_value[0], root.omv_value[0], root.omi_value[1]])
    root.element_order = [order.new("OMI")]
    expect { children(root) }.to raise_error(Openmath::Evaluation::ChildrenOrderError, /slots/)
    expect { described_class.legacy_grouped(root) }.to raise_error(Openmath::Evaluation::ChildrenOrderError, /compatibility/)
    expect(described_class.legacy_grouped(root, compatibility: true)).to eq([*root.omv_value, *root.omi_value])
  end
end
