# frozen_string_literal: true

require "base64"

module Openmath
  module Evaluation
    # The tree walk: literals evaluate to themselves, applications resolve
    # their operator symbol through the binding table and dispatch to the
    # named operation, error constructors evaluate to error values, and
    # everything outside the evaluated surface refuses with a typed error.
    module Evaluator
      module_function

      # Evaluates an OpenMath object under the variable bindings. Variables
      # bind by name (PM 1004's binding domain: numbers, booleans, strings).
      def evaluate(object, variables: {}, table: BindingTable.default)
        case object
        when Openmath::V2::Omobj, Openmath::V3::Omobj
          single(object, variables, table)
        when Openmath::V2::Omi, Openmath::V3::Omi
          integer_literal(object)
        when Openmath::V2::Omf, Openmath::V3::Omf
          float_literal(object)
        when Openmath::V2::Omstr, Openmath::V3::Omstr
          object.value.join
        when Openmath::V2::Omb, Openmath::V3::Omb
          require_base64(object)
        when Openmath::V2::Omv, Openmath::V3::Omv
          lookup_variable(object, variables)
        when Openmath::V2::Oma, Openmath::V3::Oma
          apply(object, variables, table)
        when Openmath::V2::Ombind, Openmath::V3::Ombind
          bind(object, variables, table)
        when Openmath::V2::Omattr, Openmath::V3::Omattr
          evaluate(attributed_object(object), variables: variables, table: table)
        when Openmath::V2::Ome, Openmath::V3::Ome
          error_value(object, variables, table)
        else
raise UnsupportedExpressionError, element_name(object)
        end
      end

      # The children of a container in document order: element_order names
      # each element as parsed; the per-type collections hold the values in
      # the same relative order, so a cursor per element name reconstructs
      # the sequence.
      CHILD_ATTRIBUTES = {
        "OMS" => :oms_value, "OMV" => :omv_value, "OMI" => :omi_value,
        "OMB" => :omb_value, "OMSTR" => :omstr_value, "OMF" => :omf_value,
        "OMA" => :oma_value, "OMBIND" => :ombind_value,
        "OMBVAR" => :ombvar_value, "OME" => :ome_value,
        "OMATTR" => :omattr_value, "OMATP" => :omatp_value,
        "OMFOREIGN" => :omforeign_value, "OMR" => :omr_value,
      }.freeze

      def ordered_children(container)
        cursors = Hash.new(0)
        ordered = container.element_order.filter_map do |element|
          attribute = CHILD_ATTRIBUTES[element.name]
          next unless attribute

          values = container.public_send(attribute)
          index = cursors[element.name]
          cursors[element.name] += 1
          values[index]
        end
        # Mixed-content elements can drop out of the order tracking; append
        # any values the order walk did not consume, in collection order.
        CHILD_ATTRIBUTES.each do |name, attribute|
          values = container.public_send(attribute)
          consumed = cursors[name]
          ordered.concat(values.drop(consumed)) if values && values.size > consumed
        end
        ordered
      end

def element_name(object)
  object.is_a?(Openmath::V2::Ombind) || object.is_a?(Openmath::V3::Ombind) ? "OMBIND" : object.class.name
end

def single(omobj, variables, table)
        elements = ordered_children(omobj)
        raise UnsupportedExpressionError, "empty OMOBJ" if elements.empty?
        raise UnsupportedExpressionError, "OMOBJ with multiple children" if elements.size > 1

        evaluate(elements.first, variables: variables, table: table)
      end

      def integer_literal(node)
        text = node.value.join.strip
        Integer(text.delete(" "))
      end

      def float_literal(node)
        return Float(node.dec) if node.dec
return [node.hex].pack("H*").unpack1("G") if node.hex

        raise OperandTypeError.new("OMF", "neither dec nor hex")
      end

      def require_base64(node)
        Base64.decode64(node.value.join)
      rescue ArgumentError
        raise OperandTypeError.new("base64 content", node.value.join)
      end

      def lookup_variable(node, variables)
        name = node.name
        return variables[name] if variables.key?(name)
        return variables[name.to_sym] if variables.key?(name.to_sym)

        raise UnboundSymbolError.new("(variable)", name)
      end

      def apply(oma, variables, table)
        children = ordered_children(oma)
        operator = children.first
        if operator.is_a?(Openmath::V2::Oms) || operator.is_a?(Openmath::V3::Oms)
          apply_symbol(operator, children[1..], variables, table)
        else
          closure = evaluate(operator, variables: variables, table: table)
          unless closure.is_a?(Closure)
            raise UnsupportedExpressionError,
                  "application of a #{closure.class} value"
          end

          apply_closure(closure, children[1..], variables, table)
        end
      end

      def apply_symbol(operator, argument_nodes, variables, table)
        binding = table.lookup(operator.cd, operator.name)
        raise UnboundSymbolError.new(operator.cd, operator.name) unless binding

        implementation, arity_spec = Operations.implementation(binding.operation)
        arguments = argument_nodes.map { |child| evaluate(child, variables: variables, table: table) }
        unless arity_spec.cover?(arguments.size)
          raise ArityError.new(binding.operation, arity_spec, arguments.size)
        end

        implementation.call(arguments)
      end

      def apply_closure(closure, argument_nodes, variables, table)
        arguments = argument_nodes.map { |child| evaluate(child, variables: variables, table: table) }
        unless closure.names.size == arguments.size
          raise ArityError.new("lambda", closure.names.size..closure.names.size,
                               arguments.size)
        end

        environment = closure.environment.merge(closure.names.zip(arguments).to_h)
        evaluate(closure.body, variables: environment, table: closure.table)
      end

      # fns1/lambda is the only binder in the evaluated surface; every
      # other head refuses through the unbound-symbol discipline.
      def bind(ombind, variables, table)
        head = ombind.oms_value.first
        unless head && head.cd == "fns1" && head.name == "lambda"
          raise UnboundSymbolError.new(head&.cd || "(binder)", head&.name || "(missing)")
        end

        ombvar = ombind.ombvar_value.first
        raise UnsupportedExpressionError, "lambda without OMBVAR" unless ombvar

        names = bound_variable_names(ombvar)
        body = ordered_children(ombind).drop(2)
        unless body.size == 1
          raise UnsupportedExpressionError,
                "lambda with #{body.size} bodies"
        end

        Closure.new(names: names, body: body.first,
                    environment: variables.dup, table: table)
      end

      # omvar = OMV | OMATTR(OMATP, OMV); attributed variables bind by
      # their wrapped name, attributes carried on the pair node itself.
      def bound_variable_names(ombvar)
        ordered_children(ombvar).map { |child| variable_name(child) }
      end

      def variable_name(node)
        variable = node
        if node.is_a?(Openmath::V2::Omattr) || node.is_a?(Openmath::V3::Omattr)
          variable = attributed_object(node)
        end
        unless variable.is_a?(Openmath::V2::Omv) || variable.is_a?(Openmath::V3::Omv)
          raise UnsupportedExpressionError, "binding variable #{variable.class}"
        end

        variable.name
      end

      # OMATTR evaluates its attributed object; the attribution pairs ride
      # along as data and never alter the evaluation.
      def attributed_object(omattr)
        attributed = ordered_children(omattr).last
        if attributed.nil? || attributed.is_a?(Openmath::V2::Omatp) ||
            attributed.is_a?(Openmath::V3::Omatp)
          raise UnsupportedExpressionError, "attribution without an object"
        end

        attributed
      end

      def error_value(ome, variables, table)
        symbol = ome.oms_value.first
        raise UnsupportedExpressionError, "error without a leading OMS" unless symbol

        content = ordered_children(ome).drop(1).map do |child|
          evaluate(child, variables: variables, table: table)
        end
        ErrorValue.new(symbol.cd, symbol.name, content)
      end
    end
  end
end
