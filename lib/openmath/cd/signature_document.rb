# frozen_string_literal: true

require "lutaml/model"

module Openmath
  module CD
    # One signature record: the symbol's name and its STS type as an
    # OpenMath object (the omcdsig2 grammar embeds a standard OMOBJ; the
    # object rides the versioned object model through the CD registry).
    class Signature < Lutaml::Model::Serializable
      def self.lutaml_default_register
        Configuration::CONTEXT_ID
      end

      attribute :name, :string
      attribute :object, :omobj

      xml do
        namespace CdsNamespace
        element "Signature"
        map_attribute "name", to: :name
        map_element "OMOBJ", to: :object
      end
    end

    # The CDSignatures document: which CD it signs (the cd attribute),
    # what kind of signatures it carries (the type attribute, e.g. "sts"),
    # and the Signature records.
    class SignatureDocument < Lutaml::Model::Serializable
      def self.lutaml_default_register
        Configuration::CONTEXT_ID
      end

      attribute :cd, :string
      attribute :signature_type, :string
      attribute :comment_value, :string, collection: true
      attribute :review_date, :string
      attribute :status, :string
      attribute :signature_value, Signature, collection: true

      xml do
        namespace CdsNamespace
        element "CDSignatures"
        map_attribute "cd", to: :cd
        map_attribute "type", to: :signature_type
        map_element "CDSComment", to: :comment_value
        map_element "CDSReviewDate", to: :review_date
        map_element "CDSStatus", to: :status
        map_element "Signature", to: :signature_value
      end
    end
  end
end
