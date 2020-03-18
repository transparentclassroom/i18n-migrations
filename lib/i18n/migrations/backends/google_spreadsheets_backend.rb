require_relative './google_spreadsheet'
require_relative '../metadata'

module I18n
  module Migrations
    module Backends
      class GoogleSpreadsheetsBackend
        def initialize(config)
          @config = config
        end

        def pull(locale)
          return if locale.main_locale?

          sheet = get_google_spreadsheet(locale.name)
          pull_from_sheet(sheet, locale)
          locale.migrate!
        end

        def push(locale, force: false)
          return if locale.main_locale?

          sheet = get_google_spreadsheet(locale.name)
          unless force
            pull_from_sheet(sheet, locale)
            locale.migrate!
          end
          push_to_sheet(sheet, locale)
        end

        private def get_google_spreadsheet(locale)
          GoogleSpreadsheet.new(locale,
                                @config.google_spreadsheet(locale),
                                @config.google_service_account_key_path).sheet
        end

        def sync_migrations(migrations)
          # nothing to do here in this backend
        end

        def pull_from_sheet(sheet, locale)
          puts "Pulling #{locale.name}"
          data = {}
          metadata = Metadata.new
          count = 0

          (2..sheet.num_rows).each do |row|
            key, value, note = sheet[row, 1], sheet[row, 3], sheet[row, 4]
            if key.present?
              locale.assign_complex_key(data, key.split('.'), value.present? ? value : '')
              if note.present?
                metadata[key] = parse_metadatum(note)
              end
              count += 1
              #print '.'
            end
          end

          locale.write_data_and_metadata(data, metadata)
          locale.write_remote_version(data)

          puts "\n#{count} keys"
        end

        def push_to_sheet(sheet, locale)
          main_data = locale.main_locale.read_data
          data, metadata = locale.read_data_and_metadata
          row = 2

          puts "Pushing #{locale.name}"

          main_data.each do |key, value|
            sheet[row, 1] = key
            sheet[row, 2] = value
            sheet[row, 3] = data[key]
            sheet[row, 4] = unparse_metadatum(metadata[key])
            row += 1
            #print '.'
          end

          sheet.synchronize
          locale.write_remote_version(data)

          puts "\n#{main_data.keys.length} keys"
        end

        def parse_metadatum(text)
          m = Metadata::Metadatum.new({})
          m.notes = text.gsub("[autotranslated]") do
            m.autotranslated = true
            ''
          end.gsub(/\[error: ([^\]]+)\]/) do
            m.errors << $1
            ''
          end.strip
          m
        end

        def unparse_metadatum(metadatum)
          string = []
          string << '[autotranslated]' if metadatum.autotranslated
          metadatum.errors.each do |error|
            string << "[error: #{error}]"
          end
          string << metadatum.notes unless metadatum.notes.blank?
          string.join("\n")
        end
      end
    end
  end
end
