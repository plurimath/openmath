# frozen_string_literal: true

require "json"
require "yaml"

module Openmath
  module Extensions
    # Small validator for the JSON Schema vocabulary used by the two shipped
    # contracts. Keep this vocabulary in step with the shipped schema files.
    module Schema
      module_function

      def validate(value, schema, at)
        types = Array(schema.fetch("type"))
        valid = types.any? do |type|
          case type
          when "object" then value.is_a?(Hash) && value.keys.all? { |key| key.is_a?(String) }
          when "array" then value.is_a?(Array)
          when "string" then value.is_a?(String)
          when "integer" then value.is_a?(Integer)
          when "null" then value.nil?
          else raise DescriptorError, "#{at}: unknown schema type #{type}"
          end
        end
        raise DescriptorError, "#{at}: expected #{types.join('/')}" unless valid
        if schema.key?("const") && value != schema["const"]
          raise DescriptorError, "#{at}: rejected #{value.inspect}"
        end
        if value.is_a?(String) && (value.empty? || (schema["pattern"] && !Regexp.new("\\A(?:#{schema["pattern"]})\\z").match?(value)))
          raise DescriptorError, "#{at}: rejected string #{value.inspect}"
        end
        if value.is_a?(Array)
          value.each_with_index { |item, index| validate(item, schema.fetch("items"), "#{at}[#{index}]") }
        elsif value.is_a?(Hash)
          missing = schema.fetch("required", []) - value.keys
          raise DescriptorError, "#{at}: missing #{missing.join(', ')}" unless missing.empty?
          properties = schema.fetch("properties", {})
          value.each do |key, item|
            child = properties[key] || schema.fetch("additionalProperties", false)
            raise DescriptorError, "#{at}: unknown field #{key}" unless child
            validate(item, child, "#{at}.#{key}")
          end
        end
        value
      end

      # Psych's safe loader rejects aliases and Ruby objects, but normally
      # accepts duplicate mapping keys. Refuse those before they are lost.
      def yaml(path)
        tree = Psych.parse_file(path)
        visit = lambda do |node|
          if node.is_a?(Psych::Nodes::Mapping)
            keys = node.children.each_slice(2).map { |key, _value| key.respond_to?(:value) ? key.value : nil }
            duplicate = keys.tally.find { |_key, count| count > 1 }
            raise DescriptorError, "#{path}: duplicate YAML key #{duplicate.first.inspect}" if duplicate
          end
          Array(node.children).each { |child| visit.call(child) } if node.respond_to?(:children)
        end
        visit.call(tree) if tree
        YAML.safe_load_file(path, aliases: false)
      rescue Psych::Exception, SystemCallError => e
        raise DescriptorError, "#{path}: #{e.message}"
      end

      def load(path)
        JSON.parse(File.read(path))
      rescue JSON::ParserError, SystemCallError => e
        raise DescriptorError, "#{path}: #{e.message}"
      end
    end
  end
end
