# frozen_string_literal: true

require "moxml"

module Openmath
  # The Content MathML v4 encoding (the plurimath#35 re-parenting:
  # Content MathML rides the openmath gem's content models, so the
  # semantic layer is shared with the XML and binary encodings).
  #
  # The reader accepts the strict core — csymbol, apply, ci, cn, cs,
  # lambda/bvar — and the non-strict operator elements of the MathML 4
  # content operator table (plus, times, eq, ...), which transform
  # exactly the way the standard's Strict Content MathML Transformation
  # Algorithm does: element to csymbol (ContentMathMLOperators::TABLE),
  # arguments to an apply. The writer always emits the strict form.
  # Everything the semantic core cannot carry — presentation elements,
  # qualifier elements, cn types with no OpenMath form, OMB and
  # OMFOREIGN with no Content MathML form — refuses with a typed error.
  module ContentMathML
    # Malformed Content MathML: unknown elements, missing attributes,
    # qualifiers and presentation markup outside the semantic core.
    class Error < StandardError; end

    NAMESPACE = "http://www.w3.org/1998/Math/MathML"

    module_function

    # Parses Content MathML into the versioned object model: the parsed
    # object slots into an OMOBJ root, as the XML and binary readers do.
    def parse(input, version: 2)
      doc = Moxml.parse(input)
      root = doc.root
      raise Error, "no root element" unless root

      hierarchy = version == 3 ? :V3 : :V2
      Openmath.const_get(hierarchy).register_models!
      omobj = Openmath.const_get(hierarchy).const_get(:Omobj).new
      child = Reader.new(version: version).element(root)
      name = child.class.mappings_for(:xml).element_name
      attribute = Evaluation::Evaluator::CHILD_ATTRIBUTES[name]
      raise Error, "child #{name} is not allowed in OMOBJ" if attribute.nil?

      omobj.public_send(:"#{attribute}=", [child])
      omobj.element_order ||= []
      omobj.element_order << Lutaml::Xml::Element.new("Element", name, node_type: :element)
      omobj
    end

    # Serializes the model (or XML text) to the strict Content MathML form.
    def generate(object_or_xml, version: 2)
      object = object_or_xml.is_a?(String) ? Openmath.parse(object_or_xml, version: version) : object_or_xml
      Writer.new(object).document
    end

    def content_element(name, children = nil, attributes = nil)
      attributes_arg = attributes && !attributes.empty? ? attributes : nil
      doc = children&.first&.document || Moxml.new.create_document
      node = doc.create_element(name)
      attributes_arg&.each { |key, value| node[key] = value }
      children&.each { |child| node.add_child(child) }
      node
    end

    # The reader: one Content MathML element at a time.
    class Reader
      def initialize(version:)
        @version = version
      end

      def hierarchy
        @hierarchy ||= Openmath.const_get(@version == 3 ? :V3 : :V2)
      end

      def element(node)
        name = node.name
        case name
        when "OMOBJ", "math" then single(node)
        when "csymbol" then csymbol(node)
        when "apply" then apply(node)
        when "lambda" then lambda_node(node)
        when "ci" then variable(node)
        when "cn" then number(node)
        when "cs" then string(node)
        when ContentMathMLOperators::TABLE then operator(name, node)
        else
          raise Error, "unsupported Content MathML element #{name.inspect} " \
                       "(outside the strict semantic core)"
        end
      end

      def single(node)
        children = node.element_children
        raise Error, "math without exactly one child" if children.empty?

        # Non-strict container form: the operator element and its
        # arguments sit side by side under the wrapper and form one
        # application (the standard's transform of <plus/>x y</math>).
        if children.size > 1
          first = children.first.name
          if ContentMathMLOperators::TABLE.key?(first)
            application = model(:Oma)
            slot(application, operator(first, children.first))
            children.drop(1).each { |child| slot(application, element(child)) }
            return application
          elsif children.size > 1 && %w[apply csymbol].include?(first)
            application = element(children.first)
            raise Error, "math with #{children.size} children" unless application.is_a?(hierarchy.const_get(:Oma))

            children.drop(1).each { |child| slot(application, element(child)) }
            return application
          end

          raise Error, "math with #{children.size} children"
        end

        element(children.first)
      end

      def csymbol(node)
        cd = node["cd"]
        name = node["name"]
        unless cd && name
          raise Error, "csymbol without cd and name attributes"
        end

        model(:Oms).tap do |symbol|
          symbol.cd = cd
          symbol.name = name
          symbol.cdbase = node["cdbase"] if node["cdbase"]
        end
      end

      def apply(node)
        children = node.element_children
        if children.empty?
          raise Error, "apply without children"
        end

        model(:Oma).tap do |application|
          # Non-strict form: the operator element leads the apply and its
          # arguments follow as siblings.
          head = children.first
          if ContentMathMLOperators::TABLE.key?(head.name)
            slot(application, operator(head.name, head))
            children.drop(1).each { |child| slot(application, element(child)) }
          else
            children.each { |child| slot(application, element(child)) }
          end
        end
      end

      # MathML 4 deprecates the non-strict bind form: lambda carries no
      # head symbol, so the binding maps to OMBIND over fns1/lambda —
      # the same construction the evaluator's lambda layer binds.
      def lambda_node(node)
        bvar = node.element_children.select { |child| child.name == "bvar" }
        rest = node.element_children.reject { |child| child.name == "bvar" }
        raise Error, "lambda without a bvar" if bvar.empty?
        raise Error, "lambda without a body" if rest.empty?
        raise Error, "lambda with more than one body" if rest.size > 1

        binder = model(:Ombind)
        slot(binder, lambda_symbol)
        vars_container = model(:Ombvar)
        bvar.each do |child|
          variable = child.element_children.first
          raise Error, "bvar without a variable" unless variable

          slot(vars_container, element(variable))
        end
        slot(binder, vars_container)
        slot(binder, element(rest.first))
        binder
      end

      def lambda_symbol
        model(:Oms).tap do |symbol|
          symbol.cd = "fns1"
          symbol.name = "lambda"
        end
      end

      def variable(node)
        text = node.text.strip
        raise Error, "ci without a name" if text.empty?

        model(:Omv).tap { |variable| variable.name = text }
      end

      def string(node)
        model(:Omstr).tap { |string| string.value = [node.text] }
      end

      # cn: integer (base 10, or base N through nums1/based_integer),
      # rational (type="rational" with a sep child), e-notation
      # (type="e-notation" with a sep child: mantissa × 10^exponent).
      def number(node)
        type = node["type"] || "integer"
        children = node.element_children
        case type
        when "integer" then integer(node, children)
        when "rational" then rational(node, children)
        when "e-notation" then e_notation(node, children)
        when "real", "double", "hexdouble"
          raise Error, "cn type #{type.inspect} has no exact OpenMath form " \
                       "(encode the value with an OMF in the XML encoding)"
        else
          raise Error, "unsupported cn type #{type.inspect}"
        end
      end

      def integer(node, children)
        unless children.empty?
          raise Error, "cn integer with child elements"
        end

        text = node.text.strip
        base = node["base"] ? Integer(node["base"], 10) : 10
        if base == 10
          model(:Omi).tap { |integer| integer.value = [text] }
        else
          model(:Oma).tap do |application|
            slot(application, symbol("nums1", "based_integer"))
            slot(application, integer_value(base.to_s))
            slot(application, string_value(text))
          end
        end
      end

      def rational(node, children)
        unless children.size == 1 && children.first.name == "sep"
          raise Error, 'cn type="rational" needs exactly one sep child'
        end

        numerator, denominator = node.children.select(&:text?).map { |part| part.text.strip }.reject(&:empty?)
        raise Error, "cn rational without two digits" unless numerator && denominator

        model(:Oma).tap do |application|
          slot(application, symbol("nums1", "rational"))
          slot(application, integer_value(numerator))
          slot(application, integer_value(denominator))
        end
      end

      def e_notation(node, children)
        unless children.size == 1 && children.first.name == "sep"
          raise Error, 'cn type="e-notation" needs exactly one sep child'
        end

        mantissa, exponent = node.children.select(&:text?).map { |part| part.text.strip }.reject(&:empty?)
        unless mantissa && exponent
          raise Error, "cn e-notation without mantissa and exponent"
        end

        model(:Oma).tap do |application|
          slot(application, symbol("arith1", "times"))
          slot(application, real_literal(mantissa))
          slot(application, power_of_ten(exponent))
        end
      end

      def real_literal(text)
        model(:Omf).tap { |float| float.dec = text }
      end

      def power_of_ten(exponent)
        model(:Oma).tap do |application|
          slot(application, symbol("arith1", "power"))
          slot(application, integer_value("10"))
          slot(application, integer_value(exponent))
        end
      end

      def integer_value(text)
        model(:Omi).tap { |integer| integer.value = [text] }
      end

      def string_value(text)
        model(:Omstr).tap { |string| string.value = [text] }
      end

      def symbol(cd, name)
        model(:Oms).tap do |oms|
          oms.cd = cd
          oms.name = name
        end
      end

      def operator(name, node)
        cd, symbol_name = ContentMathMLOperators::TABLE.fetch(name)
        children = node.element_children
        if children.empty?
          # A nullary operator stands alone (a constant symbol).
          symbol(cd, symbol_name)
        else
          model(:Oma).tap do |application|
            slot(application, symbol(cd, symbol_name))
            children.each { |child| slot(application, element(child)) }
          end
        end
      end

      def slot(container, child)
        name = child.class.mappings_for(:xml).element_name
        attribute = Evaluation::Evaluator::CHILD_ATTRIBUTES[name]
        if attribute.nil? || !container.respond_to?("#{attribute}=")
          raise Error, "child #{name} is not allowed in " \
                       "#{container.class.mappings_for(:xml).element_name}"
        end

        collection = container.public_send(attribute) || []
        container.public_send(:"#{attribute}=", collection + [child])
        order = container.element_order ||= []
        order << Lutaml::Xml::Element.new("Element", name, node_type: :element)
      end

      def model(name)
        hierarchy.register_models!
        hierarchy.const_get(name).new
      end
    end

    # The writer: the strict form only — csymbol, apply, ci, cn, cs,
    # lambda/bvar. Constructs with no Content MathML form refuse typed.
    class Writer
      def initialize(root)
        @root = root
      end

      def document
        wrapper = Moxml.new.create_document
        math = wrapper.create_element("math")
        math["xmlns"] = NAMESPACE
        math.add_child(element(@root))
        wrapper.root = math
        wrapper.to_xml(indent: 2, declaration: false, expand_empty: false)
      end

      def element(node)
        name = node.class.mappings_for(:xml).element_name
        case name
        when "OMOBJ" then content_of(node)
        when "OMS" then csymbol(node)
        when "OMA" then apply(node)
        when "OMV" then variable(node)
        when "OMI" then integer(node)
        when "OMF" then float(node)
        when "OMSTR" then string(node)
        when "OMBIND" then binding(node)
        else
          raise Error, "#{name} has no Content MathML form (the semantic " \
                       "core encodes OMS, OMA, OMV, OMI, OMF, OMSTR and " \
                       "OMBIND; encode others in the XML encoding)"
        end
      end

      # An OMOBJ's single child is what gets encoded (the frame is the
      # math wrapper, as the binary framing is).
      def content_of(node)
        child = Evaluation::Evaluator.ordered_children(node).first
        raise Error, "empty OMOBJ" unless child

        element(child)
      end

      def csymbol(node)
        attributes = { "cd" => node.cd.to_s, "name" => node.name.to_s }
        attributes["cdbase"] = node.cdbase if node.cdbase
        ContentMathML.content_element("csymbol", nil, attributes)
      end

      def apply(node)
        children = Evaluation::Evaluator.ordered_children(node)
        raise Error, "application without children" if children.empty?

        ContentMathML.content_element("apply", children.map { |child| element(child) })
      end

      def variable(node)
        element_node = ContentMathML.content_element("ci", nil, nil)
        element_node.content = node.name.to_s
        element_node
      end

      def integer(node)
        text = node.value.join.gsub(/\s+/, "")
        element_node = ContentMathML.content_element("cn", nil, nil)
        element_node.content = text
        element_node
      end

      def float(node)
        element_node = ContentMathML.content_element("cn", nil,
                                                     { "type" => "e-notation" })
        raise Error, "hex OMF has no exact Content MathML form" if node.hex
        mantissa = ContentMathML.content_element("mn", nil, nil)
        mantissa.content = node.dec.to_s
        exponent = ContentMathML.content_element("mn", nil, nil)
        exponent.content = "0"
        element_node.add_child(mantissa)
        element_node.add_child(sep(element_node.document))
        element_node.add_child(exponent)
        element_node
      end

      def string(node)
        element_node = ContentMathML.content_element("cs", nil, nil)
        element_node.content = node.value.join
        element_node
      end

      def binding(node)
        head = node.oms_value&.first
        unless head && head.cd == "fns1" && head.name == "lambda"
          raise Error, "binding whose head is not fns1#lambda has no " \
                       "Content MathML form"
        end

        vars = node.ombvar_value&.first
        raise Error, "binding without OMBVAR" unless vars

        lambda_node = ContentMathML.content_element("lambda", nil, nil)
        Evaluation::Evaluator.ordered_children(vars).each do |var|
          lambda_node.add_child(ContentMathML.content_element("bvar", [element(var)]))
        end
        body = Evaluation::Evaluator.ordered_children(node).drop(2).first
        raise Error, "binding without a body" unless body

        lambda_node.add_child(element(body))
        lambda_node
      end

      def sep(document)
        document.create_element("sep")
      end
    end
  end
end
