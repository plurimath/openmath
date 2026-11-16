# frozen_string_literal: true

require "spec_helper"

# Architectural lint checks and registration smoke tests (the mml
# code_quality_spec pattern).
#
# These lock in:
# - No `require_relative` for internal library code (use `autoload`).
# - No `instance_variable_set/get`, no `send` bypassing visibility.
# - Every versioned element class is reachable via autoload and registered
#   in its version's LutaML context, so symbol-typed attributes resolve.
ELEMENT_IDS = %i[
  oms omv omi omb omstr omf oma ombind ombvar ome omattr omatp omforeign omr omobj
].freeze

def element_class_name(id)
  id.to_s.split("_").map(&:capitalize).join
end

RSpec.describe "openmath code quality" do
  lib_files = Dir[File.expand_path("../../lib/**/*.rb", __dir__)]

  it "uses autoload, never require_relative, for internal library code" do
    offenders = lib_files.select { |f| File.read(f).match?(/require_relative/) }
    expect(offenders).to eq([])
  end

  it "does not mutate other objects' state" do
    offenders = lib_files.select do |f|
      File.read(f).match?(/instance_variable_(set|get)|\.send\(/)
    end
    expect(offenders).to eq([])
  end

  %i[V2 V3].each do |version_const|
    version_module = Openmath.const_get(version_const)

    describe "the #{version_const} context" do
      it "has every element class reachable via autoload" do
        ELEMENT_IDS.each do |id|
          expect(version_module.const_get(element_class_name(id))).to be_a(Class), id
        end
      end

      it "registers every element class in its LutaML context" do
        version_module.register_models!
        context = version_module::Configuration.context
        ELEMENT_IDS.each do |id|
          resolved = context.registry.lookup(id)
          expect(resolved).to be_a(Class), id
          expect(resolved.name).to start_with("Openmath::#{version_const}"), id
        end
      end

      it "parses through its own hierarchy" do
        xml = "<OMOBJ xmlns=\"http://www.openmath.org/OpenMath\"><OMV name=\"x\"/></OMOBJ>"
        expect(version_module.parse(xml)).to be_a(version_module::Omobj)
      end
    end
  end
end
