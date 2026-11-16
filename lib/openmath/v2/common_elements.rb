# frozen_string_literal: true

module Openmath
  module V2
    # The shared parent of the OpenMath 2 element classes: the child object
    # collections and their element maps, modeled from schemas/openmath2.rnc
    # (the OpenMath 2 RelaxNG schema, vendored from OpenMath/OMSVN). Child
    # types are declared as symbols resolved through this version's
    # registered models.
    class CommonElements < Openmath::CommonElements
      def self.lutaml_default_register
        Configuration::CONTEXT_ID
      end

      attribute :oms_value, :oms, collection: true
      attribute :omv_value, :omv, collection: true
      attribute :omi_value, :omi, collection: true
      attribute :omb_value, :omb, collection: true
      attribute :omstr_value, :omstr, collection: true
      attribute :omf_value, :omf, collection: true
      attribute :oma_value, :oma, collection: true
      attribute :ombind_value, :ombind, collection: true
      attribute :ombvar_value, :ombvar, collection: true
      attribute :ome_value, :ome, collection: true
      attribute :omattr_value, :omattr, collection: true
      attribute :omatp_value, :omatp, collection: true
      attribute :omforeign_value, :omforeign, collection: true
      attribute :omr_value, :omr, collection: true

      xml do
        namespace Openmath::Namespace
        map_element "OMS", to: :oms_value
        map_element "OMV", to: :omv_value
        map_element "OMI", to: :omi_value
        map_element "OMB", to: :omb_value
        map_element "OMSTR", to: :omstr_value
        map_element "OMF", to: :omf_value
        map_element "OMA", to: :oma_value
        map_element "OMBIND", to: :ombind_value
        map_element "OMBVAR", to: :ombvar_value
        map_element "OME", to: :ome_value
        map_element "OMATTR", to: :omattr_value
        map_element "OMATP", to: :omatp_value
        map_element "OMFOREIGN", to: :omforeign_value
        map_element "OMR", to: :omr_value
      end
    end
  end
end
