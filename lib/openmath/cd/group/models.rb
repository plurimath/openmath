# frozen_string_literal: true

module Openmath
  module CD
    module Group
      class Namespace < Lutaml::Xml::Namespace
        uri "http://www.openmath.org/OpenMathCDG"
      end

      class Member < Lutaml::Model::Serializable
        attribute :cd_name, :string
        attribute :cd_version, :string
        attribute :cd_url, :string
        attribute :comment, :string

        xml do
          namespace Namespace
          element "CDGroupMember"
          map_element "CDName", to: :cd_name
          map_element "CDVersion", to: :cd_version
          map_element "CDURL", to: :cd_url
          map_element "CDComment", to: :comment
        end
      end

      class Document < Lutaml::Model::Serializable
        attribute :name, :string
        attribute :version, :string
        attribute :revision, :string
        attribute :url, :string
        attribute :description, :string
        attribute :members, Member, collection: true
        attribute :includes, :string, collection: true
        attribute :comments, :string, collection: true

        xml do
          namespace Namespace
          element "CDGroup"
          map_element "CDGroupName", to: :name
          map_element "CDGroupVersion", to: :version
          map_element "CDGroupRevision", to: :revision
          map_element "CDGroupURL", to: :url
          map_element "CDGroupDescription", to: :description
          map_element "CDGroupMember", to: :members
          map_element "CDGroupInclude", to: :includes
          map_element "CDComment", to: :comments
        end
      end
    end
  end
end
