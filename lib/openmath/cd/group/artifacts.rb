# frozen_string_literal: true

module Openmath
  module CD
    module Group
      # The only acquisition layer: checked local bytes. Never opens a URL.
      class Artifacts
        attr_reader :records

        def initialize(root: ROOT, manifest: "data/cd-groups/manifest.json")
          @root = File.realpath(root)
          metadata = JSON.parse(File.read(local_path(manifest)))
          @records = metadata.fetch("artifacts")
          @by_path = {}
          records.each do |record|
            path = record.fetch("path")
            if @by_path.key?(path)
              raise IntegrityError, "refused duplicate artifact #{path}"
            end
            @by_path[path] = record.freeze
          end
        rescue JSON::ParserError, KeyError => e
          raise IntegrityError, "refused manifest #{manifest}: #{e.message}"
        end

        def read(path)
          record = @by_path[path]
          raise IntegrityError, "refused unrecorded artifact #{path}" unless record

          bytes = File.binread(local_path(path))
          actual = Digest::SHA256.hexdigest(bytes)
          expected = record.fetch("sha256")
          unless actual == expected
            raise IntegrityError, "refused #{path}: SHA256 expected #{expected}, actual #{actual}"
          end
          bytes
        rescue Errno::ENOENT => e
          raise MissingMember, "refused missing local artifact #{path}: #{e.message}"
        end

        def check!
          records.each { |record| read(record.fetch("path")) }
          true
        end

        def local_path(path)
          unless path.is_a?(String) && !path.empty? && !path.include?("\0") &&
              !path.start_with?("/") &&
              !path.split("/").include?("..") && !path.include?(":")
            raise UnsafePath, "refused artifact path #{path.inspect}"
          end
          full = File.expand_path(path, @root)
          real = File.realpath(full)
          unless real.start_with?("#{@root}/")
            raise UnsafePath, "refused artifact path #{path.inspect} escaping #{@root}"
          end
          real
        rescue Errno::ENOENT
          raise MissingMember, "refused missing local artifact #{path}"
        end

        def self.xml(bytes, reference, error_class: InvalidGroup)
          document = Nokogiri::XML(bytes) { |config| config.strict.nonet }
          if document.internal_subset
            raise error_class, "refused #{reference}: DTD/entity declarations"
          end
          document
        rescue Nokogiri::XML::SyntaxError => e
          raise error_class, "refused #{reference}: #{e.message}"
        end
      end
    end
  end
end
