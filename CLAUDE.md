# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working
with code in this repository.

## Project Overview

`openmath` parses the OpenMath XML encoding into a typed model declared
with LutaML Model, and serializes it back. Version-scoped hierarchies:
`Openmath::V2` (the published standard) today, `Openmath::V3` (the draft)
when its model lands. Part of the Plurimath ecosystem.

## Commands

```bash
rake                                # specs (default task)
bundle exec rspec                   # run the suite
bundle exec rspec spec/openmath/v2/roundtrip_spec.rb:14  # single spec
```

## Architecture

- **mml-pattern composition**: `Openmath::V2::CommonElements` holds the
  child object collections and element maps; `lib/openmath/base/*.rb`
  modules add each element's attributes and root; the version classes
  (`Openmath::V2::Oms` …) subclass CommonElements and include their Base
  module. Follow the mml gem's structure when extending.
- **Canonical serialization**: `Openmath::Canonical` emits one
  deterministic form (sorted attributes, default namespace on the canonical
  root, no inter-element whitespace, OMI/OMB whitespace stripped, OMSTR and
  foreign fragments verbatim). `#to_canonical_xml`/`#canonical_sha256` on
  `Openmath::CommonElements`; `Openmath.canonical_equal?` compares.
- **Registry, not direct types**: child attributes declare SYMBOL types
  (`attribute :oms_value, :oms, collection: true`) resolved through
  `Openmath::V2::Configuration`'s LutaML context
  (`lutaml_default_register :openmath_v2`). `V2.parse` calls
  `register_models!` once per process. Declaring direct class types in a
  superclass body creates a load-order inheritance race — do not revert
  to direct types.
- **Schema-first**: `schemas/openmath2.rnc` is the authoritative content
  model (vendored from OpenMath/OMSVN, formerCVS/OpenMath2). Verify every
  element/attribute against the schema before modeling; the Common and
  Compound attribute modules mirror the schema's `common.attributes` and
  `compound.attributes`.
- **Namespace**: `Openmath::Namespace` (Lutaml::Xml::Namespace, uri
  `http://www.openmath.org/OpenMath`). Both unprefixed and `om:`-prefixed
  documents parse.
- **Ordered containers**: OMA/OMBIND/OME/OMATTR/OMATP/OMBVAR/OMOBJ are
  element-only (`ordered`); OMATP's pairs alternate (symbol, value) and
  the document order is the pairing.

## Conventions

- `frozen_string_literal: true` in all files; autoloads in the immediate
  parent namespace's file (no `require_relative` for internal code).
- `Gemfile.lock` is gitignored; dependencies come from the gemspec.
- CI workflows: release via metanorma/ci's rubygems-release (OIDC Trusted
  Publishing); tests are plain rspec for now.

## Known limitations (by design at 0.1.0)

- No schema validation of the root element; the reader is lenient.
- Foreign markup inside OMFOREIGN is captured verbatim by
  `Openmath::Foreign.capture` (parse-time Moxml pass into `notom_value`,
  re-emitted at recorded positions on serialization); the mapping DSL has no
  arbitrary-markup representation, so capture rides the source pass, not the
  lutaml mappings.
- OpenMath 3 parses through its own hierarchy (`Openmath::V3`,
  `Openmath.parse(version: 3)`); the OM3 draft schema validates it.
