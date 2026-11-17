# frozen_string_literal: true

require "lutaml/model"

module Openmath
  module CD
    # A member entry: the CD name with its pinned version and optional
    # location.
    class GroupMember < Lutaml::Model::Serializable
      attribute :comment, :string
      attribute :cd_name, :string
      attribute :cd_version, :string
      attribute :cd_url, :string

      xml do
        namespace GroupNamespace
        element "CDGroupMember"
        map_element "CDComment", to: :comment
        map_element "CDName", to: :cd_name
        map_element "CDVersion", to: :cd_version
        map_element "CDURL", to: :cd_url
      end
    end

    # The CDGroup document model (omcdgroup2.rnc, the OpenMathCDG
    # namespace): the group's name, version, revision, URL and
    # description, then the member entries with their pinned CDVersion.
    class GroupDocument < Lutaml::Model::Serializable
      attribute :name, :string
      attribute :group_version, :string
      attribute :group_revision, :string
      attribute :url, :string
      attribute :group_description, :string
      attribute :comment_value, :string, collection: true
      attribute :member_value, GroupMember, collection: true

      xml do
        namespace GroupNamespace
        element "CDGroup"
        map_element "CDGroupName", to: :name
        map_element "CDGroupVersion", to: :group_version
        map_element "CDGroupRevision", to: :group_revision
        map_element "CDGroupURL", to: :url
        map_element "CDGroupDescription", to: :group_description
        map_element "CDComment", to: :comment_value
        map_element "CDGroupMember", to: :member_value
      end
    end
  end
end
