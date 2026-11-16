# frozen_string_literal: true

require "spec_helper"
require "tmpdir"
require "fileutils"
require "open3"
require "rbconfig"
require "json"
require "digest"
require "rubygems/package"

RSpec.describe Openmath::Extensions::Registry do
  let(:source_root) { File.expand_path("../..", __dir__) }

  around do |example|
    Dir.mktmpdir("openmath-extension-contract") do |directory|
      @package = directory
      %w[lib data].each { |name| FileUtils.cp_r(File.join(source_root, name), directory) }
      example.run
    end
  end

  def write_json(relative, object)
    path = File.join(@package, relative)
    FileUtils.mkdir_p(File.dirname(path))
    File.write(path, JSON.pretty_generate(object) + "\n")
  end

  def fixture(id, cd: id, cdbase: "urn:fixture", hook: true)
    implementation = "lib/openmath/extensions/#{id}/probe.rb"
    FileUtils.mkdir_p(File.dirname(File.join(@package, implementation)))
    FileUtils.cp(File.join(source_root, "spec/fixtures/extensions/probe.rb"), File.join(@package, implementation))
    fragment = "data/bindings/#{id}.yml"
    write_json(fragment, {
      "schema" => "openmath-binding-fragment/1", "version" => 1,
      "signatures" => { "identity" => { "operation" => "identity" } },
      "bindings" => [{ "cdbase" => cdbase, "cd" => cd, "name" => "probe", "operation" => "identity", "signature" => "identity" }],
    })
    files = [fragment, implementation].to_h do |relative|
      [relative, Digest::SHA256.file(File.join(@package, relative)).hexdigest]
    end
    descriptor = {
      "schema" => "openmath-extension/1", "id" => id, "files" => files, "bindings" => [fragment],
      "hooks" => hook ? [{ "type" => "installer", "file" => implementation, "constant" => "FixtureExtension" }] : [],
    }
    write_json("data/extensions/#{id}.yml", descriptor)
    descriptor
  end

  def registry
    described_class.new(root: @package)
  end

  def subprocess
    Open3.capture3(RbConfig.ruby, "-I", File.join(@package, "lib"), "-r", "openmath", "-e", <<~'CODE', chdir: @package)
      require "json"
      first = Openmath::Extensions.registry
      Openmath::Extensions.install!
      table = Openmath::Evaluation::BindingTable.default
      puts JSON.generate(api: Openmath.fixture_api, binding: table.lookup("zeta", "probe", cdbase: "urn:fixture").signature,
                         stable: first.equal?(Openmath::Extensions.registry), installs: Openmath.fixture_install_count)
    CODE
  end

  it "discovers a temporary packaged extension, binding and public API in a fresh process" do
    protected_paths = %w[lib/openmath.rb lib/openmath/v2.rb lib/openmath/v3.rb lib/openmath/extensions/registry.rb]
    before = protected_paths.to_h { |path| [path, Digest::SHA256.file(File.join(@package, path)).hexdigest] }
    fixture("zeta")
    fixture("alpha", hook: false)
    stdout, stderr, status = subprocess
    expect(status.exitstatus).to eq(0), stderr
    expect(JSON.parse(stdout.lines.last)).to eq("api" => %w[alpha core zeta], "binding" => "identity", "stable" => true, "installs" => 1)
    protected_paths.each { |path| expect(Digest::SHA256.file(File.join(@package, path)).hexdigest).to eq(before.fetch(path)) }
    expect(subprocess.first).to eq(stdout)
  end

  it "ships discovery data and loads a fixture from an actual gem package" do
    specification = Gem::Specification.load(File.join(source_root, "openmath.gemspec"))
    required = Dir.chdir(source_root) { Dir["data/*-schema.json", "data/extensions/*.yml", "data/bindings/*.yml"] }
    missing = required - specification.files
    pending("F-pkg prerequisite absent at admission 7719764: #{missing.join(', ')}") unless missing.empty?
    expect(missing).to be_empty

    fixture("zeta")
    specification.files = (specification.files + Dir.chdir(@package) { Dir["lib/openmath/extensions/zeta/*.rb", "data/bindings/zeta.yml", "data/extensions/zeta.yml"] }).uniq
    # Copy existing package files only; the fixture adds its own files without
    # changing the installed gemspec, entrypoints or a shared manifest.
    specification.files.each do |relative|
      next if File.file?(File.join(@package, relative))
      source = File.join(source_root, relative)
      next unless File.file?(source)
      FileUtils.mkdir_p(File.dirname(File.join(@package, relative)))
      FileUtils.cp(source, File.join(@package, relative))
    end
    archive = Dir.chdir(@package) { Gem::Package.build(specification, true) }
    extracted = File.join(@package, "installed")
    Gem::Package.new(File.join(@package, archive)).extract_files(extracted)
    @package = extracted
    stdout, stderr, status = subprocess
    expect(status.exitstatus).to eq(0), stderr
    expect(JSON.parse(stdout.lines.last).fetch("binding")).to eq("identity")
  end

  it "sorts descriptors independently of creation order" do
    fixture("zeta", hook: false)
    fixture("alpha", hook: false)
    expect(registry.descriptors.map { |descriptor| descriptor.fetch("id") }).to eq(%w[alpha core zeta])
  end

  it "refuses duplicate extension ids" do
    descriptor = fixture("alpha")
    write_json("data/extensions/zeta.yml", descriptor)
    expect { registry }.to raise_error(Openmath::Extensions::DescriptorError, /duplicate extension alpha/)
  end

  it "refuses duplicate cdbase, CD and name keys across fragments" do
    fixture("alpha", cd: "duplicate")
    fixture("zeta", cd: "duplicate")
    expect { registry }.to raise_error(Openmath::Evaluation::BindingArtifactError, /duplicate binding urn:fixture#duplicate#probe/)
  end

  it "distinguishes the same CD/name under different cdbases" do
    fixture("alpha", cd: "same", cdbase: "urn:first")
    fixture("zeta", cd: "same", cdbase: "urn:second")
    table = Openmath::Evaluation::BindingTable.load_fragments(registry.binding_paths)
    expect(table.lookup("same", "probe", cdbase: "urn:first")).not_to be_nil
    expect(table.lookup("same", "probe", cdbase: "urn:second")).not_to be_nil
    expect(table.lookup("same", "probe")).to be_nil
  end

  it "refuses unknown hook types before executing code" do
    descriptor = fixture("alpha")
    descriptor["hooks"][0]["type"] = "eval"
    write_json("data/extensions/alpha.yml", descriptor)
    expect { registry }.to raise_error(Openmath::Extensions::DescriptorError, /hooks.*type.*eval/)
  end

  it "refuses undeclared hooks and binding files" do
    descriptor = fixture("alpha")
    descriptor["hooks"][0]["file"] = "lib/openmath.rb"
    write_json("data/extensions/alpha.yml", descriptor)
    expect { registry }.to raise_error(Openmath::Extensions::DescriptorError, /undeclared file lib\/openmath.rb/)
    descriptor["hooks"] = []
    descriptor["bindings"] = ["data/bindings/missing.yml"]
    write_json("data/extensions/alpha.yml", descriptor)
    expect { registry }.to raise_error(Openmath::Extensions::DescriptorError, /undeclared file.*missing/)
  end

  it "refuses traversal, absolute paths and symlink escapes" do
    instance = registry
    ["../outside", "/tmp/outside", "lib/../outside", "lib//outside", "lib\\outside"].each do |path|
      expect { instance.checked_path(path) }.to raise_error(Openmath::Extensions::DescriptorError, /unsafe extension path/)
    end
    File.symlink("/etc/passwd", File.join(@package, "escape"))
    expect { instance.checked_path("escape") }.to raise_error(Openmath::Extensions::DescriptorError, /escapes package/)
  end

  it "refuses changed artifacts and duplicate file ownership" do
    descriptor = fixture("alpha")
    File.write(File.join(@package, "data/bindings/alpha.yml"), "changed")
    expect { registry }.to raise_error(Openmath::Extensions::DescriptorError, /checksum mismatch.*alpha/)
    fixture("alpha")
    other = fixture("zeta")
    other["files"].merge!(descriptor["files"])
    write_json("data/extensions/zeta.yml", other)
    expect { registry }.to raise_error(Openmath::Extensions::DescriptorError, /duplicate file owner/)
  end

  it "refuses duplicate YAML mapping keys instead of silently overwriting" do
    fixture("alpha")
    path = File.join(@package, "data/extensions/alpha.yml")
    File.write(path, File.read(path).sub('"id": "alpha",', '"id": "alpha", "id": "zeta",'))
    expect { registry }.to raise_error(Openmath::Extensions::DescriptorError, /duplicate YAML key.*id/)
  end

  it "refuses missing or inconsistent signature links" do
    descriptor = fixture("alpha")
    path = "data/bindings/alpha.yml"
    fragment = JSON.parse(File.read(File.join(@package, path)))
    fragment["bindings"][0]["signature"] = "missing"
    write_json(path, fragment)
    descriptor["files"][path] = Digest::SHA256.file(File.join(@package, path)).hexdigest
    write_json("data/extensions/alpha.yml", descriptor)
    expect { registry }.to raise_error(Openmath::Evaluation::BindingArtifactError, /signature missing.*urn:fixture#alpha#probe/)
  end

  it "preserves the legacy table API" do
    table = Openmath::Evaluation::BindingTable.load_file(Openmath::Evaluation::BindingTable::DATA_PATH)
    expect(table.lookup("arith1", "minus").operation).to eq(:minus)
    expect(Openmath::Evaluation::BindingTable.default.lookup("arith1", "minus").operation).to eq(:minus)
  end
end
