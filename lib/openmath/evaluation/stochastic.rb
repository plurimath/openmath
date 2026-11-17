# frozen_string_literal: true

module Openmath
  module Evaluation
    # Deterministic Monte-Carlo evaluation over uncertainty-carrying
    # objects (PM 1002 quantities, JCGM 101's propagation): each Uncertain
    # value in the walk draws from its category's documented distribution
    # under a seeded generator, and the final state — the generator name,
    # the seed, the sample count, the samples, and the sample mean and
    # standard deviation — rides the result, so a corpus row reproduces
    # the run byte for byte. Same seed, same samples, always.
    module Stochastic
      GENERATORS = %w[mt19937].freeze

      Result = Struct.new(:value, :samples, :mean, :standard_deviation,
                          :generator, :seed, :count, keyword_init: true)

      module_function

      # Evaluates the object with every Uncertain value sampled +count+
      # times under the seeded generator. The nominal walk runs once
      # (no sampling) for the carried value.
      def evaluate(object, samples:, seed:, generator: "mt19937",
                   variables: {}, table: BindingTable.default)
        unless GENERATORS.include?(generator)
          raise UnsupportedExpressionError, "unknown generator #{generator.inspect}"
        end

        object = Openmath.parse(object, version: 2) if object.is_a?(String)
        nominal = Evaluator.evaluate(object, variables: variables, table: table)
        random = Random.new(seed)
        draws = Array.new(samples) { walk_sampled(object, variables, table, random).first }
        Result.new(
          value: nominal, samples: draws,
          mean: draws.reduce(0.0, :+) / draws.size,
          standard_deviation: standard_deviation(draws),
          generator: generator, seed: seed, count: samples,
        )
      end

      # A sampled walk: the sampler rides the walk context, so every
      # application producing an Uncertain value draws once, in walk
      # order — two uncertain leaves in one object draw independently.
      # Returns [sampled value, leaf draws].
      def walk_sampled(object, variables, table, random)
        draws = []
        context = Evaluator::Context.new(
          variables: variables, table: table,
          index: Evaluator::Context.scope_index(object),
          memo: {}, in_progress: [],
          sampler: lambda do |uncertain|
            sampled = draw(uncertain, random)
            draws << sampled
            sampled
          end,
        )
        [Evaluator.walk(object, context), draws]
      end

      # The documented per-category distributions (JCGM 101's propagation
      # models): standard — Normal(value, magnitude); expanded —
      # Normal(value, magnitude / coverage_factor); coverage —
      # Uniform(lower, upper) for the symmetric kind, Triangular(value,
      # lower, upper) for the shortest kind.
      def draw(uncertain, random)
        case uncertain.category
        when UNCERTAIN_STANDARD, UNCERTAIN_EXPANDED
          sigma = if uncertain.category == UNCERTAIN_STANDARD
                    uncertain.magnitude
                  else
                    uncertain.magnitude / uncertain.coverage_factor
                  end
          normal(uncertain.value, sigma, random)
        else
          case uncertain.interval_kind
          when "symmetric"
            uniform(uncertain.lower, uncertain.upper, random)
          else
            triangular(uncertain.value, uncertain.lower, uncertain.upper, random)
          end
        end
      end

      def uniform(low, high, random)
        low + random.rand * (high - low)
      end

      def triangular(peak, low, high, random)
        first = random.rand
        second = random.rand
        midpoint = (peak - low) / (high - low).to_f
        first < midpoint ? low + Math.sqrt(first * midpoint) * (high - low) : high - Math.sqrt((1 - first) * (1 - midpoint)) * (high - low)
      end

      # Box-Muller over two uniforms; the magnitude scales by the
      # nominal's exactness (exact nominals sample into floats — the
      # sampled value is a realization, not the report).
      def normal(mean, sigma, random)
        u1 = random.rand
        u2 = random.rand
        return mean if u1.zero?

        mean + sigma * Math.sqrt(-2 * Math.log(u1)) * Math.cos(2 * Math::PI * u2)
      end

      def standard_deviation(draws)
        mean = draws.reduce(0.0, :+) / draws.size
        variance = draws.sum { |draw| (draw - mean)**2 } / [draws.size - 1, 1].max
        Math.sqrt(variance)
      end
    end
  end
end
