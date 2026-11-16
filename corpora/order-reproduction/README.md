# U0 order-tracking characterization

Admission: openmath `7719764a4fc7fe1438a49edfae23adb9a0b14405`.
This packet advances #16 by measurement; it changes no product code.

`manifest.json` contains authored XML fixture digests and independently recorded
expected child identities (tag, attributes and text). `VERSION` in each fixture
is replaced with `2.0` or `3.0` before parsing. All five fixtures describe OMA
children. Repeated empty and nonempty strings/bytes distinguish same-tag values;
the attribute-only case covers OMS, OMV and OMF. The planning counterexample is
included as a hypothesis to test, not assumed to be a reproduced defect.

`observed.json` records Ruby, every resolved gem version, git dependency revisions,
expected identities, parsed root/application element_order metadata, per-type
collections and output of the unchanged evaluator's `ordered_children` method.
The fallback method is called directly, including its existing append loop;
it is not reimplemented or repaired here. A legacy exception is recorded separately
from a mismatching returned sequence. Unexpected parse errors fail the harness;
only adapter loader failures become typed coverage refusals.

## Findings on the recorded environment

Ruby 4.0.1, lutaml-model 0.8.175 at
`fe146de346c4a7aa73ea26bb1131cad16697b5d7`, moxml and native dependency versions
are recorded in `observed.json`. Leptris and Nokogiri each preserve metadata order
and legacy output for all five cases under both V2 and V3 (20 observations).
No OpenMath ordering failure is reproduced in these cases.

The separate, exact #1163 Body/Wrapper map_all_content examples reproduce nil
content and nil child element_order under Leptris; Nokogiri preserves both.
Thus #1163 reproduces in its own mapping shape, but is **not an exact match**
for an OpenMath failure demonstrated by this packet. OpenMath's explicitly
ordered OMA mapping and the issue's raw-content mapping are different inputs.
These results do not prove other OpenMath trees immune to order loss.

Coverage is partial: Oga, REXML, Ox, HeadedOx and LibXML cannot load in this bundle.
Their original loader diagnostics and typed refusals are retained in the report.
No unapproved gem fetching or sibling repository changes were used to fill gaps.
Ruby 3.2–3.4 were not executed locally. The harness uses Ruby 3.2-compatible APIs;
tests do not require another Ruby to match the Ruby 4.0.1 version string.

The issue JSON is a checksummed local planning snapshot, with its official URL
and local source recorded in the manifest. Live API refresh returned HTTP 403;
no claim is made about current issue state. No successfully fetched network
artifacts were used.

## Reproduce and interpret exits

Run from the worktree through the shared serialized runner:

```
~/work/openmath-finalize/bin/check u0-json bundle exec ruby scripts/reproduce_element_order.rb --json
~/work/openmath-finalize/bin/check u0-integrity bundle exec ruby scripts/reproduce_element_order.rb --check
~/work/openmath-finalize/bin/check u0-spec bundle exec rspec spec/openmath/order_reproduction_spec.rb
~/work/openmath-finalize/bin/check u0-product bundle exec ruby scripts/reproduce_element_order.rb --json --assert-product
```

Default/`--json` exit 0 means the harness completed, including explicit coverage
refusals. It does not mean product assertions passed. `--assert-product` exits 2
with a typed CoverageError naming unavailable adapters, 1 for measured ordering
failure with complete coverage, or 0 for a complete passing matrix.
`measured_ordering_pass` reports measured cases alone. `product_ordering_pass`
is null when coverage is incomplete; it must not be interpreted as failure or
success. The RSpec harness can pass with captured product failures or coverage gaps.

`--check` verifies all manifest fixture/issue hashes plus the checksums index,
including the manifest and recorded report. Tests independently extract expected
sequences with Nokogiri and compare live observations when the exact recorded
runtime and dependency set match. Other environments run the probes and validate
matrix coverage without claiming equality to this environment's saved result.

To deliberately refresh measurements, run `--json --record` through the runner,
inspect the report, and regenerate `checksums.json` from the manifest, issue JSON,
observed JSON and all manifest fixture paths using SHA256. Never bless a changed
fixture or dependency without reviewing the resulting expectations and evidence.
