# frozen_string_literal: true

require "leptris"

module Openmath
  module CD
    # A revision-pinned CD collection: loads a CDGroup document (the
    # OpenMathCDG namespace, omcdgroup2.rnc) and then each member CD from
    # a local root or the member's recorded URL, refusing to resolve any
    # symbol whose dictionary's CDVersion contradicts the pin. Provenance
    # records the exact group document and the member revisions.
    class GroupCollection
      # The loaded dictionary's CDVersion contradicts the group's pin.
      class VersionMismatchError < StandardError
        attr_reader :cd, :pinned, :actual

        def initialize(cd, pinned, actual)
          @cd = cd
          @pinned = pinned
          @actual = actual
          super("CD version mismatch for #{cd}: group pins #{pinned.inspect}, loaded #{actual.inspect}")
        end
      end

      # The group names a CD no loader could find.
      class MemberNotFoundError < StandardError
        attr_reader :cd, :source

        def initialize(cd, source)
          @cd = cd
          @source = source
          super("CDGroup member #{cd} not found (source: #{source.inspect})")
        end
      end

      attr_reader :group, :collection, :pins

      def initialize(group, collection)
        @group = group
        @collection = collection
        @pins = group.member_value
          .select { |member| member.cd_version }
          .map { |member| [member.cd_name, member.cd_version] }
          .to_h
      end

      # Resolves a symbol through the pinned collection: a cdbase mismatch
      # refuses as in Collection#resolve, and a pinned dictionary whose
      # loaded CDVersion contradicts the pin refuses naming the CD and
      # both revisions.
      def resolve(cd:, name:, cdbase: nil)
        document = collection[cd]
        if @pins.key?(cd) && document && document.cd_version != @pins[cd]
          raise VersionMismatchError.new(cd, @pins[cd], document.cd_version)
        end

        collection.resolve(cd: cd, name: name, cdbase: cdbase)
      end

      def [](name)
        collection[name]
      end

      class << self
        # Loads a group document (XML text or file path) and its member
        # CDs. Member sources resolve against +root+ (a directory holding
        # <CDName>.ocd files) or the member's CDURL; without either, only
        # members already loaded into +collection+ count.
        def load(group_source, root: nil, collection: Collection.new)
          group = Group.parse(group_source)
          group.member_value.each do |member|
            source = member_source(member, root)
            if source
              collection.load(source)
            elsif collection[member.cd_name].nil?
              raise MemberNotFoundError.new(member.cd_name, member.cd_url || root)
            end
            document = collection[member.cd_name]
            next unless member.cd_version && document &&
                        document.cd_version != member.cd_version

            raise VersionMismatchError.new(member.cd_name, member.cd_version,
                                           document.cd_version)
          end
          new(group, collection)
        end

        # Validates a group document against the vendored omcdgroup2.rng.
        # Returns the list of Openmath::Validation::Error objects; empty
        # when valid.
        def validate(xml)
          @schema ||= Leptris::XML::RelaxNG.parse_file(
            File.expand_path("../../../schemas/omcdgroup2.rng", __dir__),
          )
          begin
            document = Leptris::XML.parse(xml, strict: true)
          rescue Leptris::XML::ParseError
            raise Openmath::Validation::ValidationError,
                  [Openmath::Validation::Error.new("malformed XML", "/")]
          end

          @schema.validate(document).map do |e|
            Openmath::Validation::Error.new(e, nil)
          end
        end

        def validate!(xml)
          errors = validate(xml)
          raise Openmath::Validation::ValidationError, errors unless errors.empty?

          true
        end

        def valid?(xml)
          validate(xml).empty?
        end

        private

        def member_source(member, root)
          candidate = root ? File.join(root, "#{member.cd_name}.ocd") : nil
          return candidate if candidate && File.exist?(candidate)

          member.cd_url if member.cd_url && File.exist?(member.cd_url)
        end
      end
    end

    # The group-level API: parse, validate, load.
    module Group
      module_function

      def parse(source)
        if source.match?(/\A</)
          GroupDocument.from_xml(source)
        else
          GroupDocument.from_xml(File.read(source))
        end
      end

      def validate(xml)
        GroupCollection.validate(xml)
      end

      def validate!(xml)
        GroupCollection.validate!(xml)
      end

      def valid?(xml)
        GroupCollection.valid?(xml)
      end

      def load(source, **options)
        GroupCollection.load(source, **options)
      end
    end
  end
end
