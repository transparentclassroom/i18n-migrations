require 'i18n/migrations/migration'

# this is a simple migrations class for testing
class SimpleMigrations
  class OneMigration < I18n::Migrations::Migration
    def change
      add 'one', 'ONE'
    end
  end

  class TwoMigration < I18n::Migrations::Migration
    def change
      add 'two', 'TWO'
    end
  end

  def initialize
    @migrations = {}
  end

  def all_versions
    @migrations.keys
  end

  def play_migration(version:, locale:, data:, metadata:, dictionary:, direction:)
    translations = I18n::Migrations::MigrationFactory::Translations.new(locale_code: locale,
                                                                        data: data,
                                                                        metadata: metadata)
    migration = @migrations[version].new(locale_code: locale,
                                         translations: translations,
                                         dictionary: dictionary,
                                         direction: direction)
    migration.change
  end

  def add(version, migration_class)
    @migrations[version] = migration_class
  end
end
