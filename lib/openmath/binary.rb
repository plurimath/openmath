# frozen_string_literal: true

require "base64"

module Openmath
  # The OpenMath 2 binary encoding (omstd20, the binary encoding chapter):
  # a compact tagged byte format with the shared-object optimization.
  #
  # The writer emits the [88] framing (references enabled) when the object
  # carries a version attribute, the plain [24] framing otherwise. It never
  # streams packets and shares exactly the OMR-referenced targets; the id
  # strings themselves have no carrier in the binary format, so the reader
  # synthesizes ids for referenced targets. The reader honors both framings,
  # streaming packets for the basic objects, internal references, cdbase
  # scopes, and refuses everything it cannot decode with a typed error.
  module Binary
    # Malformed binary: truncation, bad tags, bad sign/base bytes, invalid
    # or forward references.
    class Error < StandardError; end

    TAG_INTEGER = 1
    TAG_BIG_INTEGER = 2
    TAG_FLOAT = 3
    TAG_BYTEARRAY = 4
    TAG_VARIABLE = 5
    TAG_STRING8 = 6
    TAG_STRING16 = 7
    TAG_SYMBOL = 8
    TAG_CDBASE = 9
    TAG_FOREIGN = 12
    TAG_APPLICATION = 16
    TAG_ATTRIBUTION = 18
    TAG_ATTRPAIRS = 20
    TAG_ERROR = 22
    TAG_BINDING = 26
    TAG_BVARS = 28
    TAG_INTERNAL_REFERENCE = 30
    TAG_EXTERNAL_REFERENCE = 31
    TAG_END_OBJECT = 25

    STREAMING_BIT = 0x20
    SHARED_BIT = 0x40
    LONG_BIT = 0x80

    ELEMENT_TAGS = {
      "OMI" => TAG_INTEGER, "OMF" => TAG_FLOAT, "OMV" => TAG_VARIABLE,
      "OMB" => TAG_BYTEARRAY, "OMSTR" => TAG_STRING8, "OMS" => TAG_SYMBOL,
      "OMFOREIGN" => TAG_FOREIGN,
    }.freeze

    module_function

    # Encodes the model (or XML text) to the binary encoding.
    def encode(object_or_xml, version: 2)
      object = object_or_xml.is_a?(String) ? Openmath.parse(object_or_xml, version: version) : object_or_xml
      Writer.new(object).bytes
    end

    # Decodes the binary encoding into the versioned OMOBJ model; the
    # framing's major version selects the hierarchy unless overridden.
    def decode(bytes, version: nil)
      Decoder.new(bytes).decode(version: version)
    end

    def length_bytes(long)
      long ? 4 : 1
    end

    def read_length(reader, long)
      long ? reader.read_uint32 : reader.read_byte
    end

    def write_length(out, value)
      if value >= 256
        out << [value].pack("N")
      else
        out << value.chr
      end
    end

    # A byte cursor: every overrun is a truncation error naming its offset.
    class Reader
      attr_reader :bytes, :pos

      def initialize(bytes)
        @bytes = bytes.b
        @pos = 0
        @shared = []
      end

      def eof?
        @pos >= @bytes.bytesize
      end

      def read_byte
        raise Error, "truncated: expected a byte at #{@pos}" if eof?

        byte = @bytes.getbyte(@pos)
        @pos += 1
        byte
      end

      def read_uint32
        if @pos + 4 > @bytes.bytesize
          raise Error, "truncated: expected 4 bytes at #{@pos}"
        end

        value = @bytes.byteslice(@pos, 4).unpack1("N")
        @pos += 4
        value
      end

      def read_bytes(count)
        if @pos + count > @bytes.bytesize
          raise Error, "truncated: expected #{count} bytes at #{@pos}"
        end

        data = @bytes.byteslice(@pos, count)
        @pos += count
        data.b
      end

      def read_tag
        byte = read_byte
        [byte & 0x1F, byte & STREAMING_BIT != 0, byte & SHARED_BIT != 0,
         byte & LONG_BIT != 0]
      end

      def unread_tag
        @pos -= 1
      end

      def signed_value(uint)
        uint >= 0x80000000 ? uint - (1 << 32) : uint
      end

      def record_shared(node)
        @shared << node
      end

      def shared_object(ordinal)
        node = @shared[ordinal]
        raise Error, "internal reference #{ordinal} exceeds the #{@shared.size} shared objects" if node.nil?

        node
      end
    end

    # The decoder: framing, then the object, then the end tag.
    class Decoder
      def initialize(bytes)
        @reader = Reader.new(bytes)
      end

      def decode(version: nil)
        major, minor, referenced = read_framing
        hierarchy = version || (major == 3 ? :V3 : :V2)
        Openmath.const_get(hierarchy).register_models!
        root = Openmath.const_get(hierarchy).const_get(:Omobj).new
        root.version = "#{major}.#{minor}" if referenced
        child = read_object(referenced: referenced, hierarchy: hierarchy)
        slot(root, child)

        expect_tag(TAG_END_OBJECT)
        raise Error, "trailing bytes after the object" unless @reader.eof?

        root
      end

      # The framings share the 5-bit object tag; the shared flag bit
      # distinguishes [24] (plain) from [24+64] (versioned, references).
      def read_framing
        tag, _streaming, shared, = @reader.read_tag
        raise Error, "expected an object start tag, got #{tag}" unless tag == 24

        if shared
          [@reader.read_byte, @reader.read_byte, true]
        else
          [2, 0, false]
        end
      end

      def read_object(referenced:, hierarchy:)
        tag, streaming, shared, long = @reader.read_tag
        if streaming && !streamable?(tag)
          raise Error, "streaming bit on unstreamable tag #{tag}"
        end

        node = case tag
               when TAG_INTEGER then streaming ? read_streamed_small_integer(hierarchy) : read_small_integer(long, hierarchy)
               when TAG_BIG_INTEGER then read_big_integer(streaming, long, hierarchy)
               when TAG_FLOAT then read_float(long, hierarchy)
               when TAG_BYTEARRAY then read_bytearray(streaming, long, hierarchy)
               when TAG_VARIABLE then read_variable(long, hierarchy)
               when TAG_STRING8 then read_string8(streaming, long, hierarchy)
               when TAG_STRING16 then read_string16(streaming, long, hierarchy)
               when TAG_SYMBOL then read_symbol(long, hierarchy)
               when TAG_CDBASE then read_cdbase(long, referenced, hierarchy)
               when TAG_FOREIGN then read_foreign(streaming, long, hierarchy)
               when TAG_APPLICATION then read_children_until(TAG_APPLICATION + 1, referenced, hierarchy, model(hierarchy, :Oma))
               when TAG_ATTRIBUTION then read_attribution(referenced, hierarchy)
               when TAG_ERROR then read_error(referenced, hierarchy)
               when TAG_BINDING then read_binding(referenced, hierarchy)
               when TAG_INTERNAL_REFERENCE then read_internal_reference(long, hierarchy)
               when TAG_EXTERNAL_REFERENCE then read_external_reference(long, hierarchy)
               else raise Error, "unknown tag #{tag} at #{@reader.pos - 1}"
               end
        @reader.record_shared(node) if shared
        node
      end

      def streamable?(tag)
        [TAG_INTEGER, TAG_BIG_INTEGER, TAG_BYTEARRAY, TAG_STRING8,
         TAG_STRING16, TAG_FOREIGN].include?(tag)
      end

      # Packets of the same tag accumulate until one clears the streaming
      # bit; shared flags never appear on packets.
      def read_streaming(tag, &read_packet)
        chunks = []
        loop do
          packet_tag, streaming, shared, long = @reader.read_tag
          raise Error, "shared flag on a streamed packet" if shared
          raise Error, "streamed packet tag #{packet_tag} contradicts #{tag}" if packet_tag != tag

          chunks << read_packet.call(long)
          break unless streaming
        end
        chunks
      end

      def read_small_integer(long, hierarchy)
        value = long ? @reader.signed_value(@reader.read_uint32) : @reader.read_byte
        value -= 256 if !long && value >= 128
        integer_node(value, hierarchy)
      end

      # Streamed small-integer packets assemble as most-significant-first
      # base-128 digits; only the initial packet carries the sign.
      def read_streamed_small_integer(hierarchy)
        digits = read_streaming(TAG_INTEGER) do |long|
          digit = long ? @reader.signed_value(@reader.read_uint32) : @reader.read_byte
          raise Error, "base-128 digit #{digit} out of range" if !long && digit >= 128

          digit
        end
        value = digits.first >= 128 ? digits.first - 256 : digits.first
        digits.drop(1).each { |digit| value = value * 128 + digit }
        integer_node(value, hierarchy)
      end

      def read_big_integer(streaming, long, hierarchy)
        chunks = streaming ? read_streaming(TAG_BIG_INTEGER) { |l| read_length_bytes(l) } : [read_length_bytes(long)]
        text = chunks.join.b
        raise Error, "big integer without a sign/base byte" if text.empty?

        sign_base = text.slice!(0).getbyte(0)
        digits = text
        value = case sign_base & 0xC0
                when 0x80 then digits.bytes.inject(0) { |acc, byte| (acc << 8) | byte }
                when 0x40 then Integer("0x#{digits}")
                else Integer(digits)
                end
        value = -value if (sign_base & 0x3F) == 0x2D
        integer_node(value, hierarchy)
      end

      def read_length_bytes(long)
        @reader.read_bytes(Openmath::Binary.read_length(@reader, long))
      end

      def read_length(long)
        Openmath::Binary.read_length(@reader, long)
      end

      def integer_node(value, hierarchy)
        node = model(hierarchy, :Omi)
        node.value = [value.to_s]
        node
      end

      def read_float(_long, hierarchy)
        bits = @reader.read_bytes(8).unpack1("G")
        node = model(hierarchy, :Omf)
        node.dec = bits.to_s
        node
      end

      def read_bytearray(streaming, long, hierarchy)
        bytes = streaming ? read_streaming(TAG_BYTEARRAY) { |l| read_length_bytes(l) }.join : read_length_bytes(long)
        node = model(hierarchy, :Omb)
        node.value = [Base64.strict_encode64(bytes)]
        node
      end

      def read_string8(streaming, long, hierarchy)
        text = streaming ? read_streaming(TAG_STRING8) { |l| read_length_bytes(l) }.join : read_length_bytes(long)
        string_node(text.force_encoding("UTF-8"), hierarchy)
      end

      # A string16 length counts UTF-16 units; the payload is 2n bytes.
      def read_string16(streaming, long, hierarchy)
        chunks = streaming ? read_streaming(TAG_STRING16) { |l| @reader.read_bytes(2 * read_length(l)) } : [@reader.read_bytes(2 * read_length(long))]
        string_node(chunks.join.force_encoding("UTF-16BE").encode("UTF-8"), hierarchy)
      end

      def string_node(text, hierarchy)
        node = model(hierarchy, :Omstr)
        node.value = [text]
        node
      end

      def read_variable(long, hierarchy)
        node = model(hierarchy, :Omv)
        node.name = @reader.read_bytes(read_length(long)).force_encoding("UTF-8")
        node
      end

      def read_symbol(long, hierarchy)
        cd_length = read_length(long)
        name_length = read_length(long)
        node = model(hierarchy, :Oms)
        node.cd = @reader.read_bytes(cd_length).force_encoding("UTF-8")
        node.name = @reader.read_bytes(name_length).force_encoding("UTF-8")
        node
      end

      def read_cdbase(long, referenced, hierarchy)
        uri = @reader.read_bytes(read_length(long)).force_encoding("UTF-8")
        child = read_object(referenced: referenced, hierarchy: hierarchy)
        child.cdbase = uri if child.respond_to?(:cdbase=)
        child
      end

      def read_foreign(streaming, long, hierarchy)
        chunks = streaming ? read_streaming(TAG_FOREIGN) { |l| read_foreign_packet(l) } : [read_foreign_packet(long)]
        encoding, payload = chunks.transpose.map(&:join)
        node = model(hierarchy, :Omforeign)
        node.foreign_encoding = encoding.force_encoding("UTF-8")
        node.notom_value = payload.empty? ? [] : [payload.force_encoding("UTF-8")]
        node
      end

      def read_foreign_packet(long)
        encoding_length = read_length(long)
        payload_length = read_length(long)
        [@reader.read_bytes(encoding_length), @reader.read_bytes(payload_length)]
      end

      # Applications and other plain containers: children until the end
      # tag, each slotted by its element name.
      def read_children_until(end_tag, referenced, hierarchy, node)
        until peek_tag == end_tag
          slot(node, read_object(referenced: referenced, hierarchy: hierarchy))
        end
        consume_tag(end_tag)
        node
      end

      def read_attribution(referenced, hierarchy)
        node = model(hierarchy, :Omattr)
        pairs = model(hierarchy, :Omatp)
        expect_tag(TAG_ATTRPAIRS)
        until peek_tag == TAG_ATTRPAIRS + 1
          slot(pairs, read_object(referenced: referenced, hierarchy: hierarchy))
        end
        consume_tag(TAG_ATTRPAIRS + 1)
        slot(node, pairs)
        slot(node, read_object(referenced: referenced, hierarchy: hierarchy))
        expect_tag(TAG_ATTRIBUTION + 1)
        node
      end

      def read_error(referenced, hierarchy)
        node = read_children_until(TAG_ERROR + 1, referenced, hierarchy, model(hierarchy, :Ome))
        unless node.oms_value&.first
          raise Error, "error constructor without a leading symbol"
        end

        node
      end

      def read_binding(referenced, hierarchy)
        node = model(hierarchy, :Ombind)
        slot(node, read_object(referenced: referenced, hierarchy: hierarchy))
        expect_tag(TAG_BVARS)
        vars_container = model(hierarchy, :Ombvar)
        until peek_tag == TAG_BVARS + 1
          slot(vars_container, read_object(referenced: referenced, hierarchy: hierarchy))
        end
        consume_tag(TAG_BVARS + 1)
        slot(node, vars_container)
        slot(node, read_object(referenced: referenced, hierarchy: hierarchy))
        expect_tag(TAG_BINDING + 1)
        node
      end

      # The ordinal names the n+1-th shared sub-object; a referenced
      # target's original id has no carrier in the binary format, so one
      # is synthesized (stable from the first re-serialization on).
      def read_internal_reference(long, hierarchy)
        ordinal = read_length(long)
        target = @reader.shared_object(ordinal)
        node = model(hierarchy, :Omr)
        node.href = "##{target.id || "omr-#{ordinal}"}"
        target.id ||= "omr-#{ordinal}" if target.respond_to?(:id=)
        node
      end

      def read_external_reference(long, hierarchy)
        node = model(hierarchy, :Omr)
        node.href = @reader.read_bytes(read_length(long)).force_encoding("UTF-8")
        node
      end

      def peek_tag
        tag, = @reader.read_tag
        @reader.unread_tag
        tag
      end

      def consume_tag(expected)
        tag, = @reader.read_tag
        raise Error, "expected tag #{expected}, got #{tag}" if tag != expected
      end

      def expect_tag(expected)
        consume_tag(expected)
      end

      def slot(node, child)
        name = child.class.mappings_for(:xml).element_name
        attribute = Evaluation::Evaluator::CHILD_ATTRIBUTES[name]
        if attribute.nil? || !node.respond_to?("#{attribute}=")
          raise Error, "child #{name} is not allowed in #{node.class.mappings_for(:xml).element_name}"
        end

        collection = node.public_send(attribute) || []
        node.public_send(:"#{attribute}=", collection + [child])
        # Document order survives only through the order tracking; decoded
        # children record themselves so serialization walks them in order.
        order = node.element_order ||= []
        order << Lutaml::Xml::Element.new("Element", name, node_type: :element)
      end

      def model(hierarchy, name)
        Openmath.const_get(hierarchy).const_get(name).new
      end
    end

    # The encoder: one pass, no streaming, shared flags on exactly the
    # OMR-referenced targets.
    class Writer
      def initialize(root)
        @root = root
        @referenced = {}
        collect_references(root)
        @ordinals = {}
      end

      def bytes
        out = +"".b
        version = @root.respond_to?(:version) ? @root.version : nil
        if version && !version.to_s.empty?
          major, minor = version.to_s.split(".").map { |part| Integer(part) }
          out << (24 + 64).chr << major.chr << minor.chr
        else
          out << 24.chr
        end
        write_object(@root, out)
        out << TAG_END_OBJECT.chr
        out
      end

      def collect_references(node)
        CHILDREN(node).each { |child| collect_references(child) }
        return unless node.is_a?(V2::Omr) || node.is_a?(V3::Omr)

        href = node.href.to_s
        return unless href.start_with?("#")

        id = href[1..]
        @referenced[id] ||= find_by_id(@root, id)
      end

      def find_by_id(node, id)
        return node if node.respond_to?(:id) && node.id == id

        CHILDREN(node).each do |child|
          found = find_by_id(child, id)
          return found if found
        end
        nil
      end

      def CHILDREN(node)
        return [] unless node.respond_to?(:element_order)

        Evaluation::Evaluator.ordered_children(node)
      end

      def write_object(node, out)
        if node.is_a?(V2::Omr) || node.is_a?(V3::Omr)
          write_reference(node, out)
          return
        end

        unless cdbase(node).nil?
          uri = cdbase(node)
          out << TAG_CDBASE.chr
          out << (uri.bytesize >= 256 ? 1 : 0).chr
          Binary.write_length(out, uri.bytesize)
          out << uri.b
        end

        shared = mark_shared(node)
        name = node.class.mappings_for(:xml).element_name
        send("write_#{name.downcase}", node, out, shared)
      end

      def cdbase(node)
        node.respond_to?(:cdbase) && !node.is_a?(V2::Omobj) && !node.is_a?(V3::Omobj) ? node.cdbase : nil
      end

      def mark_shared(node)
        return false unless node.respond_to?(:id) && @referenced.value?(node)
        return true if @ordinals.key?(node.object_id)

        @ordinals[node.object_id] = @ordinals.size
        true
      end

      def write_reference(node, out)
        href = node.href.to_s
        unless href.start_with?("#")
          long = href.bytesize >= 256
          out << tag_byte(TAG_EXTERNAL_REFERENCE, false, long)
          Binary.write_length(out, href.bytesize)
          out << href.b
          return
        end

        target = @referenced[href[1..]]
        raise Error, "OMR href #{href.inspect} has no target in the object" if target.nil?

        ordinal = @ordinals[target.object_id]
        if ordinal.nil?
          raise Error, "forward reference: #{href.inspect} targets an object not yet encoded"
        end

        if ordinal < 256
          out << TAG_INTERNAL_REFERENCE.chr << ordinal.chr
        else
          out << (TAG_INTERNAL_REFERENCE + LONG_BIT).chr << [ordinal].pack("N")
        end
      end

      def write_integer(node, out, shared)
        value = Integer(node.value.join.gsub(/\s+/, ""))
        if value.between?(-128, 127)
          out << tag_byte(TAG_INTEGER, shared, false)
          out << (value & 0xFF).chr
        elsif value.between?(-(1 << 31), (1 << 31) - 1)
          out << tag_byte(TAG_INTEGER, shared, true)
          out << [value & 0xFFFFFFFF].pack("N")
        else
          digits = value.abs.to_s
          long = digits.bytesize >= 256
          out << tag_byte(TAG_BIG_INTEGER, shared, long)
          Binary.write_length(out, digits.bytesize + 1)
          out << (value.negative? ? 0x2D : 0x2B).chr << digits.b
        end
      end

      def write_float(node, out, shared)
        out << tag_byte(TAG_FLOAT, shared, false)
        bits = node.hex ? [node.hex].pack("H*").unpack1("G") : Float(node.dec)
        out << [bits].pack("G")
      end

      def write_variable(node, out, shared)
        name = node.name.to_s
        long = name.bytesize >= 256
        out << tag_byte(TAG_VARIABLE, shared, long)
        Binary.write_length(out, name.bytesize)
        out << name.b
      end

      def write_symbol(node, out, shared)
        cd = node.cd.to_s
        name = node.name.to_s
        long = [cd, name].map { |part| part.bytesize }.max >= 256
        out << tag_byte(TAG_SYMBOL, shared, long)
        Binary.write_length(out, cd.bytesize)
        Binary.write_length(out, name.bytesize)
        out << cd.b << name.b
      end

      def write_omstr(node, out, shared)
        text = node.value.join
        if text.ascii_only? || text.encoding == Encoding::UTF_8 && text.bytes.none? { |b| b > 0x7F }
          long = text.bytesize >= 256
          out << tag_byte(TAG_STRING8, shared, long)
          Binary.write_length(out, text.bytesize)
          out << text.b
        else
          units = text.encode("UTF-16BE").bytesize / 2
          long = units >= 256
          out << tag_byte(TAG_STRING16, shared, long)
          Binary.write_length(out, units)
          out << text.encode("UTF-16BE").b
        end
      end

      def write_omb(node, out, shared)
        bytes = Base64.decode64(node.value.join)
        long = bytes.bytesize >= 256
        out << tag_byte(TAG_BYTEARRAY, shared, long)
        Binary.write_length(out, bytes.bytesize)
        out << bytes
      end

      def write_omforeign(node, out, shared)
        encoding = node.foreign_encoding.to_s
        payload = Array(node.notom_value).join
        long = [encoding, payload].map { |part| part.bytesize }.max >= 256
        out << tag_byte(TAG_FOREIGN, shared, long)
        Binary.write_length(out, encoding.bytesize)
        Binary.write_length(out, payload.bytesize)
        out << encoding.b << payload.b
      end

      # The frame carries the root: version rode the framing bytes, and the
      # root cdbase is not representable in the binary format — its single
      # child is what gets encoded.
      def write_omobj(node, out, _shared)
        child = CHILDREN(node).first
        raise Error, "empty OMOBJ" unless child

        write_object(child, out)
      end

      def write_oma(node, out, shared)
        write_compound(node, out, shared, TAG_APPLICATION, TAG_APPLICATION + 1)
      end

      def write_ome(node, out, shared)
        write_compound(node, out, shared, TAG_ERROR, TAG_ERROR + 1)
      end

      def write_omattr(node, out, shared)
        out << tag_byte(TAG_ATTRIBUTION, shared, false)
        pairs = node.omatp_value&.first
        raise Error, "attribution without OMATP pairs" unless pairs

        out << TAG_ATTRPAIRS.chr
        CHILDREN(pairs).each { |child| write_object(child, out) }
        out << (TAG_ATTRPAIRS + 1).chr
        attributed = Evaluation::Evaluator.ordered_children(node).last
        raise Error, "attribution without an attributed object" if attributed.nil? || pairs.equal?(attributed)

        write_object(attributed, out)
        out << (TAG_ATTRIBUTION + 1).chr
      end

      def write_ombind(node, out, shared)
        out << tag_byte(TAG_BINDING, shared, false)
        write_object(node.oms_value.first, out)
        out << TAG_BVARS.chr
        vars = node.ombvar_value&.first
        raise Error, "binding without OMBVAR" unless vars

        CHILDREN(vars).each { |child| write_object(child, out) }
        out << (TAG_BVARS + 1).chr
        body = Evaluation::Evaluator.ordered_children(node).drop(2).first
        raise Error, "binding without a body" unless body

        write_object(body, out)
        out << (TAG_BINDING + 1).chr
      end

      def write_compound(node, out, shared, start_tag, end_tag)
        out << tag_byte(start_tag, shared, false)
        CHILDREN(node).each { |child| write_object(child, out) }
        out << end_tag.chr
      end

      def tag_byte(tag, shared, long)
        tag | (shared ? SHARED_BIT : 0) | (long ? LONG_BIT : 0)
      end

      # The element-name dispatch spellings.
      def write_omi(node, out, shared) = write_integer(node, out, shared)
      def write_omf(node, out, shared) = write_float(node, out, shared)
      def write_omv(node, out, shared) = write_variable(node, out, shared)
      def write_oms(node, out, shared) = write_symbol(node, out, shared)
    end
  end
end
