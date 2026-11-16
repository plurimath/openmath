# frozen_string_literal: true

require "spec_helper"

# The round-trip gate: every OpenMath object in the vendored corpus (the
# official CD collection's examples, see spec/fixtures/CORPUS_PROVENANCE.md)
# validates against the schema, parses, and round-trips byte-stably.
RSpec.describe "the corpus round-trip" do
  corpus = Dir[File.expand_path("../fixtures/corpus/*.omxml", __dir__)].sort

  it "has a corpus to speak of" do
    expect(corpus.size).to be > 300
  end

  corpus.each do |path|
    id = File.basename(path, ".omxml")
    it "#{id} validates, parses and round-trips byte-stably" do
      xml = File.read(path)
      expect(Openmath.valid?(xml, version: 2)).to be(true), "#{id}: schema"

      [2, 3].each do |version|
        object = Openmath.parse(xml, version: version)
        once = object.to_xml
        twice = Openmath.parse(once, version: version).to_xml
        expect(twice).to eq(once), "#{id}: not a fixed point under v#{version}"
      end
    end

    it "#{id} hashes canonically stable across versions and parse cycles" do
      xml = File.read(path)
      hashes = [2, 3].map do |version|
        object = Openmath.parse(xml, version: version)
        reparsed = Openmath.parse(object.to_xml, version: version)
        expect(reparsed.canonical_sha256).to eq(object.canonical_sha256),
                                              "#{id}: canonical drift under v#{version}"
        object.canonical_sha256
      end

      expect(hashes.uniq.size).to eq(1), "#{id}: v2 and v3 canonicals differ"
    end
  end
end
