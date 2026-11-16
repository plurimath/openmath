# frozen_string_literal: true

module Openmath
  # The canonical tagged form of a typed model (the testsuite's
  # tree-parity contract): every captured value is a tagged node with
  # exactly one tag, so two values compare equal only when the Ruby
  # values are the same in every way that matters. Models capture
  # through their declared attributes and types, never through inspect;
  # nil fields are left out; numbers keep their text; child order is
  # never sorted. Tag keys are plain strings so the YAML round trip
  # stays within safe_load's portable classes.
  module Tagged
    module_function

    def node(object)
      case object
      when Lutaml::Model::Serializable then model(object)
      when Hash
        { "hash" => object.map { |key, value| [node(key), node(value)] } }
      when Array then { "array" => object.map { |item| node(item) } }
      when Symbol then { "sym" => object.to_s }
      when Integer then { "int" => object.to_s }
      when Float then { "float" => object.inspect }
      when true, false then { "bool" => object }
      when nil then { "nil" => true }
      else { "str" => object.to_s }
      end
    end

    def model(object)
      fields = object.class.attributes.filter_map do |name, attribute|
        value = object.public_send(name)
        next if value.nil?
        next if attribute.collection? && Array(value).empty?

        [name.to_s, node(value)]
      end
      { "node" => object.class.name, "fields" => fields }
    end
  end
end
