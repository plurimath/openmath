# frozen_string_literal: true

module Openmath
  # OpenMath 2: the published standard (2004).
  module V2
    autoload :Configuration, "openmath/v2/configuration"
    autoload :CommonElements, "openmath/v2/common_elements"
    autoload :Oms, "openmath/v2/oms"
    autoload :Omv, "openmath/v2/omv"
    autoload :Omi, "openmath/v2/omi"
    autoload :Omb, "openmath/v2/omb"
    autoload :Omstr, "openmath/v2/omstr"
    autoload :Omf, "openmath/v2/omf"
    autoload :Oma, "openmath/v2/oma"
    autoload :Ombind, "openmath/v2/ombind"
    autoload :Ombvar, "openmath/v2/ombvar"
    autoload :Ome, "openmath/v2/ome"
    autoload :Omattr, "openmath/v2/omattr"
    autoload :Omatp, "openmath/v2/omatp"
    autoload :Omr, "openmath/v2/omr"
    autoload :Omforeign, "openmath/v2/omforeign"
    autoload :Omobj, "openmath/v2/omobj"

    module_function

    # Registers every element class with this version's context, once per
    # process (the Mml::VersionedParser pattern).
    def register_models!
      return if @registered

      Configuration.register_model(Oms,       id: :oms)
      Configuration.register_model(Omv,       id: :omv)
      Configuration.register_model(Omi,       id: :omi)
      Configuration.register_model(Omb,       id: :omb)
      Configuration.register_model(Omstr,     id: :omstr)
      Configuration.register_model(Omf,       id: :omf)
      Configuration.register_model(Oma,       id: :oma)
      Configuration.register_model(Ombind,    id: :ombind)
      Configuration.register_model(Ombvar,    id: :ombvar)
      Configuration.register_model(Ome,       id: :ome)
      Configuration.register_model(Omattr,    id: :omattr)
      Configuration.register_model(Omatp,     id: :omatp)
      Configuration.register_model(Omforeign, id: :omforeign)
      Configuration.register_model(Omr,       id: :omr)
      Configuration.register_model(Omobj,     id: :omobj)
      @registered = true
    end

    def parse(input)
      register_models!
      Foreign.capture(Omobj.from_xml(input, register: Configuration::CONTEXT_ID), input)
    end
  end
end
