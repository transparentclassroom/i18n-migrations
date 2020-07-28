require 'fileutils'
require 'yaml'
require 'active_support'
require 'colorize'
require 'active_support/core_ext/object'
require_relative './metadata'

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

      def validate(data, metadata)
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
          metadata[key].errors = errors
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
        data, metadata = read_data_and_metadata
        yield data, metadata
        write_data_and_metadata(data, metadata)
      end

      def migrate!
        update_info do |data, metadata|
          migrate(data, metadata)
        end
      end

      def migrate(data, metadata)
        missing_versions = (@migrations.all_versions - read_versions(data)).sort
        if missing_versions.empty?
          puts "#{@name}: up-to-date"
          return
        end
        puts "#{@name}: Migrating #{missing_versions.join(', ')}"
        missing_versions.each do |version|
          migrate_to_version(data, metadata, version, :up)
        end
      end

      def rollback(data, metadata)
        last_version = read_versions(data).last
        if last_version == nil
          puts "#{@name}: no more migrations to roll back"
          return
        end
        puts "#{@name}: Rolling back #{last_version}"
        raise "Can't find #{last_version}.rb to rollback" unless @migrations.all_versions.include?(last_version)

        migrate_to_version(data, metadata, last_version, :down)
      end

      def create(limit = nil)
        new_data, new_metadata = {}, Metadata.new
        count = 0
        main_data = main_locale.read_data
        main_data.each do |key, term|
          if key == 'VERSION'
            new_data['VERSION'] = main_data['VERSION']
          else
            new_data[key], errors = @dictionary.lookup(term, key: key)
            new_metadata[key].errors = errors
          end
          print '.'.green
          break if limit && limit < (count += 1)
        end
        puts
        write_data_and_metadata(new_data, new_metadata)
      end

      def main_locale?
        @name == @main_locale_name
      end

      def last_version
        read_versions(read_data).last
      end

      def read_data(parse: true)
        contents = data_file.read
        return contents unless parse

        hash = {}
        add_to_hash(hash, parse_yaml(contents)[@name.to_s])
        hash
      end

      def read_data_and_metadata(parse: true)
        data = read_data(parse: parse)
        metadata = read_metadata(parse: parse)
        [data, metadata]
      end

      def write_data_and_metadata(data, metadata)
        write_data(data)
        write_metadata(metadata)
      end

      def write_remote_version(data)
        remote_version_file.write({ 'VERSION' => read_versions(data) }.to_yaml)
      end

      def main_locale
        Locale.new(@main_locale_name,
                   locales_dir: @locales_dir,
                   main_locale_name: @main_locale_name,
                   migrations: @migrations,
                   dictionary: nil) # should not use dictionary on main locale
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

      def data_file
        file("#{name}.yml")
      end

      def metadata_file
        file("../#{name}_metadata.yml")
      end

      def remote_version_file
        file("../#{@name}_remote_version.yml")
      end

      private

      def write_data(data)
        # we have to go from flat keys -> values to a hash that contains other hashes
        complex_hash = {}
        data.keys.sort.each do |key|
          value = data[key]
          assign_complex_key(complex_hash, key.split('.'), value.present? ? value : '')
        end
        data_file.write({ @name => complex_hash }.to_yaml)
      end

      def read_metadata(parse: true)
        contents = if metadata_file.exist?
                     metadata_file.read
                   else
                     {}.to_yaml
                   end
        parse ? Metadata.new(parse_yaml(contents)) : contents
      end

      def write_metadata(metadata)
        metadata_file.write(metadata.to_yaml)
      end

      def migrate_to_version(data, metadata, version, direction)
        migrations.play_migration(version: version,
                                  locale: @name,
                                  data: data,
                                  metadata: metadata,
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

      def file(filename)
        Pathname.new(File.join(@locales_dir, filename))
      end

      def parse_yaml(string)
        YAML.load(string) || {}
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
