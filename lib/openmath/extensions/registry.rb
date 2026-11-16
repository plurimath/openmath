# frozen_string_literal: true

require "yaml"
require "digest"
require "pathname"
require_relative "schema"

module Openmath
  module Extensions
    class DescriptorError < StandardError; end

    # A registry is built completely before installer code runs. Features own
    # their descriptor and its files; there is no aggregate feature manifest.
    class Registry
      attr_reader :root, :descriptors, :binding_paths

      def initialize(root: File.expand_path("../../..", __dir__))
        @root = File.realpath(root)
        @descriptors = []
        @binding_paths = []
        @owners = {}
        @installed = false
        discover!
      rescue SystemCallError => e
        raise DescriptorError, "#{root}: #{e.message}"
      end

      def checked_path(relative)
        unless relative.is_a?(String) && !relative.include?("\\") && !relative.include?("\0") &&
            !Pathname.new(relative).absolute? && relative.split("/", -1).none? { |part| ["", ".", ".."].include?(part) }
          raise DescriptorError, "unsafe extension path #{relative.inspect}"
        end
        path = File.realpath(File.join(root, relative))
        unless path.start_with?("#{root}/") && File.file?(path)
          raise DescriptorError, "extension path escapes package: #{relative}"
        end
        path
      rescue SystemCallError => e
        raise DescriptorError, "extension path #{relative.inspect}: #{e.message}"
      end

      def discover!
        schema = Schema.load(checked_path("data/extension-schema.json"))
        ids = {}
        Dir.glob(File.join(root, "data/extensions/*.yml")).sort.each do |path|
          path = checked_path(Pathname.new(path).relative_path_from(Pathname.new(root)).to_s)
          doc = Schema.validate(Schema.yaml(path), schema, path)
          id = doc.fetch("id")
          raise DescriptorError, "duplicate extension #{id}" if ids[id]
          ids[id] = true
          doc.fetch("files").each do |relative, checksum|
            raise DescriptorError, "duplicate file owner #{relative}" if @owners.key?(relative)
            actual = Digest::SHA256.file(checked_path(relative)).hexdigest
            raise DescriptorError, "#{id}: checksum mismatch #{relative}" unless actual == checksum
            @owners[relative] = id
          end
          doc.fetch("bindings").each do |relative|
            owned!(doc, relative)
            unless relative.start_with?("data/bindings/") && relative.end_with?(".yml")
              raise DescriptorError, "#{id}: unsafe binding fragment #{relative}"
            end
            @binding_paths << checked_path(relative)
          end
          doc.fetch("hooks").each do |hook|
            owned!(doc, hook.fetch("file"))
            unless hook.fetch("file").start_with?("lib/") && hook.fetch("file").end_with?(".rb")
              raise DescriptorError, "#{id}: unsafe installer #{hook['file']}"
            end
          end
          @descriptors << doc
        end
        # Validate fragments (including cross-fragment keys) before executing hooks.
        Evaluation::BindingTable.load_fragments(binding_paths)
      end

      def owned!(doc, relative)
        return if doc.fetch("files").key?(relative)
        raise DescriptorError, "#{doc['id']}: undeclared file #{relative}"
      end

      def install!(target = Openmath)
        return self if @installed
        descriptors.each do |doc|
          doc.fetch("hooks").each do |hook|
            require checked_path(hook.fetch("file"))
            installer = hook.fetch("constant").split("::").inject(Object) do |scope, name|
              scope.const_get(name, false)
            end
            unless installer.respond_to?(:install)
              raise DescriptorError, "#{doc['id']}: installer #{hook['constant']} has no install hook"
            end
            installer.install(target, self)
          rescue NameError, LoadError => e
            raise DescriptorError, "#{doc['id']}: rejected hook #{hook['constant']}: #{e.message}"
          end
        end
        @installed = true
        self
      end
    end

    def self.registry
      @registry ||= Registry.new
    end

    def self.install!
      registry.install!
    end
  end
end
