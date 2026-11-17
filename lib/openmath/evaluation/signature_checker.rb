# frozen_string_literal: true

module Openmath
  module Evaluation
    # The STS application checker: an application whose operator carries
    # an sts/mapsto signature checks its evaluated arguments against the
    # declared domains, and violations refuse typed naming the signature.
    #
    # The v1 profile applies only where the type language is decidable
    # over the evaluated values: mapsto arity (a sts/CartProd domain is
    # one argument position; a trailing sts/nary makes it variadic),
    # setname domains (N, Z, Q, R, P), the algebra carriers (sts/nassoc,
    # sts/assoc) whose carriers are numerical in practice, and
    # sts/Object accepting anything. Constructs outside the profile —
    # free type variables, unknown constructs — are advisory and never
    # refuse.
    module SignatureChecker
      SETNAME_PREDICATES = {
        "N" => ->(value) { value.is_a?(Integer) },
        "Z" => ->(value) { value.is_a?(Integer) },
        "Q" => ->(value) { value.is_a?(Rational) || value.is_a?(Integer) },
        "R" => ->(value) { value.is_a?(Numeric) },
        "P" => ->(value) { value.is_a?(Numeric) && value.positive? },
      }.freeze

      NUMERIC_CONSTRUCTS = %w[nassoc assoc].freeze

      # The algebra structures the sts CD defines as carrier classes; a
      # bare OMV domain naming one of these is numerical in practice.
      CARRIER_NAMES = %w[
        SemiGroup AbelianSemiGroup Monoid AbelianMonoid
        Group AbelianGroup Ring CommutativeRing Field
        OrderedSet OrderedMonoid OrderedGroup OrderedAbelianGroup
        OrderedRing OrderedField
      ].freeze

      module_function

      # Returns the list of violations; empty when the application checks.
      def violations(cd, name, signature_object, arguments)
        domains = mapsto_domains(signature_object)
        return [] unless domains

        expanded = expand_domains(domains)
        return [arity_violation(cd, name, expanded, arguments)] if arity_mismatch?(expanded, arguments)

        arguments.each_with_index.filter_map do |argument, index|
          domain = expanded[index]
          next if domain.nil? || acceptable?(domain, argument)

          domain_violation(cd, name, domain, index, argument)
        end
      end

      def arity_mismatch?(domains, arguments)
        return false if domains.include?(:variadic)

        arguments.size != domains.size
      end

      def arity_violation(cd, name, domains, arguments)
        "signature violation for #{cd}##{name}: the signature declares " \
          "#{domains.size} argument(s), the application has #{arguments.size}"
      end

      def domain_violation(cd, name, domain, index, argument)
        "signature violation for #{cd}##{name}: argument #{index + 1} " \
          "(#{argument.inspect}) is not in the domain #{describe(domain)}"
      end

      def acceptable?(domain, argument)
        case domain
        when V2::Oms, V3::Oms
          if domain.cd.start_with?("setname")
            predicate = SETNAME_PREDICATES[domain.name]
            predicate ? predicate.call(argument) : true
          else
            true
          end
        when V2::Oma, V3::Oma
          algebra_carrier?(domain) ? argument.is_a?(Numeric) : true
        when V2::Omv, V3::Omv
          CARRIER_NAMES.include?(domain.name) ? argument.is_a?(Numeric) : true
        else
          true
        end
      end

      def algebra_carrier?(domain)
        head = children(domain).first
        (head.is_a?(V2::Oms) || head.is_a?(V3::Oms)) &&
          head.cd == "sts" && NUMERIC_CONSTRUCTS.include?(head.name)
      end

      def mapsto_domains(signature_object)
        # The stored type is the OMOBJ wrapper around the mapsto application.
        content = children(signature_object).first
        if content.is_a?(V2::Omobj) || content.is_a?(V3::Omobj)
          content = children(content).first
        end
        parts = children(content)
        head = parts.first
        return nil unless head.is_a?(V2::Oms) || head.is_a?(V3::Oms)
        return nil unless head.cd == "sts" && head.name == "mapsto"

        parts[1..]
      end

      # A sts/CartProd domain is one argument position carrying its
      # subdomains; a sts/nary domain makes the arity variadic. A bare
      # OMV domain's FIRST occurrence is an STS type parameter (lt's
      # leading OrderedSets): it introduces the carrier and occupies no
      # value slot; later occurrences are value positions of that type.
      def expand_domains(domains)
        introduced = []
        domains.filter_map do |domain|
          if oms_head?(domain, "CartProd")
            cartprod_domain(domain)
          elsif oms_head?(domain, "nary")
            :variadic
          elsif domain.is_a?(V2::Omv) || domain.is_a?(V3::Omv)
            if introduced.include?(domain.name)
              domain
            else
              introduced << domain.name
              nil
            end
          else
            introduced << carrier_name(domain) if carrier_name(domain)
            domain
          end
        end
      end

      # The carrier class an algebra constructor introduces (nassoc(X) → X).
      def carrier_name(domain)
        return nil unless algebra_carrier?(domain)

        carrier = children(domain)[1]
        return nil unless carrier.is_a?(V2::Omv) || carrier.is_a?(V3::Omv)

        carrier.name
      end

      def cartprod_domain(domain)
        children(domain)[1]
      end

      def oms_head?(domain, name)
        head = children(domain).first
        (head.is_a?(V2::Oms) || head.is_a?(V3::Oms)) && head.cd == "sts" &&
          head.name == name
      end

      def describe(domain)
        case domain
        when V2::Oms, V3::Oms
          domain.cd == "sts" ? "sts##{domain.name}" : "#{domain.cd}##{domain.name}"
        when V2::Omv, V3::Omv
          "carrier #{domain.name}"
        when V2::Oma, V3::Oma
          "an STS construct"
        else
          domain.to_s
        end
      end

      def children(object)
        Evaluation::Evaluator.ordered_children(object)
      end
    end
  end
end
