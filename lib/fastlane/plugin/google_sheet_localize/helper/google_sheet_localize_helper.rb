# frozen_string_literal: true

require 'fastlane_core/ui/ui'
require 'googleauth'
require 'google/apis/sheets_v4'

module Fastlane
  UI = FastlaneCore::UI unless Fastlane.const_defined?('UI')

  module Helper
    # Thin wrapper around the Google Sheets API v4.
    class GoogleSheetLocalizeHelper
      SCOPE = 'https://www.googleapis.com/auth/spreadsheets.readonly'

      # Rows of a single tab. Every row is padded to the same width (like the
      # old google_drive gem did), because the Sheets API drops trailing empty cells.
      Worksheet = Struct.new(:title, :rows) do
        def max_cols
          rows.map(&:count).max.to_i
        end
      end

      def initialize(service_account_path, spreadsheet_id)
        @spreadsheet_id = spreadsheet_id
        @service = Google::Apis::SheetsV4::SheetsService.new
        @service.authorization = File.open(service_account_path) do |file|
          Google::Auth::ServiceAccountCredentials.make_creds(json_key_io: file, scope: SCOPE)
        end
      end

      def worksheet_titles
        spreadsheet = @service.get_spreadsheet(@spreadsheet_id, fields: 'sheets.properties.title')
        spreadsheet.sheets.map { |sheet| sheet.properties.title }
      end

      def worksheet(title)
        range = "'#{title.gsub("'", "''")}'"
        values = @service.get_spreadsheet_values(@spreadsheet_id, range).values || []
        width = values.map(&:count).max.to_i
        rows = values.map { |row| row.map(&:to_s) + Array.new(width - row.count, '') }
        Worksheet.new(title, rows)
      end
    end
  end
end
