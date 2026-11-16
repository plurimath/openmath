# frozen_string_literal: true

require "base64"

module Openmath
  module Evaluation
    # The tree walk: literals evaluate to themselves, applications resolve
    # their operator symbol through the binding table and dispatch to the
    # named operation, error constructors evaluate to error values, OMR
    # references resolve within their document scope, and everything
    # outside the evaluated surface refuses with a typed error.
    module Evaluator
      module_function

      # The per-walk state: the variable environment and binding table in
      # effect, the optional STS signatures the walk checks against, the
      # id index of the document scope, and the reference bookkeeping
      # (memoized results, in-progress targets).
      Context = Struct.new(:variables, :table, :signatures, :index, :memo,
                           :in_progress, keyword_init: true) do
        def self.build(variables, table, root, signatures: nil)
          new(variables: variables, table: table, signatures: signatures,
              index: scope_index(root), memo: {}, in_progress: [])
        end

        def with(variables:, table:)
          Context.new(variables: variables, table: table,
                      signatures: signatures, index: index, memo: memo,
                      in_progress: in_progress)
        end

        def self.scope_index(root)
          ids = {}
          visit = ->(node) do
            id = node.respond_to?(:id) ? node.id : nil
            ids[id] = node if id
            children_of(node).each { |child| visit.call(child) }
          end
          visit.call(root)
          ids
        end

        def self.children_of(node)
          return [] unless node.respond_to?(:element_order)

          Evaluator.ordered_children(node)
        end
      end

      # Evaluates an OpenMath object under the variable bindings. Variables
      # bind by name (PM 1004's binding domain: numbers, booleans, strings).
      # When STS signatures are supplied, applications check against their
      # operator's signature and violations refuse typed.
      def evaluate(object, variables: {}, table: BindingTable.default, signatures: nil)
        walk(object, Context.build(variables, table, object, signatures: signatures))
      end

      def walk(object, context)
        case object
        when Openmath::V2::Omobj, Openmath::V3::Omobj
          single(object, context)
        when Openmath::V2::Omi, Openmath::V3::Omi
          integer_literal(object)
        when Openmath::V2::Omf, Openmath::V3::Omf
          float_literal(object)
        when Openmath::V2::Omstr, Openmath::V3::Omstr
          object.value.join
        when Openmath::V2::Omb, Openmath::V3::Omb
          require_base64(object)
        when Openmath::V2::Omv, Openmath::V3::Omv
          lookup_variable(object, context.variables)
        when Openmath::V2::Oma, Openmath::V3::Oma
          apply(object, context)
        when Openmath::V2::Ombind, Openmath::V3::Ombind
          bind(object, context)
        when Openmath::V2::Omattr, Openmath::V3::Omattr
          walk(attributed_object(object), context)
        when Openmath::V2::Ome, Openmath::V3::Ome
          error_value(object, context)
        when Openmath::V2::Omr, Openmath::V3::Omr
          resolve_reference(object, context)
        else
          raise UnsupportedExpressionError, element_name(object)
        end
      end

      # The children of a container in document order: element_order names
      # each element as parsed; the per-type collections hold the values in
      # the same relative order, so a cursor per element name reconstructs
      # the sequence. (lutaml-model's order tracking covers every content
      # model as of 0.8.175 — see openmath#16.)
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
        container.element_order.filter_map do |element|
          attribute = CHILD_ATTRIBUTES[element.name]
          next unless attribute

          values = container.public_send(attribute)
          index = cursors[element.name]
          cursors[element.name] += 1
          values[index]
        end
      end

      def element_name(object)
        object.is_a?(Openmath::V2::Ombind) || object.is_a?(Openmath::V3::Ombind) ? "OMBIND" : object.class.name
      end

      def single(omobj, context)
        elements = ordered_children(omobj)
        raise UnsupportedExpressionError, "empty OMOBJ" if elements.empty?
        raise UnsupportedExpressionError, "OMOBJ with multiple children" if elements.size > 1

        walk(elements.first, context)
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

      def apply(oma, context)
        children = ordered_children(oma)
        operator = children.first
        if operator.is_a?(Openmath::V2::Oms) || operator.is_a?(Openmath::V3::Oms)
          apply_symbol(operator, children[1..], context)
        else
          closure = walk(operator, context)
          unless closure.is_a?(Closure)
            raise UnsupportedExpressionError,
                  "application of a #{closure.class} value"
          end

          apply_closure(closure, children[1..], context)
        end
      end

      def apply_symbol(operator, argument_nodes, context)
        binding = context.table.lookup(operator.cd, operator.name)
        raise UnboundSymbolError.new(operator.cd, operator.name) unless binding

        arguments = argument_nodes.map { |child| walk(child, context) }
        check_signature(operator, arguments, context)
        implementation, arity_spec = Operations.implementation(binding.operation)
        unless arity_spec.cover?(arguments.size)
          raise ArityError.new(binding.operation, arity_spec, arguments.size)
        end

        implementation.call(arguments)
      end

      # Advisory by default: without supplied signatures nothing checks;
      # with them, a signed operator's application refuses typed on any
      # profile violation.
      def check_signature(operator, arguments, context)
        return unless context.signatures

        signature = context.signatures.lookup(operator.cd, operator.name)
        return unless signature

        violations = SignatureChecker.violations(operator.cd, operator.name,
                                                 signature, arguments)
        violations.each { |detail| raise SignatureViolationError, detail }
      end

      def apply_closure(closure, argument_nodes, context)
        arguments = argument_nodes.map { |child| walk(child, context) }
        unless closure.names.size == arguments.size
          raise ArityError.new("lambda", closure.names.size..closure.names.size,
                               arguments.size)
        end

        environment = closure.environment.merge(closure.names.zip(arguments).to_h)
        walk(closure.body, context.with(variables: environment, table: closure.table))
      end

      # fns1/lambda is the only binder in the evaluated surface; every
      # other head refuses through the unbound-symbol discipline.
      def bind(ombind, context)
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
                    environment: context.variables.dup, table: context.table)
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

      # OMR stands for the object it references (the id within this
      # document's scope). A shared subtree evaluates once per walk (the
      # memo is keyed by the environment in effect); a reference to a
      # target currently under evaluation is a cycle and refuses typed.
      def resolve_reference(omr, context)
        href = omr.href.to_s
        name = href.sub(/\A#/, "")
        unless href.start_with?("#") && !name.empty?
          raise UnsupportedExpressionError, "OMR href #{href.inspect} is not a fragment reference"
        end

        target = context.index[name]
        raise UnboundSymbolError.new("(reference)", name) unless target
        raise RecursionError.new(name) if context.in_progress.include?(name)

        memo_key = [name, context.variables.object_id]
        return context.memo[memo_key] if context.memo.key?(memo_key)

        context.in_progress << name
        begin
          context.memo[memo_key] = walk(target, context)
        ensure
          context.in_progress.delete(name)
        end
      end

      def error_value(ome, context)
        symbol = ome.oms_value.first
        raise UnsupportedExpressionError, "error without a leading OMS" unless symbol

        content = ordered_children(ome).drop(1).map do |child|
          walk(child, context)
        end
        ErrorValue.new(symbol.cd, symbol.name, content)
      end
    end
  end
end
