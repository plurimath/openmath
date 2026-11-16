# frozen_string_literal: true

require "json"
require "digest"

module Openmath
  module Evaluation
    # The portable bindings artifact: the shipped binding table plus the
    # replay ledger as language-independent JSON, so Rust and Wasm
    # runtimes can implement parse and evaluate against the same
    # semantics and replay the same vectors (the plurimath#584 rs/wasm
    # replay lanes). The export is deterministic — same table, same
    # vectors, same bytes — and `scripts/export_portable.rb --check`
    # gates that in CI.
    module Portable
      SCHEMA = "openmath-portable-bindings/1"
      DATA_PATH = File.expand_path("../../../data/portable-bindings.json", __dir__)
      VECTORS_PATH = File.expand_path("../../../data/replay-vectors.yml", __dir__)

      module_function

      # Exports the artifact structure: the bindings with their
      # operations and arities, the table checksum, and the replay
      # vectors verbatim from the ledger.
      def export
        table = BindingTable.default
        {
          "schema" => SCHEMA,
          "generator" => "openmath-ruby #{Openmath::VERSION}",
          "table_checksum" => BindingTable.default_checksum,
          "bindings" => table.bindings.sort_by(&:key).map do |binding|
            {
              "cd" => binding.cd,
              "name" => binding.name,
              "operation" => binding.operation.to_s,
              "arity" => arity_spec(binding.operation),
            }
          end,
          "vectors" => YAML.safe_load_file(VECTORS_PATH, aliases: false)
            .fetch("vectors"),
        }
      end

      # Deterministic bytes: sorted keys, no whitespace variance.
      def export_json
        JSON.generate(export, sort_keys: true)
      end

      # Writes the artifact; returns the bytes.
      def write(path = DATA_PATH)
        json = export_json
        File.write(path, json + "\n")
        json
      end

      # The determinism gate: the shipped artifact must equal a fresh
      # export byte for byte.
      def check(path = DATA_PATH)
        export_json + "\n" == File.read(path)
      end

      # Replays every ledger row through the evaluator: request XML in,
      # expected value or refusal out. Returns the list of failures;
      # empty when the artifact replays clean.
      def replay(table: BindingTable.default, signatures: nil)
        failures = []
        export.fetch("vectors").each do |vector|
          failures.concat(replay_vector(vector, table, signatures))
        end
        failures
      end

      def replay_vector(vector, table, signatures)
        object = Openmath.parse(vector.fetch("request"), version: 2)
        result = Evaluator.evaluate(object, table: table,
                                    variables: vector["variables"] || {},
                                    signatures: signatures)
        expected = vector["expected"]
        return [] if expected &&
                     values_equal?(result, expected.key?("class") ? expected : expected["value"])

        [replay_failure(vector, result)]
      rescue Openmath::Evaluation::Error, ZeroDivisionError => e
        refusal = vector["refusal"]
        return [] if refusal && e.class.name.end_with?(refusal["error"])

        [replay_failure(vector, e)]
      end

      def values_equal?(result, expected)
        case expected
        when Hash
          result.class.name == expected["class"] &&
            expected["fields"].all? do |field, value|
              result.public_send(field).to_s == value.to_s
            end
        else
          result == expected || result.to_s == expected.to_s
        end
      end

      def replay_failure(vector, result)
        expected = vector.dig("expected", "value") || vector.dig("refusal", "error")
        "replay failure #{vector.fetch("id")}: expected #{expected} — " \
          "got #{result.inspect[0, 120]}"
      end

      def arity_spec(operation)
        spec = Operations.arity(operation)
        spec.end.nil? ? [spec.min, nil] : [spec.min, spec.max]
      end
    end
  end
end
