# frozen_string_literal: true

# Read-only artifact gate. Descriptors own their checksums; updating a feature
# never rewrites an aggregate manifest. No installer code is executed here.
require_relative "../lib/openmath/evaluation"
require_relative "../lib/openmath/extensions/registry"

unless ARGV == ["--check"]
  warn "usage: ruby scripts/check_binding_artifacts.rb --check"
  exit 2
end

begin
  registry = Openmath::Extensions::Registry.new
  table = Openmath::Evaluation::BindingTable.load_fragments(registry.binding_paths)
  puts "checked #{registry.descriptors.size} extensions, #{table.bindings.size} bindings"
rescue Openmath::Extensions::DescriptorError, Openmath::Evaluation::BindingArtifactError => e
  warn e.message
  exit 1
end
