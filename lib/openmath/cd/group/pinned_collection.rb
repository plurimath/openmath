# frozen_string_literal: true

module Openmath
  module CD
    module Group
      # A Collection-compatible resolver retaining all base/version/revision
      # identities. The existing name-only Collection is deliberately untouched.
      class PinnedCollection
        attr_reader :artifacts

        def initialize(artifacts: Artifacts.new)
          @artifacts = artifacts
          @entries = {}
          @documents = {}
          artifacts.records.select { |r| r["kind"] == "cd" }.each do |record|
            key = %w[base name version revision].map { |field| record.fetch(field) }
            if @entries.key?(key)
              previous = @entries.fetch(key)
              raise DuplicateRevision,
                    "refused duplicate #{key.inspect}: revisions #{previous['revision']} and #{record['revision']}"
            end
            @entries[key.freeze] = record
          end
        end

        def size
          @entries.size
        end

        # Header/integrity verification does not materialize all embedded FMP
        # object graphs. Corpus evaluation belongs to V-roll.
        def verify!
          artifacts.check!
          @entries.each_key { |key| dictionary_xml(key) }
          true
        end

        def documents
          @entries.keys.map { |key| load_document(key) }
        end

        def [](name)
          fetch(cd: name)
        end

        def fetch(cd:, cdbase: DEFAULT_BASE, version: nil, revision: nil)
          candidates = @entries.keys.select { |base, name, _, _| base == cdbase && name == cd }
          matching = candidates.select do |_, _, v, r|
            (version.nil? || v == version.to_s) && (revision.nil? || r == revision.to_s)
          end
          reference = "#{cdbase}/#{cd} version #{version.inspect} revision #{revision.inspect}"
          if matching.empty?
            available = @entries.keys.select { |_, name, _, _| name == cd }
            raise IdentityMismatch,
                  "refused #{reference}; available base/version/revisions: #{available.inspect}"
          end
          if matching.size > 1
            raise AmbiguousRevision,
                  "refused #{reference}; competing base/version/revisions: #{matching.inspect}"
          end
          load_document(matching.first)
        end

        def resolve(cd:, name:, cdbase: DEFAULT_BASE, version: nil, revision: nil)
          fetch(cd: cd, cdbase: cdbase || DEFAULT_BASE, version: version,
                revision: revision).definition_for(name)
        end

        def group(name)
          path = artifacts.records.find do |record|
            record["kind"] == "group" && File.basename(record["path"], ".cdg") == name
          end&.fetch("path")
          raise MissingMember, "refused unrecorded CDGroup #{name.inspect}" unless path

          Group.parse(artifacts.read(path))
        end

        # Member versions are constraints; revisions come from the pinned local
        # inventory, since the official CDGroup grammar has no CDRevision field.
        def members(group)
          unless group.includes.empty?
            raise UnsupportedInclude, "refused CDGroupInclude #{group.includes.inspect} in #{group.name}"
          end
          group.members.map do |member|
            document = fetch(cd: member.cd_name, version: member.cd_version)
            if member.cd_url && member.cd_url != document.cd_url
              raise IdentityMismatch,
                    "refused member #{member.cd_name} URL #{member.cd_url.inspect}; revision #{document.cd_revision} URL #{document.cd_url.inspect}"
            end
            document
          end
        end

        private

        def load_document(key)
          return @documents[key] if @documents.key?(key)

          @documents[key] = Openmath::CD.parse(dictionary_xml(key))
        end

        def dictionary_xml(key)
          record = @entries.fetch(key)
          xml = artifacts.read(record.fetch("path"))
          parsed = Artifacts.xml(xml, record.fetch("path"), error_class: InvalidDictionary)
          if parsed.root&.name != "CD" || parsed.root.namespace&.href != "http://www.openmath.org/OpenMathCD"
            raise InvalidDictionary, "refused CD root in #{record['path']}"
          end
          actual = %w[CDBase CDName CDVersion CDRevision].map do |tag|
            parsed.at_xpath("/c:CD/c:#{tag}", "c" => "http://www.openmath.org/OpenMathCD")&.text&.strip
          end
          actual[0] ||= DEFAULT_BASE
          unless actual == key
            raise IdentityMismatch,
                  "refused #{record['path']}: expected base/name/version/revision #{key.inspect}, actual #{actual.inspect}"
          end
          xml
        end
      end
    end
  end
end
