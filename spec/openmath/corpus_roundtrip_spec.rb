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
  end
end
