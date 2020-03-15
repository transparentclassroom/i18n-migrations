require 'active_support/inflector'
require 'active_support/core_ext/object'

module I18n
  module Migrations
    class MigrationFactory
      def initialize(migration_dir)
        @migration_dir = migration_dir
      end

      def all_versions
        Dir[@migration_dir + '/*.rb'].map { |name| File.basename(name).gsub('.rb', '') }
      end

      def get_migration(version:)
        File.read(migration_file(version: version))
      end

      def migration_file(version:)
        File.join(@migration_dir, "#{version}.rb")
      end

      def play_migration(version:, locale:, data:, metadata:, dictionary:, direction:)
        filename = File.join(@migration_dir, "#{version}.rb")
        require filename

        raise("Can't parse version: #{version}") unless version =~ /^(\d{12})_(.*)/
        migration_class_name = "#{$2.camelcase}#{$1}"

        translations = Translations.new(data: data, metadata: metadata)
        migration = begin
          migration_class_name.constantize.new(locale_code: locale,
                                               translations: translations,
                                               dictionary: dictionary,
                                               direction: direction)
        rescue
          raise "Couldn't load migration #{migration_class_name} in #{filename}"
        end

        migration.change
      end

      # This is a facade over our translations
      # data = all keys -> all translations in this locale
      # metadata = some keys -> metadata about the translation in this locale
      class Translations
        def initialize(data:, metadata:)
          @data, @metadata = data, metadata
        end

        def get_term(key)
          @data[key]
        end

        def set_term(key, value:, errors:, autotranslated:)
          #  translated_term, errors = lookup_with_errors(term, key: key)
          #  unless errors.empty?
          #    STDERR.puts "'#{term}' => '#{translated_term}'\n#{errors.join(', ').red}"
          #  end
          #  [translated_term, (errors.map { |e| "[error: #{e}]" } + ['[autotranslated]']).join("\n")]

          @data[key] = value
          @metadata[key].errors = errors
          @metadata[key].notes = nil
          @metadata[key].autotranslated = autotranslated
        end

        def delete_term(key)
          @data.delete(key)
          @metadata.delete(key)
        end

        def move_term(from, to)
          @data[to] = @data.delete(from)
          @metadata[to] = @metadata.delete(from)
        end
      end
    end
  end
end
