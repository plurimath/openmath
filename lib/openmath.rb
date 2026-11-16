# frozen_string_literal: true

require "lutaml/model"

module Openmath
  autoload :VERSION, "openmath/version"
  autoload :CommonElements, "openmath/common_elements"
  autoload :Namespace, "openmath/namespace"
  autoload :V2, "openmath/v2"

  module Base
    autoload :Oms, "openmath/base/oms"
    autoload :Omv, "openmath/base/omv"
    autoload :Omi, "openmath/base/omi"
    autoload :Omf, "openmath/base/omf"
    autoload :Oma, "openmath/base/oma"
    autoload :Ombind, "openmath/base/ombind"
    autoload :Omb, "openmath/base/omb"
    autoload :Omstr, "openmath/base/omstr"
    autoload :Ombvar, "openmath/base/ombvar"
    autoload :Ome, "openmath/base/ome"
    autoload :Omattr, "openmath/base/omattr"
    autoload :Omatp, "openmath/base/omatp"
    autoload :Omr, "openmath/base/omr"
    autoload :Omforeign, "openmath/base/omforeign"
    autoload :Common, "openmath/base/common"
    autoload :Compound, "openmath/base/compound"
    autoload :Omobj, "openmath/base/omobj"
  end

  # Parses an OpenMath XML document into the typed model of the requested
  # version. OpenMath 2 is the published standard; OpenMath 3 arrives with
  # its own versioned hierarchy (plurimath/plurimath#582).
  def parse(input, version: 2)
    case version
    when 2 then V2.parse(input)
    else raise ArgumentError, "unsupported OpenMath version #{version.inspect}"
    end
  end

  module_function :parse
end
