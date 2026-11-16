# frozen_string_literal: true

require "spec_helper"
require "openmath/cd/group"
require "tmpdir"
require "fileutils"

RSpec.describe Openmath::CD::Group do
  before(:context) { @official = Openmath::CD::Group.official }
  let(:collection) { @official }
  let(:root) { described_class::ROOT }
  let(:arith_xml) { File.read(File.join(root, "data/cd-groups/arith.cdg")) }

  it "parses authoritative legacy groups into LutaML models" do
    group = described_class.parse(arith_xml)
    expect(group).to be_a(described_class::Document)
    expect([group.name, group.version, group.revision]).to eq(%w[arith 2 0])
    expect(group.members.map(&:cd_name)).to eq(%w[arith1 arith2])
    expect(described_class.parse(group.to_xml).members.map(&:cd_name)).to eq(%w[arith1 arith2])
  end

  it "validates against the checked official grammar and rejects unknown fields" do
    expect { described_class.parse(arith_xml.sub("</CDGroup>", "<CDRevision>5</CDRevision></CDGroup>")) }
      .to raise_error(described_class::InvalidGroup, /CDRevision/)
    expect { described_class.parse(arith_xml.sub('version="2.0"', 'version="9.0"')) }
      .to raise_error(described_class::InvalidGroup, /version/)
    expect { described_class.parse("<CDGroup>") }
      .to raise_error(described_class::InvalidGroup, /CDGroup/)
  end

  it "rejects entity declarations without reading external resources" do
    xml = '<!DOCTYPE CDGroup [<!ENTITY x SYSTEM "file:///etc/passwd">]>' + arith_xml
    expect { described_class.parse(xml) }.to raise_error(described_class::InvalidGroup, /DTD/)
  end

  it "checks the complete pinned source inventory" do
    expect(collection.artifacts.check!).to be(true)
    manifest = JSON.parse(File.read(File.join(root, "data/cd-groups/manifest.json")))
    expect(manifest.fetch("commit")).to eq("cbf607561e3f90630ce7a57fe9a85f5bc0dfdd3c")
    expect(collection.size).to eq(38)
    expect(collection.verify!).to be(true)
  end

  it "acquires recorded members locally and resolves exact identities" do
    group = collection.group("fns")
    expect(collection.members(group).map(&:cd_name)).to eq(%w[fns1 fns2])
    document = collection["arith1"]
    expect(collection.resolve(cd: "arith1", name: "plus", version: document.cd_version,
                              revision: document.cd_revision).name).to eq("plus")
    expect(collection.resolve(cd: "arith1", name: "absent_symbol")).to be_nil
  end

  it "names requested and available revisions on mismatch, including base and version" do
    document = collection["arith1"]
    expect { collection.fetch(cd: "arith1", revision: "999") }
      .to raise_error(described_class::IdentityMismatch, /999.*#{document.cd_revision}/)
    expect { collection.fetch(cd: "arith1", version: "999") }
      .to raise_error(described_class::IdentityMismatch, /999/)
    expect { collection.fetch(cd: "arith1", cdbase: "https://elsewhere.invalid/cd") }
      .to raise_error(described_class::IdentityMismatch, /elsewhere.*http:\/\/www.openmath.org/)
  end

  it "refuses unrecorded groups and absent members rather than fetching URLs" do
    expect { collection.group("not_recorded") }
      .to raise_error(described_class::MissingMember, /not_recorded/)
    group = described_class.parse(arith_xml.sub("arith2</CDName>", "absent_cd</CDName>"))
    expect { collection.members(group) }
      .to raise_error(described_class::IdentityMismatch, /absent_cd/)
  end

  it "refuses includes explicitly instead of silently dropping group dependencies" do
    xml = arith_xml.sub("</CDGroup>", "<CDGroupInclude>https://example.invalid/g.cdg</CDGroupInclude></CDGroup>")
    expect { collection.members(described_class.parse(xml)) }
      .to raise_error(described_class::UnsupportedInclude, /example.invalid/)
  end

  it "refuses a mismatched member URL with the local revision in the diagnostic" do
    group = described_class.parse(arith_xml.sub("cd/arith1.ocd", "cd/not_arith1.ocd"))
    expect { collection.members(group) }
      .to raise_error(described_class::IdentityMismatch, /arith1.*not_arith1.*revision/)
  end

  # These local test inventories deliberately change revision metadata. They are
  # synthetic fixtures, never presented as official or mixed into shipped data.
  def local_inventory
    Dir.mktmpdir("openmath-cd-groups") do |directory|
      path = "arith1.ocd"
      xml = File.read(File.join(root, "data/cds/arith1.ocd"))
      original = collection.artifacts.records.find { |r| r["name"] == "arith1" }
      record = original.merge("path" => path)
      File.write(File.join(directory, path), xml)
      records = [record]
      yield directory, records, xml
    end
  end

  def artifacts_at(directory, records)
    File.write(File.join(directory, "manifest.json"), JSON.generate("artifacts" => records))
    described_class::Artifacts.new(root: directory, manifest: "manifest.json")
  end

  it "retains two revisions and refuses ambiguous resolution" do
    local_inventory do |directory, records, xml|
      changed = xml.sub(/<CDRevision>.*?<\/CDRevision>/m, "<CDRevision>999</CDRevision>")
      File.write(File.join(directory, "revision999.ocd"), changed)
      records << records.first.merge("path" => "revision999.ocd", "revision" => "999",
                                     "sha256" => Digest::SHA256.hexdigest(changed))
      pinned = described_class::PinnedCollection.new(artifacts: artifacts_at(directory, records))
      expect(pinned.fetch(cd: "arith1", revision: "999").cd_revision).to eq("999")
      expect(pinned.fetch(cd: "arith1", revision: records.first["revision"]).cd_revision)
        .to eq(records.first["revision"])
      expect { pinned["arith1"] }.to raise_error(described_class::AmbiguousRevision, /999/)
    end
  end

  it "refuses duplicate exact identities without overwriting either entry" do
    local_inventory do |directory, records, xml|
      File.write(File.join(directory, "duplicate.ocd"), xml)
      records << records.first.merge("path" => "duplicate.ocd")
      expect { described_class::PinnedCollection.new(artifacts: artifacts_at(directory, records)) }
        .to raise_error(described_class::DuplicateRevision, /revisions/)
    end
  end

  it "checks claimed identity independently of a valid checksum" do
    local_inventory do |directory, records, _xml|
      records.first["revision"] = "999"
      pinned = described_class::PinnedCollection.new(artifacts: artifacts_at(directory, records))
      expect { pinned.fetch(cd: "arith1", revision: "999") }
        .to raise_error(described_class::IdentityMismatch, /expected.*999.*actual/)
    end
  end

  it "refuses modified and missing local artifacts by name" do
    local_inventory do |directory, records, _xml|
      artifacts = artifacts_at(directory, records)
      File.write(File.join(directory, "arith1.ocd"), "corrupted")
      expect { artifacts.read("arith1.ocd") }
        .to raise_error(described_class::IntegrityError, /arith1.ocd.*SHA256/)
      FileUtils.rm(File.join(directory, "arith1.ocd"))
      expect { artifacts.read("arith1.ocd") }
        .to raise_error(described_class::MissingMember, /arith1.ocd/)
    end
  end

  it "refuses traversal, network paths and symlinks escaping the acquisition root" do
    local_inventory do |directory, records, _xml|
      artifacts = artifacts_at(directory, records)
      ["../secret", "/absolute", "https://example.invalid/a"].each do |path|
        expect { artifacts.local_path(path) }.to raise_error(described_class::UnsafePath)
      end
      File.symlink(File.join(root, "data/cds/arith1.ocd"), File.join(directory, "escape"))
      expect { artifacts.local_path("escape") }.to raise_error(described_class::UnsafePath, /escape/)
      expect { artifacts.read("unrecorded") }.to raise_error(described_class::IntegrityError, /unrecorded/)
    end
  end

  it "installs the descriptor's public APIs without modifying core Collection" do
    described_class.install!
    expect(Openmath.parse_cd_group(arith_xml).name).to eq("arith")
    expect(Openmath.official_cd_collection).to be_a(described_class::PinnedCollection)
    expect(Openmath::CD::Collection.new.size).to eq(0)
  end
end
