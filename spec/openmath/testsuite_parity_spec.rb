# frozen_string_literal: true

require "yaml"
require "json"

# The producer side of the replay: the testsuite checkout carries the
# generator whose functions computed the rows, so the replay recomputes
# through the very same code.
if ENV.fetch("OPENMATH_TESTSUITE", nil)
  generator = File.join(ENV.fetch("OPENMATH_TESTSUITE"), "scripts", "generate-openmath-stage.rb")
  require generator if File.file?(generator)
end

# Parity with the plurimath-testsuite's openmath stage: every row of the
# pinned generation's latest ledger entry recomputes through the same
# functions the producer used, and the recomputed expectation equals the
# recorded one. Runs when OPENMATH_TESTSUITE names a plurimath-testsuite
# checkout (CI checks out the commit the pin names). Append-only
# supersession: a row whose id has an -r2 sibling is kept for history and
# is superseded by that sibling — the original is skipped, the sibling
# replays.
RSpec.describe "plurimath-testsuite openmath parity" do
  root = ENV.fetch("OPENMATH_TESTSUITE", nil)
  pin_path = File.expand_path("../fixtures/testsuite-pin.yml", __dir__)
  pin = File.file?(pin_path) ? YAML.safe_load_file(pin_path, aliases: false) : nil
  ledger_path = root && File.join(root, "generations", "openmath.yaml")
  ledger = ledger_path && File.file?(ledger_path) ? YAML.safe_load_file(ledger_path, aliases: true) : nil
  latest = ledger&.fetch("entries")&.last
  generation = root && latest && File.join(root, latest.fetch("path"))

  # Flattens the generation's payloads into {id => [payload, case]}.
  def rows(generation)
    Dir[File.join(generation, "payloads", "*.yaml")].sort.flat_map do |file|
      payload = YAML.safe_load_file(file, aliases: true)
      payload.fetch("cases").map do |row|
        [row.fetch("id"), [payload, row]]
      end
    end.to_h
  end

  def input_xml(row)
    input = row.fetch("input")
    return input.fetch("str") if input.key?("str")

    [input.fetch("bytes")].pack("H*")
  end

  # The encoding tag is a capture artifact of the producer environment
  # (the same bytes arrive tagged str or bytes under different lutaml
  # serialization encodings); the replay compares content.
  def normalize(value)
    case value
    when Hash
      if value.key?("bytes") && value.key?("encoding")
        { "str" => [value["bytes"]].pack("H*").force_encoding(value["encoding"]) }
      else
        value.to_h { |key, item| [key, normalize(item)] }
      end
    when Array then value.map { |item| normalize(item) }
    else value
    end
  end

  # The official collection the cd-resolve rows resolve against.
  def official_collection
    @official_collection ||= begin
      cds = ENV.fetch("OPENMATH_CDS", nil)
      Openmath::CD::Collection.new.load(File.join(cds, "cd/Official")) if cds
    end
  end

  # Recomputes the row's expectation through the producer's functions.
  def recomputed(payload, row, collection: nil)
    case payload.fetch("boundary")
    when "model-roundtrip"
      OpenmathStage.roundtrip_expected(input_xml(row),
                                       Integer(row.dig("options", "version")))
    when "validation"
      OpenmathStage.validation_expected(input_xml(row),
                                        Integer(row.dig("options", "version")))
    when "cd-loading"
      if row.dig("options", "collection") == "official"
        return nil if official_collection.nil?

        cd, name = input_xml(row).split("#", 2)
        definition = official_collection.resolve(cd: cd, name: name)
        return { "model" => { "bool" => !definition.nil? },
                 "output" => OpenmathStage.tstr(definition ? definition.role.to_s : "") }
      end

      OpenmathStage.cd_summary(input_xml(row))
    when "evaluation"
      variables = JSON.parse(row.dig("options", "variables") || "{}")
      OpenmathStage.evaluate_expected(input_xml(row), variables, nil)
    end
  end

  it "pins the testsuite generation" do
    skip "set OPENMATH_TESTSUITE to a plurimath-testsuite checkout" unless root && latest

    expect(latest.fetch("generation")).to eq(pin.fetch("generation"))
    expect(latest.fetch("snapshot_digest")).to eq(pin.fetch("snapshot_digest"))
    expect(latest.fetch("rows")).to eq(rows(generation).size)
  end

  it "replays every non-superseded row of the pinned generation" do
    skip "set OPENMATH_TESTSUITE to a plurimath-testsuite checkout" unless root && latest

    all_rows = rows(generation)
    superseded = all_rows.keys.select { |id| id.include?("-r2") }
      .to_h { |id| [id.sub(/-r2(\.(model-roundtrip|validation|evaluation|cd-loading))\z/, "\\1"), id] }
    replayed = all_rows.reject { |id, _| superseded.key?(id) }

    expect(replayed.size).to be > 0
    failures = replayed.filter_map do |id, (payload, row)|
      actual = normalize(recomputed(payload, row))
      next if actual.nil? # cd-resolve rows without OPENMATH_CDS
      expected = normalize(row.fetch("expected"))
      next if actual == expected

      "#{id}: expected #{row['expected'].inspect[0, 160]} — got #{actual.inspect[0, 160]}"
    end
    expect(failures).to eq([]), failures.join("\n")
  end

  it "replays the -r2 supersessions" do
    skip "set OPENMATH_TESTSUITE to a plurimath-testsuite checkout" unless root && latest

    all_rows = rows(generation)
    r2 = all_rows.select { |id, _| id.include?("-r2") }
    expect(r2.size).to be > 0
    failures = r2.filter_map do |id, (payload, row)|
      actual = normalize(recomputed(payload, row))
      next if actual.nil? # cd-resolve rows without OPENMATH_CDS
      expected = normalize(row.fetch("expected"))
      next if actual == expected

      "#{id}: expected #{row['expected'].inspect[0, 160]} — got #{actual.inspect[0, 160]}"
    end
    expect(failures).to eq([]), failures.join("\n")
  end
end
