require 'fastlane/action'
require 'google_drive'

require_relative '../helper/google_sheet_localize_helper'

module Fastlane
  module Actions
    class GoogleSheetLocalizeAction < Action
      def self.run(params)

        session = ::GoogleDrive::Session.from_service_account_key(params[:service_account_path])
        spreadsheet_id = "https://docs.google.com/spreadsheets/d/#{params[:sheet_id]}"
        tabs = params[:tabs]
        platform = params[:platform]
        path = params[:localization_path]
        language_titles = params[:language_titles]
        default_language = params[:default_language]

        spreadsheet = session.spreadsheet_by_url(spreadsheet_id)
        worksheet = spreadsheet.worksheets.first

        result = []

        for i in 0..worksheet.max_cols

          title = worksheet.rows[0][i]

          if language_titles.include?(title)

            language = {
              'language' => title,
              'items' => []
            }

            filterdWorksheets = []

            if tabs.count == 0
              filterdWorksheets = spreadsheet.worksheets
            else
              filterdWorksheets = spreadsheet.worksheets.select { |item| tabs.include?(item.title) }
            end

            filterdWorksheets.each { |worksheet|
              contentRows = worksheet.rows.drop(1)
              language['items'].concat(self.generateJSONObject(contentRows, i))
            }

            result.push(language)
          end
        end
        self.createFiles(result, platform, path, default_language)
      end

      def self.generateJSONObject(contentRows, index)
          result = Array.new
          for i in 0..contentRows.count - 1
              item = self.generateSingleObject(contentRows[i], index)

              if item[:identifierIos] != "" && item[:identifierAndroid] != ""
                result.push(item)
              end
          end

          return result

      end

      def self.generateSingleObject(row, column)
        identifierIos = row[0]
        identifierAndroid = row[1]

        text = row[column]
        comment = row.last

        object = { 'identifierIos' => identifierIos,
                   'identifierAndroid' => identifierAndroid,
                   'text' => text,
                   'comment' => comment
        }

        return object

      end

      def filterUnusedRows(items, identifier)
        return items.select { |item|
            iosIdentifier = item[identifier]
            iosIdentifier != "NR" && iosIdentifier != ""
        }
      end

      def self.createFiles(languages, platform, destinationPath, defaultLanguage)
          self.createFilesForLanguages(languages, platform, destinationPath, defaultLanguage)

          if platform == "ios"

            swiftFilename = "Localization.swift"
            swiftFilepath = "#{destinationPath}/#{swiftFilename}"

            filteredItems = languages[0]["items"].select { |item|
                iosIdentifier = item['identifierIos']
                iosIdentifier != "NR" && iosIdentifier != "" && !iosIdentifier.include?('//')
            }

            File.open(swiftFilepath, "w") do |f|
              f.write("import Foundation\n\n\npublic struct Localization {\n")
              filteredItems.each { |item|

                identifier = item['identifierIos']

                values = identifier.dup.gsub('.', ' ').split(" ")

                constantName = ""

                values.each_with_index do |item, index|
                  if index == 0
                    constantName += item.downcase
                  else
                    constantName += item.capitalize
                  end
                end

                text = self.mapInvalidPlaceholder(item['text'])

                arguments = self.findArgumentsInText(text)

                if arguments.count == 0
                  f.write("\n\t///Sheet comment: #{item['comment']}\n\tpublic static let #{constantName} = localized(identifier: \"#{identifier}\")\n")
                else
                  f.write(self.createiOSFunction(constantName, identifier, arguments, item['comment']))
                end
              }
              f.write("\n}")
              f.write(self.createiOSFileEndString())
            end

          end
      end

      def self.createFilesForLanguages(languages, platform, destinationPath, defaultLanguage)

        languages.each { |language|

        if platform == "ios"

          filteredItems = self.filterUnusedRows(language["items"],'identifierIos')

          filename = "Localizable.strings"
          filepath = "#{destinationPath}/#{language['language']}.lproj/#{filename}"
          FileUtils.mkdir_p "#{destinationPath}/#{language['language']}.lproj"
          File.open(filepath, "w") do |f|
            filteredItems.each_with_index { |item, index|

              text = self.mapInvalidPlaceholder(item['text'])
              comment = item['comment']
              identifier = item['identifierIos']

              line = ""
              if identifier.include?('//')
                line = "\n\n#{identifier}\n"
              else

                if text == "" || text == "TBD"
                  default_language_object = languages.select { |languageItem| languageItem['language'] == defaultLanguage }.first["items"]
                  default_language_object = self.filterUnusedRows(default_language_object,'identifierIos')

                  defaultLanguageText = default_language_object[index]['text']
                  puts "found empty text for identifier: #{identifier} for language:#{language['language']}, replaceing it with #{defaultLanguageText}"
                  text = self.mapInvalidPlaceholder(defaultLanguageText)
                end

                line = "\"#{identifier}\" = \"#{text}\";"
              if !comment.to_s.empty?
                 line = line + " //#{comment}\n"
               else
                 line = line + "\n"
              end
              end

              f.write(line)
            }
          end
        end

        if platform == "android"
          languageDir = language['language']

          if languageDir == "en"
            languageDir = "values"
          else
            languageDir = "values-#{languageDir}"
          end

          FileUtils.mkdir_p "#{destinationPath}/#{languageDir}"
          File.open("#{destinationPath}/#{languageDir}/strings.xml", "w") do |f|
            f.write("<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n")
            f.write("<resources>\n")
            language["items"].each { |item|

              comment = item['comment']
              identifier = item['identifierAndroid']
              text = item['text']

              if !identifier.to_s.empty? && identifier != "NR"
                line = ""

                if !comment.to_s.empty?
                  line = line + "\t<!--#{comment}-->\n"
                end

                line = line + "\t<string name=\"#{identifier}\"><![CDATA[#{text}]]></string>\n"

                f.write(line)
              end
            }
            f.write("</resources>\n")
          end
        end
        }
      end

      def self.createiOSFileEndString()
        return "\n\nextension Localization {\n\tprivate static func localized(identifier key: String, _ args: CVarArg...) -> String {\n\t\tlet format = NSLocalizedString(key, tableName: nil, bundle: Bundle.main, comment: \"\")\n\n\t\tguard !args.isEmpty else { return format }\n\n\t\treturn String(format: format, locale: Locale.current, arguments: args)\n\t}\n}"
      end

      def self.createiOSFunction(constantName, identifier, arguments, comment)
          functionTitle = "\n\t///Sheet comment: #{comment}\n\tpublic static func #{constantName}("

          arguments.each_with_index do |item, index|
            puts item
            functionTitle = functionTitle + "_ arg#{index}: #{item[:type]}"
            if index < arguments.count - 1
              functionTitle = functionTitle + ", "
            else
              functionTitle = functionTitle + ") -> String {\n"
            end
          end
          functionTitle = functionTitle + "\t\treturn localized(identifier: \"#{identifier}\", "
          arguments.each_with_index do |item, index|
            functionTitle = functionTitle + "arg#{index}"
            if index < arguments.count - 1
              functionTitle = functionTitle + ", "
            else
              functionTitle = functionTitle + ")\n\t}"
            end
          end

          return functionTitle
      end

      def self.findArgumentsInText(text)
        result = Array.new
        filtered = self.mapInvalidPlaceholder(text)

        stringIndexes = (0 ... filtered.length).find_all { |i| filtered[i,2] == '%@' }
        intIndexes = (0 ... filtered.length).find_all { |i| filtered[i,2] == '%d' }
        floatIndexes = (0 ... filtered.length).find_all { |i| filtered[i,2] == '%f' }
        doubleIndexes = (0 ... filtered.length).find_all { |i| filtered[i,3] == '%ld' }

        if stringIndexes.count > 0
          result = result.concat(stringIndexes.map { |e| { "index": e, "type": "String" }})
        end

        if intIndexes.count > 0
          result = result.concat(intIndexes.map { |e| { "index": e, "type": "Int" }})
        end

        if floatIndexes.count > 0
          result = result.concat(floatIndexes.map { |e| { "index": e, "type": "Float" }})
        end

        if doubleIndexes.count > 0
          result = result.concat(doubleIndexes.map { |e| { "index": e, "type": "Double" }})
        end

        return result
      end

      def self.mapInvalidPlaceholder(text)
        filtered = text.gsub('%s', '%@').gsub('"', '\"')
        return filtered
      end

      def self.description
        "Creates .strings files for iOS and strings.xml files for Android"
      end

      def self.authors
        ["Mario Hahn", "Thomas Koller"]
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
          FastlaneCore::ConfigItem.new(key: :service_account_path,
                                  env_name: "SERVICE_ACCOUNT_PATH",
                               description: "Credentials path",
                                  optional: false,
                                      type: String),
           FastlaneCore::ConfigItem.new(key: :sheet_id,
                                   env_name: "SHEET_ID",
                                description: "Your Google-spreadsheet id",
                                   optional: false,
                                       type: String),
          FastlaneCore::ConfigItem.new(key: :platform,
                                  env_name: "PLATFORM",
                               description: "Plaform, ios or android",
                                  optional: true,
                             default_value: "ios",
                                      type: String),
          FastlaneCore::ConfigItem.new(key: :tabs,
                                  env_name: "TABS",
                               description: "Array of all Google Sheet Tabs",
                                  optional: false,
                                      type: Array),
          FastlaneCore::ConfigItem.new(key: :language_titles,
                                  env_name: "LANGUAGE_TITLES",
                               description: "Alle language titles",
                                  optional: false,
                                      type: Array),
          FastlaneCore::ConfigItem.new(key: :default_language,
                                  env_name: "DEFAULT_LANGUAGE",
                               description: "Default Language",
                                  optional: false,
                                      type: String),
          FastlaneCore::ConfigItem.new(key: :localization_path,
                                  env_name: "LOCALIZATION_PATH",
                               description: "Output path",
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
