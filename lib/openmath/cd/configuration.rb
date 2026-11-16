# frozen_string_literal: true

module Openmath
  module CD
    # Registers the CD model family (and the OpenMath object models its
    # FMP/Example elements embed) under this family's LutaML context.
    module Configuration
      CONTEXT_ID = :openmath_cd

      extend self

      def context
        Lutaml::Model::GlobalContext.context(CONTEXT_ID) || create_context!
      end

      def register_model(klass, id:)
        create_context! unless Lutaml::Model::GlobalContext.context(CONTEXT_ID)
        Lutaml::Model::GlobalContext.context(CONTEXT_ID)
                                    .registry.register(id.to_sym, klass)
        klass
      end

      def create_context!
        Lutaml::Model::GlobalContext.register_context(
          Lutaml::Model::TypeContext.new(
            id: CONTEXT_ID,
            registry: Lutaml::Model::TypeRegistry.new,
          ),
        )
        Lutaml::Model::GlobalContext.context(CONTEXT_ID)
      end

      # Registers the CD family and the object models the CD documents
      # embed, once per process.
      # The CD documents embed OpenMath objects, so the whole object
      # family must resolve in this context too.
      OBJECT_IDS = {
        oms: :Oms, omv: :Omv, omi: :Omi, omb: :Omb, omstr: :Omstr, omf: :Omf,
        oma: :Oma, ombind: :Ombind, ombvar: :Ombvar, ome: :Ome,
        omattr: :Omattr, omatp: :Omatp, omforeign: :Omforeign, omr: :Omr,
        omobj: :Omobj,
      }.freeze

      def register_models!
        return if @registered

        register_model(Fmp,        id: :fmp)
        register_model(Example,    id: :example)
        register_model(Definition, id: :definition)
        register_model(Document,   id: :cd)
        OBJECT_IDS.each do |id, const|
          register_model(Openmath::V2.const_get(const), id: id)
        end
        # The interpretive reader resolves symbol-typed attributes against
        # the default context (the mml populate_context! pattern): the CD
        # family and its embedded object family must resolve there too.
        default_registry = Lutaml::Model::GlobalContext.context.registry
        { fmp: Fmp, example: Example, definition: Definition, cd: Document }
          .merge(OBJECT_IDS.to_h { |id, const| [id, Openmath::V2.const_get(const)] })
          .each { |id, klass| default_registry.register(id, klass) unless default_registry.registered?(id) }
        @registered = true
      end
    end
  end
end
