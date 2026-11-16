# frozen_string_literal: true

require "json"
require "digest"
require "optparse"
require "openmath"
require "moxml"

# Characterization only: this deliberately calls the unchanged legacy walker.
module OrderReproduction
  ROOT = File.expand_path("..", __dir__)
  DIRECTORY = File.join(ROOT, "corpora/order-reproduction")
  MANIFEST = File.join(DIRECTORY, "manifest.json")
  class IntegrityError < StandardError; end
  class UnsupportedNodeError < StandardError; end
  class AdapterUnavailableError < StandardError; end
  class UnsupportedOptionError < StandardError; end
  class CoverageError < StandardError; end

  # The two models and inputs from lutaml-model#1163, separate from OpenMath.
  class Body < Lutaml::Model::Serializable
    attribute :content, :string
    xml do
      element "body"
      map_all_content to: :content
    end
  end

  class Wrapper < Lutaml::Model::Serializable
    attribute :child, Body
    attribute :lang, :string
    xml do
      element "wrapper"
      map_element "body", to: :child
      map_attribute "lang", to: :lang
    end
  end

  module_function

  def manifest
    JSON.parse(File.read(MANIFEST))
  end

  def verify_inputs!
    entries = manifest.fetch("cases") + [manifest.fetch("issue")]
    entries.each do |entry|
      path = File.join(ROOT, entry.fetch("path"))
      unless File.file?(path) && Digest::SHA256.file(path).hexdigest == entry.fetch("sha256")
        raise IntegrityError, "refused artifact #{entry.fetch('path')}: SHA256 mismatch"
      end
    end
    true
  end

  def check!
    verify_inputs!
    JSON.parse(File.read(File.join(DIRECTORY, "checksums.json"))).each do |path, digest|
      absolute = File.join(ROOT, path)
      unless File.file?(absolute) && Digest::SHA256.file(absolute).hexdigest == digest
        raise IntegrityError, "refused artifact #{path}: SHA256 mismatch"
      end
    end
    true
  end

  def metadata(node)
    node.element_order&.map do |entry|
      %i[name type node_type text_content namespace_uri namespace_prefix attributes].to_h do |field|
        [field.to_s, entry.public_send(field)]
      end
    end
  end

  def signature(node)
    name = node.class.name.split("::").last.upcase
    attributes = case name
                 when "OMS" then { "cd" => node.cd, "name" => node.name }
                 when "OMV" then { "name" => node.name }
                 when "OMF" then { "dec" => node.dec, "hex" => node.hex }.compact
                 when "OMSTR", "OMB", "OMI" then {}
                 else raise UnsupportedNodeError, "refused node #{node.class.name}"
                 end
    { "name" => name, "attributes" => attributes,
      "text" => node.respond_to?(:value) ? Array(node.value).join : "" }
  end

  def failure(error)
    { "error_class" => error.class.name, "message" => error.message }
  end

  def issue_probe
    body = Body.from_xml("<body>plain</body>")
    child = Wrapper.from_xml('<wrapper lang="en"><body>a<b>x</b>b</body></wrapper>').child
    { "plain_content" => body.content, "nested_content" => child.content,
      "nested_metadata" => metadata(child),
      "matches_reported_nil_targets" => body.content.nil? && child.content.nil? && child.element_order.nil? }
  end

  def measure(entry, version)
    xml = File.read(File.join(ROOT, entry.fetch("path"))).sub("VERSION", "#{version}.0")
    root = Openmath.parse(xml, version: version)
    application = root.oma_value.fetch(0)
    order = metadata(application)
    expected = entry.fetch("expected")
    row = { "case" => entry.fetch("id"), "version" => version,
            "expected" => expected, "root_metadata" => metadata(root), "actual_metadata" => order,
            "collections" => Openmath::Evaluation::Evaluator::CHILD_ATTRIBUTES.to_h do |name, attribute|
              [name, Array(application.public_send(attribute)).map { |node| signature(node) }]
            end,
            "metadata_names_match" => order&.map { |item| item.fetch("name") } == expected.map { |item| item.fetch("name") } }
    begin
      actual = Openmath::Evaluation::Evaluator.ordered_children(application).map { |node| signature(node) }
      row.merge("legacy_fallback" => actual, "legacy_matches_expected" => actual == expected)
    rescue StandardError => e
      row.merge("legacy_error" => failure(e), "legacy_matches_expected" => false)
    end
  end

  def dependency_versions
    Gem.loaded_specs.sort.to_h do |name, spec|
      source = spec.source
      revision = source.revision if source.respond_to?(:revision)
      [name, { "version" => spec.version.to_s, "revision" => revision }.compact]
    end
  end

  def run
    verify_inputs!
    adapters = Moxml::Adapter::AVAILABLE_ADAPTERS.map do |adapter|
      begin
        # Keep loader failures separate from unexpected measurement failures.
        Moxml::Adapter.load(adapter)
      rescue LoadError, Moxml::AdapterError => e
        next({ "adapter" => adapter.to_s, "status" => "unavailable",
               "refusal" => failure(AdapterUnavailableError.new("refused adapter #{adapter}: #{e.class}: #{e.message}")) })
      end
      Lutaml::Model::AdapterScope.with(xml: adapter) do
        rows = [2, 3].flat_map { |version| manifest.fetch("cases").map { |entry| measure(entry, version) } }
        { "adapter" => adapter.to_s, "status" => "measured", "issue_1163" => issue_probe, "observations" => rows }
      end
    end
    measured = adapters.select { |item| item["status"] == "measured" }
    coverage_complete = measured.size == adapters.size
    ordering_pass = !measured.empty? && measured.all? do |item|
      item["observations"].all? { |row| row["legacy_matches_expected"] && row["metadata_names_match"] }
    end
    { "schema_version" => 1, "admission_sha" => manifest.fetch("admission_sha"),
      "ruby" => RUBY_DESCRIPTION, "dependencies" => dependency_versions,
      "issue_source" => manifest.fetch("issue"), "adapters" => adapters,
      "harness_success_is_product_success" => false,
      "coverage_complete" => coverage_complete, "measured_ordering_pass" => ordering_pass,
      "product_ordering_pass" => coverage_complete ? ordering_pass : nil }
  end

  def main(arguments)
    options = {}
    parser = OptionParser.new do |opts|
      opts.on("--json") { options[:json] = true }
      opts.on("--check") { options[:check] = true }
      opts.on("--record") { options[:record] = true }
      opts.on("--assert-product") { options[:product] = true }
    end
    parser.parse!(arguments)
    raise UnsupportedOptionError, "refused arguments #{arguments.inspect}" unless arguments.empty?

    if options[:check]
      check!
      puts JSON.generate("integrity" => "pass")
      return 0
    end
    report = run
    output = JSON.pretty_generate(report) + "\n"
    File.write(File.join(DIRECTORY, "observed.json"), output) if options[:record]
    puts output
    return 0 unless options[:product]
    unless report.fetch("coverage_complete")
      missing = report.fetch("adapters").select { |item| item["status"] == "unavailable" }.map { |item| item["adapter"] }
      warn "#{CoverageError.name}: refused complete adapter assertion: unavailable #{missing.join(', ')}"
      return 2
    end
    report.fetch("product_ordering_pass") ? 0 : 1
  rescue OptionParser::ParseError => e
    raise UnsupportedOptionError, "refused option: #{e.message}"
  end
end

exit OrderReproduction.main(ARGV) if $PROGRAM_NAME == __FILE__
