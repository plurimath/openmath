# frozen_string_literal: true

module Openmath
  module Evaluation
    # The coverage-interval kinds (PM 1002 clause 6): shortest and
    # probabilistically-symmetric (spelled symmetric in AsciiMath).
    INTERVAL_KINDS = %w[shortest symmetric].freeze

    # A PM 1002 quantity: the reported value plus the uncertainty of its
    # category. The category is part of the value's identity — standard,
    # expanded and coverage-interval quantities with the same numbers are
    # different values. Exact operands keep the exact classes; the
    # constructor refusals follow PM 1002 clause 6 (coverage factors are
    # positive unsigned, probabilities lie strictly inside (0, 1) by
    # exact comparison, interval kinds are shortest or symmetric).
    UNCERTAIN_STANDARD = :standard
    UNCERTAIN_EXPANDED = :expanded
    UNCERTAIN_COVERAGE = :coverage

    Uncertain = Struct.new(:value, :category, :magnitude, :coverage_factor,
                           :coverage_probability, :lower, :upper,
                           :interval_kind, keyword_init: true) do
      def self.standard(value, magnitude)
        unless magnitude.is_a?(Numeric) && magnitude >= 0
          raise OperandTypeError.new("standard uncertainty magnitude", magnitude)
        end

        new(value: value, category: UNCERTAIN_STANDARD, magnitude: magnitude)
      end

      def self.expanded(value, magnitude, coverage_factor, coverage_probability = nil)
        unless coverage_factor.is_a?(Numeric) && coverage_factor.positive?
          raise OperandTypeError.new("coverage factor", coverage_factor)
        end
        require_probability(coverage_probability) if coverage_probability

        new(value: value, category: UNCERTAIN_EXPANDED, magnitude: magnitude,
            coverage_factor: coverage_factor,
            coverage_probability: coverage_probability)
      end

      def self.coverage(value, lower, upper, coverage_probability = nil,
                        interval_kind = "symmetric")
        if lower.is_a?(Numeric) && upper.is_a?(Numeric) && lower > upper
          raise OperandTypeError.new("coverage interval", [lower, upper])
        end
        require_probability(coverage_probability) if coverage_probability
        unless INTERVAL_KINDS.include?(interval_kind)
          raise OperandTypeError.new("interval kind", interval_kind)
        end

        new(value: value, category: UNCERTAIN_COVERAGE, lower: lower,
            upper: upper, coverage_probability: coverage_probability,
            interval_kind: interval_kind)
      end

      def self.require_probability(probability)
        return if probability.is_a?(Numeric) && probability > 0 && probability < 1

        raise OperandTypeError.new("coverage probability", probability)
      end
    end
  end
end
