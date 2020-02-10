require 'google_drive'

module I18n
  module Migrations
    module Backends
      class GoogleSpreadsheet
        attr_reader :sheet

        def initialize(locale, spreadsheet_url, key_path)
          @session = GoogleDrive::Session.from_service_account_key(key_path)

          url = spreadsheet_url || raise("Can't find google spreadsheet for #{locale}")
          @spreadsheet = @session.spreadsheet_by_url(url)
          @sheet = sheet_for("Sheet1")
        end

        def sheet_for(name)
          @spreadsheet.worksheet_by_title(name) || raise("couldn't find worksheet for #{name}")
        end
      end
    end
  end
end
