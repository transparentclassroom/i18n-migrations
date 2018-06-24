require 'fileutils'
require 'yaml'
require 'active_support/inflector'
require 'active_support/core_ext/object'
require 'colorize'

$LOAD_PATH.unshift(File.dirname(__FILE__))
require 'google_translate_dictionary'
require 'google_spreadsheet'
require 'config'
require 'locale'
require 'migration_factory'

# this class knows how to do all the things the cli needs done.
# it mostly delegates to locale to do it, often asking multiple locales to do the same thing
module I18n
  module Migrations
    class Migrator
      def locale_for(name)
        Locale.new(name,
                   locales_dir: config.locales_dir,
                   main_locale_name: config.main_locale,
                   migrations: MigrationFactory.new(config.migration_dir),
                   dictionary: new_dictionary(name))
      end

      def config
        @config ||= Config.new.read!
      end

      # for testing
      def config=(config)
        @config = config
      end

      def new_migration(name)
        name = name.parameterize(separator: '_')
        file_name = "#{Time.now.strftime('%Y%m%d%H%M')}_#{name.downcase.gsub(' ', '_')}.rb"
        unless Dir.exist?(config.migration_dir)
          puts "Creating migration directory #{config.migration_dir} because it didn't exist."
          FileUtils.mkdir_p(config.migration_dir)
        end
        File.open(File.join(config.migration_dir, file_name), 'w') do |f|
          f << <<-CONTENTS
require 'i18n-migrations'

class #{name.camelcase} < I18n::Migrations::Migration
  def change
    # add('foo.bar', 'The foo of the bar')
  end
end
          CONTENTS
        end
        puts "Wrote new migration to #{file_name}"
      end

      def migrate(locale_or_all = 'all')
        each_locale(locale_or_all) do |locale|
          locale.update_info do |data, notes|
            locale.migrate(data, notes)
          end
        end
      end

      def rollback(locale_or_all)
        each_locale(locale_or_all) do |locale|
          locale.update_info do |data, notes|
            locale.rollback(data, notes)
          end
        end
      end

      def pull(locale_or_all)
        each_locale(locale_or_all) do |locale|
          next if locale.main_locale?
          sheet = get_google_spreadsheet(locale.name)
          locale.pull(sheet)
          migrate(locale.name)
        end
      end

      def push(locale_or_all, force = false)
        each_locale(locale_or_all) do |locale|
          next if locale.main_locale?
          sheet = get_google_spreadsheet(locale.name)
          unless force
            locale.pull(sheet)
            migrate(locale.name)
          end
          locale.push(sheet)
        end
      end

      def new_locale(new_locale, limit = nil)
        locale_for(new_locale).create
      end

      def version
        each_locale do |locale|
          puts "#{locale.name}: #{locale.last_version}"
        end
      end

      def validate(locale_or_all)
        each_locale(locale_or_all) do |locale|
          next if locale.main_locale?
          locale.update_info do |data, notes|
            locale.validate(data, notes)
          end
        end
      end

      private

      def each_locale(name = 'all')
        (name == 'all' ? all_locale_names : [name]).each do |l|
          yield locale_for(l)
        end
      end

      def all_locale_names
        [config.main_locale] + config.other_locales
      end

      def get_google_spreadsheet(locale)
        GoogleSpreadsheet.new(locale,
                              config.google_spreadsheets[locale],
                              config.google_service_account_key_path).sheet
      end

      def new_dictionary(locale)
        GoogleTranslateDictionary.new(from_locale: config.main_locale,
                                      to_locale: locale,
                                      key: config.google_translate_api_key,
                                      do_not_translate: config.do_not_translate)
      end
    end
  end
end
