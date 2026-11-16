# frozen_string_literal: true

module Openmath
  module Evaluation
    # An interval1 value: the construction's exact bounds and open/closed
    # flags. Ruby's Range cannot represent an open lower bound, so the
    # interval constructions evaluate to this and membership asks it.
    Interval = Struct.new(:low, :high, :low_closed, :high_closed,
                          keyword_init: true) do
      def member?(value)
        above_low = low_closed ? value >= low : value > low
        below_high = high_closed ? value <= high : value < high
        above_low && below_high
      end
    end
  end
end
