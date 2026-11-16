# frozen_string_literal: true

module Openmath
  module CD
    module Group
      class Error < StandardError; end
      class InvalidGroup < Error; end
      class InvalidDictionary < Error; end
      class IntegrityError < Error; end
      class UnsafePath < Error; end
      class MissingMember < Error; end
      class IdentityMismatch < Error; end
      class AmbiguousRevision < Error; end
      class DuplicateRevision < Error; end
      class UnsupportedInclude < Error; end
    end
  end
end
