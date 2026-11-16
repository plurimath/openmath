# frozen_string_literal: true

require "spec_helper"
require_relative "../../scripts/check_package"

RSpec.describe "installed gem packaging" do
  it "ships unchanged runtime data and evaluates rational and plus outside the source tree" do
    expect { PackageCheck.run }.to output(/package check passed: openmath #{Openmath::VERSION}/).to_stdout
  end
end
