# frozen_string_literal: true

module Openmath
  module V3
    # Registers the version's element classes under this version's LutaML
    # context, so the symbol-typed child attributes resolve (the Mml
    # pattern).
    module Configuration
      CONTEXT_ID = :openmath_v3

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
    end
  end
end
