# frozen_string_literal: true

require_relative "lib/openmath/version"

Gem::Specification.new do |spec|
  spec.name = "openmath"
  spec.version = Openmath::VERSION
  spec.authors = ["Ribose Inc."]
  spec.email = ["open.source@ribose.com"]

  spec.summary = "OpenMath parser by Plurimath."
  spec.description = <<~DESCRIPTION
    OpenMath 2 and OpenMath 3 XML encoding parsed into a typed model
    declared with LutaML Model, with content-dictionary-aware semantics.
    Used by Plurimath.
  DESCRIPTION

  spec.homepage = "https://github.com/plurimath/openmath"
  spec.license = "BSD-2-Clause"

  spec.required_ruby_version = Gem::Requirement.new(">= 3.2.0")

  spec.files = Dir.chdir(File.expand_path(__dir__)) do
    Dir["lib/**/*.rb", "README.adoc", "LICENSE.md"]
      .select { |f| File.file?(f) }
  end
  spec.require_paths = ["lib"]

  spec.add_dependency "lutaml-model", "~> 0.8", ">= 0.8.162"
  spec.add_dependency "moxml", "~> 0.6.1"

  spec.metadata["rubygems_mfa_required"] = "true"
end
