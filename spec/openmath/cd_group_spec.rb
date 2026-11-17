# frozen_string_literal: true

require "spec_helper"

RSpec.describe Openmath::CD::GroupCollection do
  let(:root) { File.expand_path("../fixtures/cdgroup", __dir__) }
  let(:group_source) { File.join(root, "testgroup.cdg") }

  it "parses the group document with its pinned members" do
    group = Openmath.parse_cdgroup(File.read(group_source))

    expect(group.name).to eq("testgroup")
    expect(group.group_version).to eq("2")
    expect(group.group_revision).to eq("1")
    expect(group.member_value.map(&:cd_name)).to eq(%w[mycd1 mycd2])
    expect(group.member_value.map(&:cd_version)).to eq(%w[1 3])
    expect(group.member_value.last.comment).to include("pins its revision")
  end

  it "validates group documents against the group schema" do
    expect(Openmath::CD::Group.valid?(File.read(group_source))).to be(true)
    expect { Openmath.validate_cdgroup!(File.read(group_source)) }.not_to raise_error

    broken = File.read(group_source).gsub("<CDGroupVersion>2</CDGroupVersion>",
                                          "<CDVersion>2</CDVersion>")
    expect(Openmath::CD::Group.valid?(broken)).to be(false)
    expect { Openmath.validate_cdgroup!(broken) }
      .to raise_error(Openmath::Validation::ValidationError)
  end

  it "loads members from a local root and resolves through the pins" do
    pinned = described_class.load(group_source, root: root)

    expect(pinned.pins).to eq("mycd1" => "1", "mycd2" => "3")
    expect(pinned.group.name).to eq("testgroup")
    expect(pinned.collection.size).to eq(2)
    expect(pinned.resolve(cd: "mycd1", name: "sym")).to be_a(Openmath::CD::Definition)
    expect(pinned.resolve(cd: "unknown-cd", name: "sym")).to be_nil
  end

  it "refuses a loaded revision contradicting the pin, naming both" do
    collection = Openmath::CD::Collection.new.load(root)
    # Corrupt the loaded copy of mycd1 so its version contradicts the pin.
    collection.documents.each do |document|
      document.cd_version = "9" if document.cd_name == "mycd1"
    end

    expect do
      described_class.load(group_source, collection: collection)
    end.to raise_error(
      described_class::VersionMismatchError,
      /mycd1.*pins "1".*loaded "9"/,
    )
  end

  it "refuses members no loader could find" do
    group = File.read(group_source).sub("mycd2", "ghostcd")

    expect do
      described_class.load(group, root: root)
    end.to raise_error(described_class::MemberNotFoundError, /ghostcd/)
  end

  it "resolves a mismatching pinned dictionary through the typed refusal" do
    pinned = described_class.load(group_source, root: root)
    pinned.collection.documents.each do |document|
      document.cd_version = "42" if document.cd_name == "mycd2"
    end

    expect do
      pinned.resolve(cd: "mycd2", name: "other")
    end.to raise_error(
      described_class::VersionMismatchError,
      /mycd2.*pins "3".*loaded "42"/,
    )
  end
end
