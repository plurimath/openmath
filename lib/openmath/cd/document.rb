# frozen_string_literal: true

module Openmath
  module CD
    # The Content Dictionary document: <CD> with its header (CDName,
    # CDBase, CDURL, CDReviewDate, CDStatus, CDDate, CDVersion, CDRevision,
    # CDComments, Description) and its symbol definitions.
    class Document < Openmath::CommonElements
      def self.lutaml_default_register
        Configuration::CONTEXT_ID
      end

      attribute :cd_name, :string
      attribute :cd_base, :string
      attribute :cd_url, :string
      attribute :cd_review_date, :string
      attribute :cd_status, :string
      attribute :cd_date, :string
      attribute :cd_version, :string
      attribute :cd_revision, :string
      attribute :description, :string, collection: true
      attribute :definition_value, Definition, collection: true

      xml do
        namespace Openmath::CD::Namespace
        element "CD"
        map_element "CDName", to: :cd_name
        map_element "CDBase", to: :cd_base
        map_element "CDURL", to: :cd_url
        map_element "CDReviewDate", to: :cd_review_date
        map_element "CDStatus", to: :cd_status
        map_element "CDDate", to: :cd_date
        map_element "CDVersion", to: :cd_version
        map_element "CDRevision", to: :cd_revision
        map_element "Description", to: :description
        map_element "CDDefinition", to: :definition_value
      end

      # The symbol names, in document order.
      def symbol_names
        definition_value.map(&:name)
      end

      # The definition of one symbol, or nil.
      def definition_for(name)
        definition_value.find { |d| d.name == name }
      end
    end
  end
end
