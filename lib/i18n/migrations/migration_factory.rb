require 'active_support/inflector'

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
        File.read(File.join(@migration_dir, "#{version}.rb"))
      end

      def play_migration(version:, locale:, data:, notes:, dictionary:, direction:)
        filename = File.join(@migration_dir, "#{version}.rb")
        require filename

        raise("Can't parse version: #{version}") unless version =~ /^(\d{12})_(.*)/
        migration_class_name = "#{$2.camelcase}#{$1}"

        translations = Translations.new(data: data, notes: notes)
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
      # notes = some keys -> notes about the translation in this locale
      class Translations
        def initialize(data:, notes:)
          @data, @notes = data, notes
        end

        def get_term(key)
          @data[key]
        end

        def set_term(key, value:, notes: nil)
          @data[key] = value
          if notes.present?
            @notes[key] = notes
          else
            @notes.delete(key)
          end
        end

        def delete_term(key)
          @data.delete(key)
          @notes.delete(key)
        end

        def move_term(from, to)
          @data[to] = @data.delete(from)
          @notes[to] = @notes.delete(from)
        end
      end
    end
  end
end
