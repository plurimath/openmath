# frozen_string_literal: true

module Openmath
  module Evaluation
    # PM 1012's constraint evaluation: one limit against one result under
    # one decision rule, yielding one ConstraintResult. The verdict kinds
    # are PM 1012's Verdict enum; the signed residual is result - L in the
    # limit's own number (negative under an upper limit, positive over a
    # lower one); the comparison is exact for exact operands and as
    # computed for limited (float) ones.
    module Constraint
      SATISFIED = "satisfied"
      NOT_SATISFIED = "not-satisfied"
      CONDITIONAL = "conditional"
      VERDICTS = [SATISFIED, NOT_SATISFIED, CONDITIONAL].freeze

      UPPER = "upper"
      LOWER = "lower"

      SIMPLE_ACCEPTANCE = "simple-acceptance"
      GUARDED_ACCEPTANCE = "guarded-acceptance"

      # The stated boundary and its comparison direction: an upper limit
      # is satisfied at or below the boundary, a lower one at or above.
      Limit = Struct.new(:value, :direction, keyword_init: true)

      # The decision rule as data: simple acceptance carries no factor;
      # guarded acceptance carries the coverage factor k of its band.
      DecisionRule = Struct.new(:name, :coverage_factor, keyword_init: true)

      # PM 1012 clause 5's ConstraintResult. The verdict is nil only when
      # the applicability guard made the constraint inapplicable
      # (applicable false); the band and zone are set under guarded
      # acceptance.
      Result = Struct.new(:verdict, :residual, :rule, :diagnostics,
                          :limit, :band, :zone, :applicable,
                          keyword_init: true)

      module_function

      def upper_limit(args)
        limit(args, UPPER)
      end

      def lower_limit(args)
        limit(args, LOWER)
      end

      def limit(args, direction)
        boundary = args.fetch(0)
        raise OperandTypeError.new("limit", boundary) unless boundary.is_a?(Numeric)

        Limit.new(value: boundary, direction: direction)
      end

      def simple_acceptance(_args)
        DecisionRule.new(name: SIMPLE_ACCEPTANCE)
      end

      # The guard band is k * u: a positive coverage factor times the
      # result's standard uncertainty (PM 1012 clause 6).
      def guarded_acceptance(args)
        factor = args.fetch(0)
        raise OperandTypeError.new("coverage factor", factor) unless factor.is_a?(Numeric) && factor.positive?

        DecisionRule.new(name: GUARDED_ACCEPTANCE, coverage_factor: factor)
      end

      # evaluate_constraint(limit, result, rule[, guard]). A guard
      # evaluating to false records the constraint as inapplicable; a
      # guard that is not a boolean refuses.
      def evaluate(args)
        limit, result, rule, guard = args
        check_operands(args)
        return inapplicable(limit, rule) if guard == false

        if rule.name == GUARDED_ACCEPTANCE
          guarded(limit, result, rule)
        else
          simple(limit, result, rule)
        end
      end

      def check_operands(args)
        limit, _result, rule, guard = args
        raise OperandTypeError.new("constraint limit", limit) unless limit.is_a?(Limit)
        raise OperandTypeError.new("decision rule", rule) unless rule.is_a?(DecisionRule)
        return if args.size < 4 || [true, false].include?(guard)

        raise OperandTypeError.new("applicability guard", guard)
      end

      def inapplicable(limit, rule)
        Result.new(verdict: nil, residual: nil, rule: rule, limit: limit,
                   applicable: false,
                   diagnostics: ["inapplicable: the applicability guard is false"])
      end

      # Simple acceptance: the boundary comparison decides; no band, no
      # conditional zone.
      def simple(limit, result, rule)
        value = reported_value(result)
        residual = value - limit.value
        verdict = within?(limit, residual) ? SATISFIED : NOT_SATISFIED
        Result.new(verdict: verdict, residual: residual, rule: rule,
                   limit: limit, applicable: true, diagnostics: [])
      end

      # Guarded acceptance: the zone [L - k*u, L] for an upper limit,
      # [L, L + k*u] for a lower one, closed at both ends, is the
      # conditional zone. The residual carries its expanded uncertainty
      # (k*u at factor k).
      def guarded(limit, result, rule)
        unless result.is_a?(Uncertain) && result.category == UNCERTAIN_STANDARD
          raise OperandTypeError.new("guarded acceptance result", result)
        end

        band = rule.coverage_factor * result.magnitude
        residual = result.value - limit.value
        zone = guard_zone(limit, band)
        Result.new(verdict: guarded_verdict(limit, residual, band),
                   residual: Uncertain.expanded(residual, band, rule.coverage_factor),
                   rule: rule, limit: limit, band: band, zone: zone,
                   applicable: true, diagnostics: [])
      end

      def guarded_verdict(limit, residual, band)
        return NOT_SATISFIED unless within?(limit, residual)

        distance = limit.direction == UPPER ? -residual : residual
        distance > band ? SATISFIED : CONDITIONAL
      end

      def guard_zone(limit, band)
        if limit.direction == UPPER
          [limit.value - band, limit.value]
        else
          [limit.value, limit.value + band]
        end
      end

      def within?(limit, residual)
        limit.direction == UPPER ? residual <= 0 : residual >= 0
      end

      def reported_value(result)
        value = result.is_a?(Uncertain) ? result.value : result
        raise OperandTypeError.new("constraint result", result) unless value.is_a?(Numeric)

        value
      end
    end
  end
end
