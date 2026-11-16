# frozen_string_literal: true

# Vendors the round-trip corpus: every OpenMath object embedded in the
# official CD collection's examples (OpenMath/CDs, cd/Official/*.ocd),
# extracted into spec/fixtures/corpus/ one file per object, with the
# source recorded per file in CORPUS_PROVENANCE.md.
#
# Usage: bundle exec ruby scripts/vendor_corpus.rb <path-to-CDs-checkout>
require "fileutils"
require "nokogiri"

cds_root = ARGV.fetch(0) { abort "usage: vendor_corpus.rb <CDs-checkout>" }
out = File.expand_path("../spec/fixtures/corpus", __dir__)
FileUtils.mkdir_p(out)
File.delete(*Dir.glob(File.join(out, "*.omxml")))

provenance = ["# Corpus provenance", "",
              "Extracted from the official CD collection (OpenMath/CDs, cd/Official),",
              "one OpenMath object per file; the source CD element is recorded.",
              "Regenerate with scripts/vendor_corpus.rb against a CDs checkout.", ""]
count = 0

Dir[File.join(cds_root, "cd/Official/*.ocd")].sort.each do |ocd_path|
  cd_name = File.basename(ocd_path, ".ocd")
  doc = Nokogiri::XML(File.read(ocd_path))
  doc.xpath("//*[local-name()='OMOBJ']").each_with_index do |omobj, index|
    count += 1
    id = "#{cd_name}-#{format('%03d', index + 1)}"
    File.write(File.join(out, "#{id}.omxml"), omobj.to_xml.rstrip + "\n")
    provenance << "- `#{id}.omxml` — #{File.basename(ocd_path)} (cd #{cd_name}), object #{index + 1}"
  end
rescue StandardError => e
  warn "#{ocd_path}: #{e.class}: #{e.message}"
end

File.write(File.expand_path("../spec/fixtures/CORPUS_PROVENANCE.md", __dir__),
           provenance.join("\n") + "\n")
puts "vendored #{count} objects"
