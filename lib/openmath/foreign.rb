# frozen_string_literal: true

require "nokogiri"

module Openmath
  # Foreign-markup capture for OMFOREIGN (the schema's notOM content).
  #
  # lutaml-model's mapping DSL has no representation for arbitrary-markup
  # children, so capture rides a source-side pass: after the typed parse,
  # the document is re-walked with nokogiri in parallel with the model
  # tree, and every OMFOREIGN's foreign children (elements outside the
  # OpenMath namespace) are serialized verbatim into the instance's
  # +notom_value+, with +notom_positions+ recording how many OpenMath
  # children precede each fragment. Serialization writes the fragments
  # back at those positions through Base::Omobj's to_xml override.
  module Foreign
    OPENMATH_NS = "http://www.openmath.org/OpenMath"
    SAVE_OPTIONS = Nokogiri::XML::Node::SaveOptions::AS_XML

    module_function

    # True when any OMFOREIGN in the object carries captured fragments.
    def contained?(object)
      children(object).any? do |child|
        next true if omforeign?(child) && Array(child.notom_value).any?

        contained?(child)
      end
    end

    # Walks the model object alongside +source+ and fills every
    # Omforeign's notom_value/notom_positions from the serialized foreign
    # children in document order. Nested OMFOREIGN objects descend.
    def capture(object, source)
      root = Nokogiri.XML(source).root
      return object unless root

      capture_node(object, root)
      object
    end

    # Inserts the captured fragments back into a serialized document,
    # locating each OMFOREIGN node by the same positional pairing capture
    # used, and re-serializes.
    def inject_tree(object, xml_string)
      doc = Nokogiri.XML(xml_string)
      place(object, doc.root)
      root_serialize(doc)
    end

    # Appends the fragments of a standalone Omforeign serialization.
    def inject(xml, fragments)
      doc = Nokogiri.XML(xml)
      target = doc.root
      return xml.to_s unless target

      fragments.each do |fragment|
        node = Nokogiri.XML(fragment).root
        target.add_child(node) if node
      end
      root_serialize(doc)
    end

    def capture_node(model, node)
      om_children = 0
      foreign = []
      positions = []
      cursor = child_cursor(model)

      node.element_children.each do |child|
        model_child = cursor.call(child.name)
        om_children += 1 if model_child || openmath_child?(child)
        if model_child
          capture_node(model_child, child)
        elsif !openmath_child?(child)
          foreign << child
          positions << om_children
        end
      end

      return unless omforeign?(model)

      model.notom_value = foreign.map { |n| n.to_xml(save_with: SAVE_OPTIONS) }
      model.notom_positions = positions
    end

    def place(model, node)
      cursor = child_cursor(model)

      node.element_children.each do |child|
        model_child = cursor.call(child.name)
        next unless model_child

        place(model_child, child)
        next unless omforeign?(model_child)

        insert_fragments(child, model_child)
      end
    end

    def insert_fragments(node, model)
      fragments = Array(model.notom_value)
      positions = Array(model.notom_positions)
      siblings = node.element_children.select { |c| openmath_child?(c) }
      fragments.each_with_index do |fragment, i|
        fragment_node = Nokogiri.XML(fragment).root
        next unless fragment_node

        anchor = siblings[positions[i]] if positions[i]
        anchor ? anchor.add_previous_sibling(fragment_node) : node.add_child(fragment_node)
      end
    end

    def omforeign?(model)
      model.is_a?(V2::Omforeign) || model.is_a?(V3::Omforeign)
    end

    def openmath_child?(node)
      (node.namespace&.href || OPENMATH_NS) == OPENMATH_NS
    end

    # Document-order model child of +name+ matched positionally against
    # the walk (the evaluator's per-name cursor contract).
    def child_cursor(model)
      seen = Hash.new(0)
      lambda do |name|
        attribute = Evaluation::Evaluator::CHILD_ATTRIBUTES[name]
        return nil unless attribute

        values = Array(model.public_send(attribute))
        index = seen[name]
        seen[name] += 1
        values[index]
      end
    end

    def children(object)
      Evaluation::Evaluator::CHILD_ATTRIBUTES.values
        .flat_map { |attribute| Array(object.public_send(attribute)) }
    end

    def root_serialize(doc)
      doc.root.to_xml(save_with: SAVE_OPTIONS)
    end
  end
end
