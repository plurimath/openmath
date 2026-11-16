# frozen_string_literal: true

module FixtureExtension
  def self.install(target, registry)
    target.instance_variable_set(:@fixture_installs, target.instance_variable_get(:@fixture_installs).to_i + 1)
    target.define_singleton_method(:fixture_install_count) { @fixture_installs }
    target.define_singleton_method(:fixture_api) do
      registry.descriptors.map { |descriptor| descriptor.fetch("id") }
    end
  end
end
