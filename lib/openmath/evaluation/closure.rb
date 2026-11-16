# frozen_string_literal: true

module Openmath
  module Evaluation
    # The value of fns1/lambda: the bound variable names, the body, the
    # lexical environment captured at construction, and the table the
    # body evaluates under. Application merges the arguments over the
    # captured environment — lexically, never at the call site.
    Closure = Struct.new(:names, :body, :environment, :table, keyword_init: true)
  end
end
