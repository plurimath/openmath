# Schema provenance

All schemas are vendored verbatim from the OpenMath society's repositories
(cloned at openmath-reference/ in the workspace) so that validation never
depends on the network.

| File | Source | Notes |
|---|---|---|
| `openmath2.rng` | https://github.com/OpenMath/OMSVN, `www/standard/om20-2013-07-11/openmath2.rng` | The OpenMath 2 RelaxNG schema from the standard's second distribution. |
| `openmath2.rnc` | https://github.com/OpenMath/OMSVN, `formerCVS/OpenMath2/openmath2.rnc` | The same grammar in compact syntax, kept for reference. |
| `omcdgroup2.rng` | https://github.com/OpenMath/OMSVN, `formerCVS/OpenMath2/omcdgroup2.rnc`, compiled to RNG with the OMSVN trang.jar | The CDGroup grammar (OpenMathCDG namespace), compiled because nokogiri validates XML-form RelaxNG. |
| `omcdgroup2.rnc` | https://github.com/OpenMath/OMSVN, `formerCVS/OpenMath2/omcdgroup2.rnc` | The same grammar in compact syntax, kept for reference. |
| `omcd2.rng` | https://github.com/OpenMath/OMSVN, `formerCVS/OpenMath2/omcd2.rnc` | The CD grammar (OpenMathCD namespace). |
| `openmath3.rng` | https://github.com/OpenMath/OMSVN, `OpenMath3-effort-2009/rnc/openmath3.rng` | The OpenMath 3 draft schema (2009 effort); includes `om3-common.rng`. |
| `om3-common.rng` | https://github.com/OpenMath/OMSVN, `OpenMath3-effort-2009/rnc/om3-common.rng` | The OM3 draft's shared grammar. |

The object grammars of OpenMath 2 and the OM3 draft are the same shape; the
version distinction is carried by the document's `version` attribute and the
gem's versioned class hierarchies. Re-vendoring on an OM3 draft move is a
deliberate, recorded change.
