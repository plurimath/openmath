#!/usr/bin/env ruby
# frozen_string_literal: true

# Writes the portable bindings artifact (data/portable-bindings.json):
# the shipped binding table plus the replay ledger as language-
# independent JSON. With --check, verifies the shipped artifact equals a
# fresh export byte for byte (the CI determinism gate).
require "bundler/setup"
$LOAD_PATH.unshift File.expand_path("../lib", __dir__)
require "openmath"

path = File.expand_path("../data/portable-bindings.json", __dir__)

if ARGV.include?("--check")
  if Openmath::Evaluation::Portable.check(path)
    puts "portable artifact verified: #{path}"
  else
    warn "portable artifact drift: #{path} differs from a fresh export"
    exit 1
  end
else
  Openmath::Evaluation::Portable.write(path)
  puts "exported: #{path} (#{File.size(path)} bytes)"
end
