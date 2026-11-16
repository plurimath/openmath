# frozen_string_literal: true

require "nokogiri"

module Openmath
  module Evaluation
    # Order belongs to a container, not to its per-type collections. Source
    # slots and builder slots are checked against the current collections on
    # every read so a mutation cannot silently change operand order.
    module Children
      NAMESPACE = "http://www.openmath.org/OpenMath"
      ATTRIBUTES = %w[OMS OMV OMI OMB OMSTR OMF OMA OMBIND OMBVAR OME OMATTR OMATP OMFOREIGN OMR]
        .to_h { |name| [name, :"#{name.downcase}_value"] }.freeze
      CONTAINERS = %w[OMOBJ OMA OMBIND OMBVAR OME OMATTR OMATP].freeze
      SLOT_VARIABLE = :@openmath_child_slots

      # Installed on each version's model parent once its context is ready.
      # This also covers callers of the public Model.from_xml API.
      module XMLParser
        def from_xml(input, *args, **options)
          source = input.respond_to?(:read) ? input.read : input
          object = super(source, *args, **options)
          Children.capture(object, source)
        end
      end

      module_function

      def values(container)
        ATTRIBUTES.to_h do |name, attribute|
          [name, container.respond_to?(attribute) ? Array(container.public_send(attribute)) : []]
        end
      end

      def refuse(container, reason)
        raise ChildrenOrderError, "#{container.class}: #{reason}"
      end

      # Binary and programmatic builders must explicitly state the order.
      def assign(container, children)
        slots = children.to_a.dup.freeze
        validate(container, slots)
        container.instance_variable_set(SLOT_VARIABLE, slots)
        container
      end

      def validate(container, slots)
        actual = values(container).values.flatten
        unless slots.map(&:object_id).tally == actual.map(&:object_id).tally
          refuse(container, "child slots do not match current collections")
        end
        slots
      end

      def ordered(container)
        if container.instance_variable_defined?(SLOT_VARIABLE)
          return validate(container, container.instance_variable_get(SLOT_VARIABLE)).dup
        end

        collections = values(container)
        cursors = Hash.new(0)
        slots = Array(container.element_order).map do |element|
          name = element.name
          refuse(container, "unknown order element #{name.inspect}") unless ATTRIBUTES.key?(name)
          if element.respond_to?(:namespace_uri) && element.namespace_uri && element.namespace_uri != NAMESPACE
            refuse(container, "foreign order namespace #{element.namespace_uri.inspect} for #{name}")
          end
          child = collections.fetch(name)[cursors[name]]
          cursors[name] += 1
          refuse(container, "order exceeds collection #{name}") unless child
          child
        end
        validate(container, slots).dup
      end

      # Explicit characterization of the former type-grouped fallback. This
      # method is never called by evaluation or ordered().
      def legacy_grouped(container, compatibility: false)
        refuse(container, "legacy grouping requires compatibility: true") unless compatibility
        values(container).values.flatten
      end

      def capture(container, input)
        document = Nokogiri::XML(input) { |config| config.strict.nonet }
        capture_node(container, document.root)
        container
      rescue Nokogiri::XML::SyntaxError => e
        refuse(container, "invalid source XML: #{e.message}")
      end

      def capture_node(container, source)
        return unless CONTAINERS.include?(source.name)
        unless source.namespace&.href == NAMESPACE
          refuse(container, "source namespace #{source.namespace&.href.inspect} for #{source.name}")
        end
        collections = values(container)
        cursors = Hash.new(0)
        slots = source.element_children.map do |element|
          name = element.name
          unless element.namespace&.href == NAMESPACE && ATTRIBUTES.key?(name)
            refuse(container, "source child {#{element.namespace&.href}}#{name}")
          end
          child = collections.fetch(name)[cursors[name]]
          cursors[name] += 1
          refuse(container, "source child #{name} missing from model") unless child
          capture_node(child, element)
          child
        end
        assign(container, slots)
      end
    end
  end
end
