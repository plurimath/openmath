# frozen_string_literal: true

# Build and install locally, then exercise the installed gem away from the source
# tree. Dependencies come from the current bundle; no downloads are performed.
require "bundler"
require "digest"
require "open3"
require "rubygems/package"
require "rubygems/installer"
require "tmpdir"

module PackageCheck
  class Error < StandardError; end

  ROOT = File.expand_path("..", __dir__)

  def self.run
    spec = Gem::Specification.load(File.join(ROOT, "openmath.gemspec"))
    raise Error, "cannot load openmath.gemspec" unless spec

    data = Dir.chdir(ROOT) { Dir["data/**/*"].select { |path| File.file?(path) } }
    missing = data - spec.files
    raise Error, "package omits runtime data: #{missing.join(', ')}" unless missing.empty?

    Dir.mktmpdir("openmath-package-") do |scratch|
      archive = File.join(scratch, "openmath-#{spec.version}.gem")
      Dir.chdir(ROOT) { Gem::Package.build(spec, false, false, archive) }
      home = File.join(scratch, "gems")
      installed = Gem::Installer.at(archive, install_dir: home,
                                              ignore_dependencies: true,
                                              wrappers: false).install
      data.each do |path|
        packaged = File.join(installed.full_gem_path, path)
        unless File.file?(packaged) && Digest::SHA256.file(packaged) == Digest::SHA256.file(File.join(ROOT, path))
          raise Error, "installed runtime data differs: #{path}"
        end
      end

      # Pin the already activated dependencies, including a git-sourced
      # lutaml-model, while resolving openmath from the scratch GEM_HOME.
      gemfile = File.join(scratch, "Gemfile")
      dependencies = Gem.loaded_specs.values.reject { |dep| %w[openmath bundler].include?(dep.name) }
      File.write(gemfile, (["gem 'openmath', '= #{spec.version}'"] + dependencies.map do |dep|
        declaration = "gem #{dep.name.dump}, #{"= #{dep.version}".dump}"
        # Installed gemspecs preserve custom require paths and native extensions.
        # Only source dependencies need a path declaration.
        if dep.respond_to?(:source) && dep.source.is_a?(Bundler::Source::Path)
          declaration += ", path: #{dep.full_gem_path.dump}"
        end
        declaration
      end).join("\n") + "\n")

      probe = <<~'RUBY'
        require "openmath"
        expected = File.realpath(ARGV.fetch(0))
        actual = File.realpath(Gem.loaded_specs.fetch("openmath").full_gem_path)
        raise "loaded openmath outside scratch install: #{actual}" unless actual == expected
        table = Openmath::Evaluation::BindingTable
        path = File.realpath(table::DATA_PATH)
        raise "binding table outside installed gem: #{path}" unless path.start_with?(expected + File::SEPARATOR)
        table.default
        { ["nums1", "rational"] => Rational(1, 2), ["arith1", "plus"] => 3 }.each do |(cd, name), expected_value|
          xml = %(<OMOBJ xmlns="http://www.openmath.org/OpenMath"><OMA><OMS cd="#{cd}" name="#{name}"/><OMI>1</OMI><OMI>2</OMI></OMA></OMOBJ>)
          value = Openmath.evaluate(xml)
          raise "#{cd}/#{name}: expected #{expected_value.inspect}, got #{value.inspect}" unless value == expected_value && value.class == expected_value.class
          puts "#{cd}/#{name} = #{value.inspect} (#{value.class})"
        end
        puts "BindingTable::DATA_PATH = #{path}"
      RUBY
      output, status = Bundler.with_unbundled_env do
        Open3.capture2e({ "GEM_HOME" => home, "GEM_PATH" => ([home] + Gem.path).join(File::PATH_SEPARATOR),
                         "BUNDLE_GEMFILE" => gemfile, "BUNDLE_PATH" => nil,
                         "BUNDLE_IGNORE_CONFIG" => "1", "RUBYLIB" => nil },
                       Gem.ruby, "-rbundler/setup", "-e", probe,
                       installed.full_gem_path, chdir: scratch)
      end
      raise Error, "installed openmath #{spec.version} probe failed (#{status.exitstatus}):\n#{output}" unless status.success?

      puts output
      puts "package check passed: openmath #{spec.version}, #{data.size} runtime data files"
    end
  end
end

PackageCheck.run if $PROGRAM_NAME == __FILE__
