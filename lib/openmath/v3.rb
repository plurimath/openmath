# frozen_string_literal: true

module Openmath
  # OpenMath 3: the draft standard (the object grammar is the same shape as
  # OpenMath 2's; the versioned hierarchy carries the distinction).
  module V3
    autoload :Configuration, "openmath/v3/configuration"
    autoload :CommonElements, "openmath/v3/common_elements"
    autoload :Oms, "openmath/v3/oms"
    autoload :Omv, "openmath/v3/omv"
    autoload :Omi, "openmath/v3/omi"
    autoload :Omb, "openmath/v3/omb"
    autoload :Omstr, "openmath/v3/omstr"
    autoload :Omf, "openmath/v3/omf"
    autoload :Oma, "openmath/v3/oma"
    autoload :Ombind, "openmath/v3/ombind"
    autoload :Ombvar, "openmath/v3/ombvar"
    autoload :Ome, "openmath/v3/ome"
    autoload :Omattr, "openmath/v3/omattr"
    autoload :Omatp, "openmath/v3/omatp"
    autoload :Omr, "openmath/v3/omr"
    autoload :Omforeign, "openmath/v3/omforeign"
    autoload :Omobj, "openmath/v3/omobj"

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
      CommonElements.singleton_class.prepend(Evaluation::Children::XMLParser)
      @registered = true
    end

    def parse(input)
      register_models!
      Omobj.from_xml(input, register: Configuration::CONTEXT_ID)
    end
  end
end
