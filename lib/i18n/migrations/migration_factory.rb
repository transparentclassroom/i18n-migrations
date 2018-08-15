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

      def play_migration(version:, locale:, data:, notes:, dictionary:, direction:)
        filename = File.join(@migration_dir, "#{version}.rb")
        require filename

        raise("Can't parse version: #{version}") unless version =~ /^(\d{12})_(.*)/
        migration_class_name = "#{$2.camelcase}#{$1}"

        migration = begin
          migration_class_name.constantize.new(locale, data, notes, dictionary, direction)
        rescue
          raise "Couldn't load migration #{migration_class_name} in #{filename}"
        end

        migration.change
      end
    end
  end
end
