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
        when Openmath::V2::Ome, Openmath::V3::Ome
          error_value(object, variables, table)
        else
          raise UnsupportedExpressionError, element_name(object)
        end
      end

      # Public compatibility entrypoint used by downstream converters (#587).
      CHILD_ATTRIBUTES = Children::ATTRIBUTES

      def ordered_children(container)
        Children.ordered(container)
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
        unless operator.is_a?(Openmath::V2::Oms) || operator.is_a?(Openmath::V3::Oms)
          raise UnsupportedExpressionError, "application without an OMS operator"
        end

        binding = table.lookup(operator.cd, operator.name)
        raise UnboundSymbolError.new(operator.cd, operator.name) unless binding

        implementation, arity_spec = Operations.implementation(binding.operation)
        arguments = children[1..].map { |child| evaluate(child, variables: variables, table: table) }
        unless arity_spec.cover?(arguments.size)
          raise ArityError.new(binding.operation, arity_spec, arguments.size)
        end

        implementation.call(arguments)
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
