#!/usr/bin/env ruby
# frozen_string_literal: true

# The acquisition record lives beside the verbatim data. This offline gate
# verifies it; refreshing requires a separately reviewed manifest/source update.
require_relative "../lib/openmath/cd/group"
require "yaml"

unless ARGV == ["--check"]
  warn "usage: bundle exec ruby scripts/vendor_cd_collection.rb --check (offline)"
  exit 2
end

begin
  artifacts = Openmath::CD::Group::Artifacts.new
  artifacts.check!
  collection = Openmath::CD::Group::PinnedCollection.new(artifacts: artifacts)
  # Check every dictionary header against the inventory without evaluating FMPs.
  collection.verify!
  tracked = artifacts.records.map { |r| r.fetch("path") }.sort
  actual = Dir.chdir(Openmath::CD::Group::ROOT) do
    Dir["data/cds/**/*", "data/cd-groups/*.cdg", "schemas/cdgroup/*"]
      .select { |path| File.file?(path) }.sort
  end
  unless actual == tracked
    raise Openmath::CD::Group::IntegrityError,
          "refused inventory: unrecorded #{actual - tracked}, missing #{tracked - actual}"
  end
  descriptor_path = artifacts.local_path("data/extensions/groups.yml")
  descriptor = YAML.safe_load_file(descriptor_path)
  descriptor.fetch("artifacts").each do |record|
    path = record.fetch("path")
    actual_digest = Digest::SHA256.file(artifacts.local_path(path)).hexdigest
    unless actual_digest == record.fetch("sha256")
      raise Openmath::CD::Group::IntegrityError,
            "refused descriptor artifact #{path}: SHA256 expected #{record['sha256']}, actual #{actual_digest}"
    end
  end
  puts "verified #{tracked.size} artifacts; #{collection.size} exact CD identities; offline"
rescue Openmath::CD::Group::Error => e
  warn "#{e.class}: #{e.message}"
  exit 1
end
