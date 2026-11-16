# frozen_string_literal: true

require "spec_helper"

# The portable bindings artifact: language-independent JSON for the
# rs/wasm replay lanes, deterministic under export, and self-consistent
# — every ledger row replays through the evaluator.
RSpec.describe Openmath::Evaluation::Portable do
  let(:artifact_path) { File.expand_path("../../data/portable-bindings.json", __dir__) }

  it "exports the shipped table with arities and the ledger" do
    artifact = described_class.export

    expect(artifact.fetch("schema")).to eq("openmath-portable-bindings/1")
    expect(artifact.fetch("bindings").size).to be >= 50
    expect(artifact.fetch("bindings")).to include(
      {"cd" => "arith1", "name" => "plus", "operation" => "plus",
       "arity" => [1, nil]},
      {"cd" => "pmquant", "name" => "ustd", "operation" => "ustd",
       "arity" => [2, 2]},
    )
    expect(artifact.fetch("vectors").size).to be >= 50
    expect(artifact.fetch("table_checksum")).to eq(Openmath::Evaluation::BindingTable.default_checksum)
  end

  it "exports deterministically: two exports are byte-identical" do
    expect(described_class.export_json).to eq(described_class.export_json)
  end

  it "ships an artifact matching a fresh export (the CI gate)" do
    expect(described_class.check(artifact_path)).to be(true)
  end

  it "replays every ledger row through the evaluator" do
    expect(described_class.replay).to be_empty
  end

  it "keeps the ledger's refusal rows typed" do
    refusals = described_class.export.fetch("vectors")
      .select { |vector| vector["refusal"] }

    expect(refusals.map { |vector| vector["refusal"]["error"] }).to include(
      "UnboundSymbolError", "ArityError", "OperandTypeError",
      "DimensionMismatchError", "RecursionError", "ZeroDivisionError",
    )
  end
end
