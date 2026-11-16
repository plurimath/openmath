# CDGroups local acquisition profile

Admission: openmath 7719764a4fc7fe1438a49edfae23adb9a0b14405.
Immutable source: OpenMath/CDs cbf607561e3f90630ce7a57fe9a85f5bc0dfdd3c.
No cross-repository runtime or branch dependency is introduced.

`data/cd-groups/manifest.json` records source URLs and SHA256 for all 38
`cd/Official/*.ocd` files, all 20 `cdgroups/*.cdg` files, and both authoritative
group grammars. Source bytes are verbatim, including copyright notices. The
archive's Git pax comment identifies the recorded commit; the acquisition URL
and archive SHA256 also record the fetched archive. `scripts/vendor_cd_collection.rb
--check` is offline and refuses missing, modified or unrecorded artifacts.
Refreshing data means updating and reviewing the source manifest, corpus record
and extension descriptor together; the script never silently fetches new bytes.

`Openmath::CD::Group.parse(xml)` validates the official grammar before LutaML
mapping. Compatibility profile: a root `version="2.0"` attribute is removed from
a validation copy because upstream groups contain it but upstream's grammar
omits it. Other versions, fields, malformed XML and DTDs are refused. The
original files and both grammars are never rewritten. CDGroup's grammar has
member versions but no member revision or base fields. Revisions and bases come
from the checked acquisition inventory, not a guessed `CDRevision` extension.
`CDGroupInclude` is modeled and explicitly refused during member acquisition;
recursive group inclusion is not silently ignored or fetched.

`Group::PinnedCollection` implements `resolve(cd:, name:, cdbase:)`, `[]`,
`documents` and `size`, plus `fetch(..., version:, revision:)` and version/revision
constraints on `resolve`. It indexes every exact base/name/version/revision key.
Name-only lookup is permitted only when that base/name has a single candidate.
A missing symbol returns nil. A missing dictionary, wrong base/version/revision,
ambiguous revisions, or duplicate exact identity raises a typed diagnostic.
Both requested and available revisions are named on mismatches. CDBase defaults
to `http://www.openmath.org/cd` for the two source files that omit it; no explicit
base is relaxed or normalized. Member URLs are checked against local CDURL.

Members can only come from a local checksummed `Artifacts` inventory. A caller
can supply an inventory rooted in another local directory; paths and symlinks
must stay within that root. There is no URL reader or runtime acquisition code.
The official source's groups also refer to experimental and contributed CDs,
and some references are absent from this source. Those are not relabeled as
Official. `corpora/groups/manifest.json` inventories unavailable official members
per group; acquisition refuses these names instead of returning a partial set.
For example, `arith.cdg` references experimental `arith2`, while `fns.cdg` is fully
covered by the official inventory. V-roll must retain this distinction when
classifying corpus acceptance.

The extension installer provides `Openmath.parse_cd_group` and
`Openmath.official_cd_collection`. On the admission base tests require the module
explicitly. F-ext public discovery and packaged API verification must pass on the
same descriptor after F-ext reaches main, before merge. No public discovery or
package acceptance is asserted by standalone module verification.
