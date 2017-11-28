require 'fileutils'
require 'yaml'
require 'active_support/inflector'
require 'active_support/core_ext/object'
require 'colorize'

$LOAD_PATH.unshift(File.dirname(__FILE__))
require 'google_translate_dictionary'
require 'google_spreadsheet'
require 'config'

module I18n
  module Migrations
    class Migrator
      def config
        @config ||= Config.new.read!
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
          update_locale_info(locale) do |data, notes|
            migrate_locale(locale, data, notes)
          end
        end
      end

      def rollback(locale_or_all)
        each_locale(locale_or_all) do |locale|
          update_locale_info(locale) do |data, notes|
            rollback_locale(locale, data, notes)
          end
        end
      end

      def pull(locale_or_all)
        each_locale(locale_or_all) do |locale|
          next if locale == config.main_locale
          sheet = get_google_spreadsheet(locale)
          pull_locale(locale, sheet)
          migrate(locale)
        end
      end

      def push(locale_or_all, force = false)
        each_locale(locale_or_all) do |locale|
          next if locale == config.main_locale
          sheet = get_google_spreadsheet(locale)
          unless force
            pull_locale(locale, sheet)
            migrate(locale)
          end
          push_locale(locale, sheet)
        end
      end

      def new_locale(new_locale, limit = nil)
        dictionary = new_dictionary(new_locale)
        new_data, new_notes = {}, {}
        count = 0
        main_data = read_locale_data(config.main_locale)
        main_data.each do |key, term|
          new_data[key], new_notes[key] = dictionary.lookup(term)
          print '.'.green
          break if limit && limit < count += 1
        end
        new_data['VERSION'] = main_data['VERSION']
        puts
        write_locale_data_and_notes(new_locale, new_data, new_notes)
      end

      def version
        each_locale do |locale|
          puts "#{locale}: #{locale_versions(read_locale_data(locale)).last}"
        end
      end

      def validate(locale_or_all)
        each_locale(locale_or_all) do |locale|
          next if locale == config.main_locale
          update_locale_info(locale) do |data, notes|
            validate_locale(locale, data, notes)
          end
        end
      end

      private

      def validate_locale(locale, data, notes)
        main_data = read_locale_data(config.main_locale)
        dict = new_dictionary(locale)
        main_data.each do |key, main_term|
          old_term = data[key]
          new_term, errors = dict.fix(main_term, old_term)
          if new_term != old_term
            data[key] = new_term
            puts "#{"Fix".green} #{key.green}:"
            puts "#{config.main_locale}: #{main_term}"
            puts "#{locale} (old): #{old_term}"
            puts "#{locale} (new): #{new_term}"
          end
          replace_errors_in_notes(notes, key, errors)
          if errors.length > 0
            puts "Error #{errors.join(', ')} #{key}"
            puts "#{config.main_locale}: #{main_term}"
            puts "#{locale}: #{old_term}"
          end
        end
      end

      def replace_errors_in_notes(all_notes, key, errors)
        return if all_notes[key].blank? && errors.empty?

        notes = all_notes[key]
        notes = notes.present? ? notes.split("\n") : []
        notes = notes.reject { |n| n.start_with?("[error:") }
        all_notes[key] = (errors.map{|e| "[error: #{e}]"} + notes).join("\n")
      end

      def update_locale_info(locale)
        data, notes = read_locale_data_and_notes(locale)
        yield data, notes
        write_locale_data_and_notes(locale, data, notes)
      end

      def read_locale_data_and_notes(locale)
        data = read_locale_data(locale)
        notes = locale == config.main_locale ? {} : read_locale_from_file(locale, "../#{locale}_notes.yml")
        [data, notes]
      end

      def read_locale_data(locale)
        read_locale_from_file(locale, "#{locale}.yml")
      end

      def write_locale_data_and_notes(locale, data, notes)
        write_locale_to_file(locale, "#{locale}.yml", data)
        write_locale_to_file(locale, "../#{locale}_notes.yml", notes) unless locale == config.main_locale
      end

      def pull_locale(locale, sheet)
        puts "Pulling #{locale}"
        data = {}
        notes = {}
        count = 0

        (2..sheet.num_rows).each do |row|
          key, value, note = sheet[row, 1], sheet[row, 3], sheet[row, 4]
          if key.present?
            assign_complex_key(data, key.split('.'), value.present? ? value : '')
            if note.present?
              assign_complex_key(notes, key.split('.'), note)
            end
            count += 1
            print '.'
          end
        end

        write_locale_data_and_notes(locale, data, notes)
        write_locale_remote_version(locale, data)

        puts "\n#{count} keys"
      end

      def write_locale_remote_version(locale, data)
        write_locale_to_file(locale,
                             "../#{locale}_remote_version.yml",
                             { 'VERSION' => locale_versions(data) })
      end

      def push_locale(locale, sheet)
        main_data = read_locale_data(config.main_locale)
        data, notes = read_locale_data_and_notes(locale)
        row = 2

        puts "Pushing #{locale}"

        main_data.each do |key, value|
          sheet[row, 1] = key
          sheet[row, 2] = value
          sheet[row, 3] = data[key]
          sheet[row, 4] = notes[key]
          row += 1
          print '.'
        end

        sheet.synchronize
        write_locale_remote_version(locale, data)

        puts "\n#{main_data.keys.length} keys"
      end

      def migrate_locale(locale, data, notes)
        missing_versions = (all_versions - locale_versions(data)).sort
        if missing_versions.empty?
          puts "#{locale}: up-to-date"
          return
        end
        puts "#{locale}: Migrating #{missing_versions.join(', ')}"
        missing_versions.each do |version|
          migrate_locale_to_version(locale, data, notes, version, :up)
        end
      end

      def rollback_locale(locale, data, notes)
        last_version = locale_versions(data).last
        if last_version == nil
          puts "#{locale}: no more migrations to roll back"
          return
        end
        puts "#{locale}: Rolling back #{last_version}"
        raise "Can't find #{last_version}.rb to rollback" unless all_versions.include?(last_version)

        migrate_locale_to_version(locale, data, notes, last_version, :down)
      end

      def migrate_locale_to_version(locale, data, notes, version, direction)
        filename = File.join(config.migration_dir, "#{version}.rb")
        require filename
        migration_class_name = version.gsub(/^\d{12}_/, '').camelcase
        dictionary = new_dictionary(locale)

        migration = begin
          migration_class_name.constantize.new(locale, data, notes, dictionary, direction)
        rescue
          raise "Couldn't load migration #{migration_class_name} in #{filename}"
        end

        migration.change

        if direction == :up
          data['VERSION'] = (locale_versions(data) + [version]).join("\n")
        else
          data['VERSION'] = (locale_versions(data) - [version]).join("\n")
        end
      end

      def locale_versions(data)
        (data['VERSION'] && data['VERSION'].split("\n")) || []
      end

      def read_locale_from_file(locale, filename)
        filename = File.join(config.locales_dir, filename)
        begin
          hash = {}
          add_to_hash(hash, YAML.load(File.read(filename))[locale.to_s])
          hash
        rescue
          puts "Error loading #{filename}"
          raise
        end
      end

      def write_locale_to_file(locale, filename, hash)
        # we have to go from flat keys -> values to a hash that contains other hashes
        complex_hash = {}
        hash.keys.sort.each do |key|
          value = hash[key]
          assign_complex_key(complex_hash, key.split('.'), value.present? ? value : '')
        end
        File.open(File.join(config.locales_dir, filename), 'w') do |file|
          file << { locale => complex_hash }.to_yaml
        end
      end

      def assign_complex_key(hash, key, value)
        if key.length == 0
          # should never get here
        elsif key.length == 1
          hash[key[0]] = value
        else
          hash[key[0]] ||= {}
          assign_complex_key(hash[key[0]], key[1..-1], value)
        end
      end

      # flattens new_hash and adds it to hash
      def add_to_hash(hash, new_hash, prefix = [])
        return unless new_hash

        new_hash.each do |key, value|
          if value.is_a?(Hash)
            add_to_hash(hash, value, prefix + [key])
          else
            hash[(prefix + [key]).join('.')] = value
          end
        end
      end

      def each_locale(locale = 'all')
        (locale == 'all' ? all_locales : [locale]).each do |l|
          yield l
        end
      end

      def all_locales
        [config.main_locale] + config.other_locales
      end

      def all_versions
        Dir[config.migration_dir + '/*.rb'].map { |name| File.basename(name).gsub('.rb', '') }
      end

      def new_dictionary(locale)
        GoogleTranslateDictionary.new(config.main_locale, locale, config.google_translate_api_key, config.do_not_translate)
      end

      def get_google_spreadsheet(locale)
        GoogleSpreadsheet.new(locale,
                              config.google_spreadsheets[locale],
                              config.google_service_account_key_path).sheet
      end
    end
  end
end
