# frozen_string_literal: true

require "spec_helper"
require "nokogiri"
require_relative "../../scripts/reproduce_element_order"

RSpec.describe OrderReproduction do
  let(:saved) { JSON.parse(File.read(File.join(described_class::DIRECTORY, "observed.json"))) }

  it "checks every corpus artifact against its SHA256" do
    expect(described_class.check!).to be(true)
  end

  it "records expected child identities independently of lutaml's order metadata" do
    described_class.manifest.fetch("cases").each do |entry|
      xml = File.read(File.join(described_class::ROOT, entry.fetch("path")))
      expected = Nokogiri::XML(xml).at_xpath("//*[local-name()='OMA']").element_children.map do |node|
        { "name" => node.name, "attributes" => node.attribute_nodes.to_h { |attribute| [attribute.name, attribute.value] },
          "text" => node.text }
      end
      expect(entry.fetch("expected")).to eq(expected)
    end
  end

  it "measures the current environment and compares matching recorded inputs" do
    actual = JSON.parse(JSON.generate(described_class.run))
    expect(actual.fetch("ruby")).to eq(RUBY_DESCRIPTION)
    expect(actual.fetch("dependencies").fetch("lutaml-model").fetch("version")).to eq(Gem.loaded_specs.fetch("lutaml-model").version.to_s)
    if actual.fetch("ruby") == saved.fetch("ruby") && actual.fetch("dependencies") == saved.fetch("dependencies")
      expect(actual.fetch("adapters")).to eq(saved.fetch("adapters"))
    end
    expect(actual.fetch("adapters").map { |adapter| adapter.fetch("adapter") })
      .to eq(Moxml::Adapter::AVAILABLE_ADAPTERS.map(&:to_s))
  end

  it "keeps V2/V3, metadata, legacy output and issue probes separate for each measured adapter" do
    measured = saved.fetch("adapters").select { |adapter| adapter.fetch("status") == "measured" }
    expect(measured.map { |adapter| adapter.fetch("adapter") }).to include("leptris", "nokogiri")
    measured.each do |adapter|
      rows = adapter.fetch("observations")
      expect(rows.size).to eq(described_class.manifest.fetch("cases").size * 2)
      expect(rows.map { |row| row.fetch("version") }.uniq.sort).to eq([2, 3])
      rows.each do |row|
        expect(row.keys).to include("expected", "actual_metadata", "collections", "metadata_names_match", "legacy_matches_expected")
        expect(row.key?("legacy_fallback") || row.key?("legacy_error")).to be(true)
      end
      expect(adapter.fetch("issue_1163")).to have_key("matches_reported_nil_targets")
    end
    expect(saved.fetch("harness_success_is_product_success")).to be(false)
  end

  it "names every unavailable adapter in a typed refusal" do
    unavailable = saved.fetch("adapters").select { |adapter| adapter.fetch("status") == "unavailable" }
    unavailable.each do |adapter|
      expect(adapter.dig("refusal", "error_class")).to eq("OrderReproduction::AdapterUnavailableError")
      expect(adapter.dig("refusal", "message")).to include(adapter.fetch("adapter"))
    end
  end

  it "refuses unrecognized nodes and command options with typed diagnostics" do
    expect { described_class.signature(Object.new) }
      .to raise_error(OrderReproduction::UnsupportedNodeError, /Object/)
    expect { described_class.main(["--unknown"]) }
      .to raise_error(OrderReproduction::UnsupportedOptionError, /unknown/)
  end
end
