require 'fileutils'
require 'yaml'
require 'active_support'
require 'colorize'

# this class does all the work, but doesn't hold config or do more than one locale
module I18n
  module Migrations
    class Locale
      attr_reader :name
      attr_reader :migrations

      def initialize(name, locales_dir:, main_locale_name:, migrations:, dictionary:)
        @name, @locales_dir, @main_locale_name, @migrations, @dictionary =
            name, locales_dir, main_locale_name, migrations, dictionary
      end

      def validate(data, notes)
        fix_count, error_count = 0, 0
        main_data = main_locale.read_data
        main_data.each do |key, main_term|
          old_term = data[key]
          new_term, errors = @dictionary.fix(main_term, old_term, key: key)
          if new_term != old_term
            data[key] = new_term
            puts "#{"Fix".green} #{key.green}:"
            puts "#{@main_locale_name}: #{main_term}"
            puts "#{@name} (old): #{old_term}"
            puts "#{@name} (new): #{new_term}"
            puts
            fix_count += 1
          end
          replace_errors_in_notes(notes, key, errors)
          if errors.length > 0
            puts "Error #{errors.join(', ').red} #{key.yellow}"
            puts "#{@main_locale_name.bold}: #{main_term}"
            puts "#{@name.bold}: #{old_term}"
            puts
            error_count += 1
          end
        end

        puts "#{name}: #{fix_count} Fixes" if fix_count > 0
        puts "#{name}: #{error_count} Errors" if error_count > 0
      end

      def update_info
        data, notes = read_data_and_notes
        yield data, notes
        write_data_and_notes(data, notes)
      end

      def migrate(data, notes)
        missing_versions = (@migrations.all_versions - read_versions(data)).sort
        if missing_versions.empty?
          puts "#{@name}: up-to-date"
          return
        end
        puts "#{@name}: Migrating #{missing_versions.join(', ')}"
        missing_versions.each do |version|
          migrate_to_version(data, notes, version, :up)
        end
      end

      def rollback(data, notes)
        last_version = read_versions(data).last
        if last_version == nil
          puts "#{@name}: no more migrations to roll back"
          return
        end
        puts "#{@name}: Rolling back #{last_version}"
        raise "Can't find #{last_version}.rb to rollback" unless @migrations.all_versions.include?(last_version)

        migrate_to_version(data, notes, last_version, :down)
      end

      def pull(sheet)
        puts "Pulling #{@name}"
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

        write_data_and_notes(data, notes)
        write_remote_version(data)

        puts "\n#{count} keys"
      end

      def pull_from_crowd_translate(client)
        data = client.get_locale_file(name)
        File.open(File.join(@locales_dir, "#{name}.yml"), 'w') do |file|
          file << data
        end
        write_remote_version(YAML::load(data)[name])
      end

      def push(sheet)
        main_data = main_locale.read_data
        data, notes = read_data_and_notes
        row = 2

        puts "Pushing #{@name}"

        main_data.each do |key, value|
          sheet[row, 1] = key
          sheet[row, 2] = value
          sheet[row, 3] = data[key]
          sheet[row, 4] = notes[key]
          row += 1
          print '.'
        end

        sheet.synchronize
        write_remote_version(data)

        puts "\n#{main_data.keys.length} keys"
      end

      def create(limit = nil)
        new_data, new_notes = {}, {}
        count = 0
        main_data = main_locale.read_data
        main_data.each do |key, term|
          if key == 'VERSION'
            new_data['VERSION'] = main_data['VERSION']
          else
            new_data[key], new_notes[key] = @dictionary.lookup(term, key: key)
          end
          print '.'.green
          break if limit && limit < (count += 1)
        end
        puts
        write_data_and_notes(new_data, new_notes)
      end

      def main_locale?
        @name == @main_locale_name
      end

      def last_version
        read_versions(read_data).last
      end

      def read_data
        read_from_file("#{@name}.yml")
      end

      private

      def main_locale
        Locale.new(@main_locale_name,
                   locales_dir: @locales_dir,
                   main_locale_name: @main_locale_name,
                   migrations: @migrations,
                   dictionary: nil) # should not use dictionary on main locale
      end

      def replace_errors_in_notes(all_notes, key, errors)
        return if all_notes[key].blank? && errors.empty?

        notes = all_notes[key]
        notes = notes.present? ? notes.split("\n") : []
        notes = notes.reject { |n| n.start_with?("[error:") }
        all_notes[key] = (errors.map { |e| "[error: #{e}]" } + notes).join("\n")
      end

      def read_data_and_notes
        data = read_data
        notes = main_locale? ? {} : read_from_file("../#{@name}_notes.yml")
        [data, notes]
      end

      def write_data_and_notes(data, notes)
        write_data(data)
        write_to_file("../#{@name}_notes.yml", notes) unless main_locale?
      end

      def write_data(data)
        write_to_file("#{@name}.yml", data)
      end

      def write_remote_version(data)
        write_to_file("../#{@name}_remote_version.yml",
                      { 'VERSION' => read_versions(data) })
      end

      def migrate_to_version(data, notes, version, direction)
        migrations.play_migration(version: version,
                                  locale: @name,
                                  data: data,
                                  notes: notes,
                                  dictionary: @dictionary,
                                  direction: direction)

        if direction == :up
          data['VERSION'] = (read_versions(data) + [version]).join("\n")
        else
          data['VERSION'] = (read_versions(data) - [version]).join("\n")
        end
      end

      def read_versions(data)
        (data['VERSION'] && data['VERSION'].split("\n")) || []
      end

      def read_from_file(filename)
        filename = File.join(@locales_dir, filename)
        begin
          hash = {}
          add_to_hash(hash, YAML.load(File.read(filename))[@name.to_s])
          hash
        rescue
          puts "Error loading #{filename}"
          raise
        end
      end

      def write_to_file(filename, hash)
        # we have to go from flat keys -> values to a hash that contains other hashes
        complex_hash = {}
        hash.keys.sort.each do |key|
          value = hash[key]
          assign_complex_key(complex_hash, key.split('.'), value.present? ? value : '')
        end
        File.open(File.join(@locales_dir, filename), 'w') do |file|
          file << { @name => complex_hash }.to_yaml
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
    end
  end
end
