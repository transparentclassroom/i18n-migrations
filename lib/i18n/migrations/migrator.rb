require 'fileutils'
require 'yaml'
require 'active_support/inflector'
require 'active_support/core_ext/object'
require 'colorize'

require 'i18n/migrations/backends/crowd_translate_backend'
require 'i18n/migrations/backends/google_spreadsheets_backend'
require 'i18n/migrations/config'
require 'i18n/migrations/google_translate_dictionary'
require 'i18n/migrations/locale'
require 'i18n/migrations/migration_factory'

# this class knows how to do all the things the cli needs done.
# it mostly delegates to locale to do it, often asking multiple locales to do the same thing
module I18n
  module Migrations
    class Migrator
      def locale_for(name)
        Locale.new(name,
                   locales_dir: config.locales_dir,
                   main_locale_name: config.main_locale,
                   migrations: new_migrations,
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
        time = Time.now.strftime('%Y%m%d%H%M')
        file_name = "#{time}_#{name.downcase.gsub(' ', '_')}.rb"
        unless Dir.exist?(config.migration_dir)
          puts "Creating migration directory #{config.migration_dir} because it didn't exist."
          FileUtils.mkdir_p(config.migration_dir)
        end
        full_file_name = File.join(config.migration_dir, file_name)
        File.open(full_file_name, 'w') do |f|
          f << <<-CONTENTS
require 'i18n-migrations'

class #{name.camelcase}#{time} < I18n::Migrations::Migration
  def change
    # add('foo.bar', 'The foo of the bar')
  end
end
          CONTENTS
        end
        puts "Wrote new migration to #{full_file_name}"
      end

      def migrate(locale_or_all = 'all')
        each_locale(locale_or_all) do |locale|
          locale.migrate!
        end
      end

      def rollback(locale_or_all)
        each_locale(locale_or_all) do |locale|
          locale.update_info do |data, metadata|
            locale.rollback(data, metadata)
          end
        end
      end

      def pull(locale_or_all)
        each_locale(locale_or_all) do |locale|
          next if locale.main_locale?
          backend.pull(locale)
        end
      end

      def push(locale_or_all, force = false)
        backend.sync_migrations(new_migrations)
        each_locale(locale_or_all, concurrency: config.push_concurrency) do |locale|
          backend.push(locale, force: force)
          wait
        end
      end

      def new_locale(new_locale)
        locale_for(new_locale).create
      end

      def version
        each_locale do |locale|
          puts "#{locale.name}: #{locale.last_version}"
        end
      end

      def validate(locale_or_all)
        each_locale(locale_or_all, async: false) do |locale|
          next if locale.main_locale?
          locale.update_info do |data, metadata|
            locale.validate(data, metadata)
          end
        end
      end

      private def report_locale_on_error(locale, &block)
        begin
          block.call locale
        rescue
          puts "Error w/ '#{locale.name}': #{$!.message}"
          raise
        end
      end

      private def each_locale(name = 'all',
                              async: true,
                              concurrency: config.concurrency,
                              &block)
        locale_names = name == 'all' ? all_locale_names : [name]

        if async
          puts "Using #{concurrency} concurrency"
          locale_names.each_slice(concurrency) do |some_locale_names|
            threads = some_locale_names.map do |l|
              locale = locale_for(l)
              Thread.new { report_locale_on_error(locale, &block) }
            end
            threads.each(&:join)
          end
        else
          locale_names.each do |l|
            report_locale_on_error(locale_for(l), &block)
          end
        end
      end

      private def all_locale_names
        [config.main_locale] + config.other_locales
      end

      private def new_dictionary(locale)
        GoogleTranslateDictionary.new(from_locale: config.main_locale,
                                      to_locale: locale,
                                      key: config.google_translate_api_key,
                                      do_not_translate: config.main_locale == locale ? {} : config.do_not_translate(locale))
      end

      private def new_migrations
        MigrationFactory.new(config.migration_dir)
      end

      private def backend
        @backend ||= if config.crowd_translate?
                       Backends::CrowdTranslateBackend.new
                     else
                       Backends::GoogleSpreadsheetsBackend.new(config)
                     end
      end

      private def wait
        if config.wait_seconds > 0
          puts "Pausing #{config.wait_seconds}s to not run into Google Translate API throttling..."
          sleep config.wait_seconds
        end
      end
    end
  end
end
