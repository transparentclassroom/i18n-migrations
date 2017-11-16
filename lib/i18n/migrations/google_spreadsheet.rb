require 'google_drive'
require 'config'

module I18n
  module Migrations
    class GoogleSpreadsheet
      attr_reader :sheet

      def initialize(locale)
        @session = GoogleDrive::Session.from_service_account_key(Config.google_service_account_key_path)

        url = Config.google_spreadsheets[locale] || raise("Can't find google spreadsheet for #{locale}")
        @spreadsheet = @session.spreadsheet_by_url(url)
        @sheet = sheet_for("Sheet1")
      end

      def sheet_for(name)
        @spreadsheet.worksheet_by_title(name) || raise("couldn't find worksheet for #{name}")
      end
    end
  end
end
