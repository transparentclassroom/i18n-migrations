require_relative './google_spreadsheet'

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

        def push(locale, force = false)
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

        def pull_from_sheet(sheet, locale)
          puts "Pulling #{locale.name}"
          data = {}
          notes = {}
          count = 0

          (2..sheet.num_rows).each do |row|
            key, value, note = sheet[row, 1], sheet[row, 3], sheet[row, 4]
            if key.present?
              locale.assign_complex_key(data, key.split('.'), value.present? ? value : '')
              if note.present?
                locale.assign_complex_key(notes, key.split('.'), note)
              end
              count += 1
              print '.'
            end
          end

          locale.write_data_and_notes(data, notes)
          locale.write_remote_version(data)

          puts "\n#{count} keys"
        end

        def push_to_sheet(sheet, locale)
          main_data = locale.main_locale.read_data
          data, notes = locale.read_data_and_notes
          row = 2

          puts "Pushing #{locale.name}"

          main_data.each do |key, value|
            sheet[row, 1] = key
            sheet[row, 2] = value
            sheet[row, 3] = data[key]
            sheet[row, 4] = notes[key]
            row += 1
            print '.'
          end

          sheet.synchronize
          locale.write_remote_version(data)

          puts "\n#{main_data.keys.length} keys"
        end
      end
    end
  end
end
