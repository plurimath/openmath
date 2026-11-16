# frozen_string_literal: true

require "openmath"
require "nokogiri"
require "digest"
require "json"
require_relative "group/errors"
require_relative "group/models"
require_relative "group/artifacts"
require_relative "group/pinned_collection"

module Openmath
  module CD
    # CDGroups and immutable local dictionary collections. Requiring this file
    # is sufficient on the admission base; extension discovery installs it later.
    module Group
      ROOT = File.expand_path("../../..", __dir__)
      DEFAULT_BASE = "http://www.openmath.org/cd"

      module_function

      def parse(xml)
        document = Artifacts.xml(xml, "CDGroup")
        if document.root&.[]("version") == "2.0"
          # Upstream's groups carry this legacy attribute; upstream's RNG does
          # not. Validate a copy without it, preserving the authoritative bytes.
          document.root.remove_attribute("version")
        end
        schema_path = "schemas/cdgroup/omcdgroup2.rng"
        schema = Nokogiri::XML::RelaxNG(Artifacts.new.read(schema_path))
        errors = schema.validate(document)
        unless errors.empty?
          raise InvalidGroup, "refused CDGroup: #{errors.map(&:message).join('; ')}"
        end

        Document.from_xml(document.to_xml)
      end

      def official
        PinnedCollection.new
      end

      # F-ext installer hook; it adds APIs without changing cd.rb or Collection.
      def install!
        Openmath.define_singleton_method(:parse_cd_group) { |xml| Group.parse(xml) }
        Openmath.define_singleton_method(:official_cd_collection) { Group.official }
      end
    end
  end
end
