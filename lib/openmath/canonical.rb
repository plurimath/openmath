# frozen_string_literal: true

require "digest"

module Openmath
  # The canonical serialization profile: the single deterministic form of
  # an OpenMath object, invariant under syntactic variation — attribute
  # order (sorted alphabetically), namespace prefix choice (the default
  # namespace is declared once on the root of the canonical form),
  # inter-element whitespace (none), OMI/OMB insignificant internal
  # whitespace (stripped), and spelling normalization of insignificant
  # differences. OMSTR text and OMFOREIGN fragments are content and stay
  # verbatim. OMF dec/hex spellings are preserved (dec is not lossless to
  # hex); OMR references are preserved unexpanded (resolution is a
  # separate operation).
  module Canonical
    NAMESPACE = "http://www.openmath.org/OpenMath"

    module_function

    def xml(object)
      out = +""
      element(object, out, root: true)
      out
    end

    def sha256(object)
      Digest::SHA256.hexdigest(xml(object))
    end

    def equal?(left, right)
      sha256(left) == sha256(right)
    end

    def element(node, out, root: false)
      name = element_name(node)
      out << "<#{name}"
      out << %( xmlns="#{NAMESPACE}") if root
      canonical_attributes(node).each do |key, value|
        out << %( #{key}="#{escape(value, attribute: true)}")
      end
      text = content_text(node)
      children = ordered_children(node)
      fragments = foreign_fragments(node)
      if text.nil? && children.empty? && fragments.empty?
        out << "/>"
        return
      end

      out << ">"
      out << escape(text) unless text.nil?
      emit_children(node, children, fragments, out)
      out << "</#{name}>"
    end

    def emit_children(node, children, fragments, out)
      return children.each { |child| element(child, out) } if fragments.empty?

      emitted = 0
      positions = Array(node.notom_positions)
      children.each_with_index do |child, index|
        while emitted < fragments.size && positions[emitted] == index
          out << fragments[emitted]
          emitted += 1
        end
        element(child, out)
      end
      fragments.drop(emitted).each { |fragment| out << fragment }
    end

    def canonical_attributes(node)
      attributes = {
        "cdbase" => node.respond_to?(:cdbase) ? node.cdbase : nil,
        "cd" => node.respond_to?(:cd) ? node.cd : nil,
        "encoding" => node.respond_to?(:foreign_encoding) ? node.foreign_encoding : nil,
        "href" => node.respond_to?(:href) ? node.href : nil,
        "id" => node.id,
        "name" => node.respond_to?(:name) ? node.name : nil,
        "version" => node.respond_to?(:version) ? node.version : nil,
        "dec" => omf_attribute(node, :dec),
        "hex" => omf_attribute(node, :hex),
      }
      attributes.filter_map do |key, value|
        next unless value

        [key, value]
      end
    end

    def omf_attribute(node, key)
      return unless node.is_a?(V2::Omf) || node.is_a?(V3::Omf)

      node.public_send(key)
    end

    def content_text(node)
      case node
      when V2::Omstr, V3::Omstr
        Array(node.value).join
      when V2::Omb, V3::Omb
        Array(node.value).join.gsub(/\s+/, "")
      when V2::Omi, V3::Omi
        Array(node.value).join.gsub(/\s+/, "")
      end
    end

    def ordered_children(node)
      Evaluation::Evaluator.ordered_children(node)
    end

    def foreign_fragments(node)
      return [] unless node.is_a?(V2::Omforeign) || node.is_a?(V3::Omforeign)

      Array(node.notom_value)
    end

    def element_name(node)
      node.class.mappings_for(:xml).element_name
    end

    def escape(value, attribute: false)
      text = value.to_s
      text = text.gsub("&", "&amp;").gsub("<", "&lt;").gsub(">", "&gt;")
      attribute ? text.gsub('"', "&quot;") : text
    end
  end
end
