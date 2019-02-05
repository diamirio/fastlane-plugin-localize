require 'fastlane/action'
require_relative '../helper/google_sheet_localize_helper'

module Fastlane
  module Actions
    class GoogleSheetLocalizeAction < Action
      def self.run(params)

        UI.message("Using config file: #{params[:localize_credentials]}")

        session = Helper::GoogleSheetLocalizeHelper.setup(params[:localize_credentials])
        ##
        # Ensure valid credentials, either by restoring from the saved credentials
        # files or intitiating an OAuth2 authorization. If authorization is required,
        # the user's default browser will be launched to approve the request.
        #

        # Prints the names and majors of students in a sample spreadsheet:
        # https://docs.google.com/spreadsheets/d/1BxiMVs0XRA5nFMdKvBdBZjgmUUqptlbs74OgvE2upms/edit
        spreadsheet_id = params[:localize_sheet_id]
        spreadsheet_url = "https://docs.google.com/spreadsheets/d/#{spreadsheet_id}"

        range = 'Class Data!A2:E'
        spreadsheet = session.spreadsheet_by_url(spreadsheet_url)

        # Get the first worksheet
        worksheet = spreadsheet.worksheets.first

        languages = Helper::GoogleSheetLocalizeHelper.numberOfLanguages(worksheet)
        puts languages

        contentRows = worksheet.rows.drop(1)

        result = []
        for i in 2..1+languages
          title = worksheet.rows[0][i]

          language = {
            'language' => title,
            'items' => Helper::GoogleSheetLocalizeHelper.generateJSONObject(contentRows, i)
          }
          result.push(language)
        end

        puts result
        Helper::GoogleSheetLocalizeHelper.writeToJSONFile(result)
        Helper::GoogleSheetLocalizeHelper.createiOSFiles(result)
      end

      def self.description
        "Creates .strings files for iOS and strings.xml files for Android"
      end

      def self.authors
        ["Mario Hahn"]
      end

      def self.return_value
        # If your method provides a return value, you can describe here what it does
      end

      def self.details
        # Optional:
        "Creates .strings files for iOS and strings.xml files for Android. The localization is mananged on a google sheet."
      end

      def self.available_options
        [
           FastlaneCore::ConfigItem.new(key: :localize_sheet_id,
                                   env_name: "LOCALIZE_SHEET_ID",
                                description: "Your Google-spreadsheet id",
                                   optional: false,
                                       type: String),
           FastlaneCore::ConfigItem.new(key: :localize_credentials,
                                   env_name: "LOCALIZE_CREDENTIALS",
                                description: "Credentials Key path",
                                   optional: false,
                                       type: String)
        ]
      end

      def self.is_supported?(platform)
         [:ios, :mac, :android].include?(platform)
      end
    end
  end
end
