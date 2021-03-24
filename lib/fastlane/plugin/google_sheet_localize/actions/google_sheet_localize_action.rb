require 'fastlane/action'
require 'google_drive'
require 'json'

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
        base_language = params[:base_language]
        code_generation_path = params[:code_generation_path]
        identifier_name = params[:identifier_name]
        comment_example_language = params[:comment_example_language]
        support_objc = params[:support_objc]
        support_spm = params[:support_spm]

        if identifier_name.to_s.empty?
          if platform == "ios"
            identifier_name = "Identifier iOS"
          end
          if platform == "android"
            identifier_name = "Identifier Android"
          end
          if platform == "web"
            identifier_name = "Identifier Web"
          end
        end

        if comment_example_language.to_s.empty?
          comment_example_language = default_language
        end

        spreadsheet = session.spreadsheet_by_url(spreadsheet_id)

        filterdWorksheets = []

        if tabs.count == 0
          filterdWorksheets = spreadsheet.worksheets
        else
          filterdWorksheets = spreadsheet.worksheets.select { |item| tabs.include?(item.title) }
        end

        result = []
        
        filterdWorksheets.each { |worksheet|

          identifierIndex = 0

          for i in 0..worksheet.max_cols
            if worksheet.rows[0][i] == identifier_name
              identifierIndex = i
            end
          end

          for i in 0..worksheet.max_cols

            title = worksheet.rows[0][i]

            if language_titles.include?(title)

              language = result.select { |item| item['language'] == title }.first

              if language.nil?
                language = {
                  'language' => title,
                  'items' => []
                }
              end

              contentRows = worksheet.rows.drop(1)

              items = language['items']
              items = items + self.generateJSONObject(contentRows, i, identifierIndex)

              language['items'] = items

              result.push(language)
            end
          end
      }
      self.createFiles(result, platform, path, default_language, base_language, code_generation_path, comment_example_language, support_objc, support_spm)
      end

      def self.generateJSONObject(contentRows, index, identifierIndex)
          result = Array.new
          for i in 0..contentRows.count - 1
              item = self.generateSingleObject(contentRows[i], index, identifierIndex)

              if item[:identifier] != ""
                result.push(item)
              end
          end

          return result

      end

      def self.generateSingleObject(row, column, identifierIndex)
        identifier = row[identifierIndex]

        text = row[column]
        comment = row.last

        object = { 'identifier' => identifier,
                   'text' => text,
                   'comment' => comment
        }
        return object

      end

      def self.filterUnusedRows(items, identifier, filterComment)
        filtered = items.select { |item|
            currentIdentifier = item[identifier]
            currentIdentifier != "NR" && currentIdentifier != "" && currentIdentifier != "TBD"
        }
        
        if filterComment == "false" 
           return filtered
        end

        return filtered.select { |item|
            !item[identifier].include?('//')
        }
      end

      def self.createFiles(languages, platform, destinationPath, defaultLanguage, base_language, codeGenerationPath, comment_example_language, support_objc, support_spm)
          self.createFilesForLanguages(languages, platform, destinationPath, defaultLanguage, base_language)

          if platform == "web"
            jsonFileName = "Localization.json"

            jsonFilepath = "#{destinationPath}/#{jsonFileName}"

            File.open(jsonFilepath, "w") do |f|

              jsonItem = {}

              languages.each { |language|
                filteredItems = self.filterUnusedRows(language["items"],'identifier', "true")

                allKeys = {}

                filteredItems.each { |item|
                  identifier = item['identifier']

                  text = item['text']

                  matches = text.scan(/%[0-9][sdf]/)
                  matches.each { |match|
                    text = text.gsub(match, "{#{match[1]}}")
                  }

                  if !identifier.include?('//')
                    allKeys[identifier] = text
                  end
                }
                jsonItem[language["language"]] = allKeys
              }

              jsonString = JSON.pretty_generate(jsonItem)
              f.write(jsonString)
            end
          end

          if platform == "ios"

            swiftFilename = "Localization.swift"

            swiftPath = codeGenerationPath

            if codeGenerationPath.to_s.empty?
              swiftPath = destinationPath
            end

            languageItems = languages.select { |item| item["language"] == comment_example_language }.first

            filteredItems = self.filterUnusedRows(languageItems["items"],'identifier', "true")

            swiftFilepath = "#{swiftPath}/#{swiftFilename}"

            File.open(swiftFilepath, "w") do |f|
              f.write("import Foundation\n\n// swiftlint:disable all\n#{getiOSTypeDefinition(support_objc)} {\n")
              filteredItems.each { |item|

                identifier = item['identifier']

                values = identifier.dup.split(/\.|_/)

                constantName = ""

                values.each_with_index do |item, index|
                  if index == 0
                    item[0] = item[0].downcase
                    constantName += item
                  else
                    item[0] = item[0].upcase
                    constantName += item
                  end
                end

                if constantName == "continue"
                  constantName = "`continue`"
                end

                if constantName == "switch"
                  constantName = "`switch`"
                end

                text = self.mapInvalidPlaceholder(item['text'])

                arguments = self.findArgumentsInText(text)

                if arguments.count == 0
                  f.write(self.createComment(item['comment'], item['text']))
                  f.write("#{getiOSAttributes(support_objc)}public static let #{constantName} = localized(identifier: \"#{identifier}\")\n")
                else
                  f.write(self.createComment(item['comment'], item['text']))
                  f.write(self.createiOSFunction(constantName, identifier, arguments, support_objc))
                end
              }
              f.write("\n}")
              f.write(self.createiOSFileEndString(destinationPath, support_spm))
            end

          end
      end

      def self.createComment(comment, example) 

        if comment.to_s.empty?
          return %Q(
    /**
    #{example}
    */
    )
        end

      return %Q(
    /**
    #{example}
    
    - Sheet comment:
    ````
    #{comment}
    ````
    */
    )
      end

      def self.createFilesForLanguages(languages, platform, destinationPath, defaultLanguage, base_language)

        languages.each { |language|

        if platform == "ios"

          filteredItems = self.filterUnusedRows(language["items"],'identifier', "false")

          stringFileName = "Localizable.strings"
          pluralsFileName = "Localizable.stringsdict"

          languageName = language['language']

          if languageName == base_language
            languageName = "Base"
          end

          stringFilepath = "#{destinationPath}/#{languageName}.lproj/#{stringFileName}"
          pluralsFilepath = "#{destinationPath}/#{languageName}.lproj/#{pluralsFileName}"
          FileUtils.mkdir_p "#{destinationPath}/#{languageName}.lproj"

          File.open(stringFilepath, "w") do |f|
            filteredItems.each_with_index { |item, index|

              text = self.mapInvalidPlaceholder(item['text'])
              comment = item['comment']
              identifier = item['identifier']

              line = ""
              if identifier.include?('//')
                line = "\n\n#{identifier}\n"
              else


                  if (text == "" || text == "TBD") && !defaultLanguage.to_s.empty?
                    default_language_object = languages.select { |languageItem| languageItem['language'] == defaultLanguage }.first["items"]
                    default_language_object = self.filterUnusedRows(default_language_object,'identifier', "false")

                    defaultLanguageText = default_language_object[index]['text']
                    puts "found empty text for:\n\tidentifier: #{identifier}\n\tlanguage:#{language['language']}\n\treplacing it with: #{defaultLanguageText}"
                    text = self.mapInvalidPlaceholder(defaultLanguageText)
                  end

                  if !text.include?("one|")

                  matches = text.scan(/%[0-9][sdf]/)

                  matches.each { |match|
                    text = text.gsub(match, "%#{match[1]}$#{match[2].gsub("s","@")}")
                  }

                  line = "\"#{identifier}\" = \"#{text}\";"
                  if !comment.to_s.empty?
                    line = line + " //#{comment}\n"
                  else
                    line = line + "\n"
                  end
                end
              end
              f.write(line)
            }
          end

          File.open(pluralsFilepath, "w") do |f|

            f.write("<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n")
            f.write("<!DOCTYPE plist PUBLIC \"-//Apple//DTD PLIST 1.0//EN\" \"http://www.apple.com/DTDs/PropertyList-1.0.dtd\">\n")
            f.write("<plist version=\"1.0\">\n")
            f.write("<dict>\n")

            filteredItems.each_with_index { |item, index|

              text = self.mapInvalidPlaceholder(item['text'])
              identifier = item['identifier']

                if (text == "" || text == "TBD") && !defaultLanguage.to_s.empty?
                  default_language_object = languages.select { |languageItem| languageItem['language'] == defaultLanguage }.first["items"]
                  default_language_object = self.filterUnusedRows(default_language_object,'identifier', "false")

                  defaultLanguageText = default_language_object[index]['text']
                  puts "found empty text for:\n\tidentifier: #{identifier}\n\tlanguage:#{language['language']}\n\treplacing it with: #{defaultLanguageText}"
                  text = self.mapInvalidPlaceholder(defaultLanguageText)
                end

                if !identifier.include?('//') && text.include?("one|")

                text = text.gsub("\n", "|")

                formatIdentifier = identifier.gsub(".", "")

                f.write("\t\t<key>#{identifier}</key>\n")
                f.write("\t\t<dict>\n")
                f.write("\t\t\t<key>NSStringLocalizedFormatKey</key>\n")
                f.write("\t\t\t<string>%#@#{formatIdentifier}@</string>\n")
                f.write("\t\t\t<key>#{formatIdentifier}</key>\n")
                f.write("\t\t\t<dict>\n")
                f.write("\t\t\t\t<key>NSStringFormatSpecTypeKey</key>\n")
                f.write("\t\t\t\t<string>NSStringPluralRuleType</string>\n")
                f.write("\t\t\t\t<key>NSStringFormatValueTypeKey</key>\n")
                f.write("\t\t\t\t<string>d</string>\n")

                text.split("|").each_with_index { |word, wordIndex|
                  if wordIndex % 2 == 0
                    f.write("\t\t\t\t<key>#{word}</key>\n")
                  else
                    f.write("\t\t\t\t<string>#{word}</string>\n")
                  end
                }
                f.write("\t\t\t</dict>\n")
                f.write("\t\t</dict>\n")
              end
            }
            f.write("</dict>\n")
            f.write("</plist>\n")
          end
        end

        if platform == "android"
          languageDir = language['language']

          if languageDir == base_language
            languageDir = "values"
          else
            languageDir = "values-#{languageDir}"
          end

          FileUtils.mkdir_p "#{destinationPath}/#{languageDir}"
          File.open("#{destinationPath}/#{languageDir}/strings.xml", "w") do |f|
            f.write("<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n")
            f.write("<resources>\n")

            filteredItems = self.filterUnusedRows(language["items"],'identifier', "false")

            filteredItems.each_with_index { |item, index|

              comment = item['comment']
              identifier = item['identifier']
              text = item['text']

              line = ""

              if !comment.to_s.empty?
                line = line + "    <!--#{comment}-->\n"
              end

              if (text == "" || text == "TBD") && !defaultLanguage.to_s.empty?
                default_language_object = languages.select { |languageItem| languageItem['language'] == defaultLanguage }.first["items"]
                default_language_object = self.filterUnusedRows(default_language_object,'identifier', "false")

                defaultLanguageText = default_language_object[index]['text']
                puts "found empty text for:\n\tidentifier: #{identifier}\n\tlanguage:#{language['language']}\n\treplacing it with: #{defaultLanguageText}"
                text = defaultLanguageText
              end

              text = text.gsub(/\\?'/, "\\\\'")

              if text.include?("one|")

                text = text.gsub("\n", "|")

                line = line + "    <plurals name=\"#{identifier}\">\n"

                plural = ""

                text.split("|").each_with_index { |word, wordIndex|
                  if wordIndex % 2 == 0
                    plural = "        <item quantity=\"#{word}\">"
                  else
                    plural = plural + "<![CDATA[#{word}]]></item>\n"
                    line = line + plural
                  end
                }
                line = line + "    </plurals>\n"
              elsif text.start_with?("[\"") && text.end_with?("\"]")

                line = line + "    <string-array name=\"#{identifier}\">\n"

                JSON.parse(text).each { |arrayItem|

                  arrayItem = arrayItem.gsub("'", "\\\\'")

                  line = line + "        <item><![CDATA[#{arrayItem}]]></item>\n"
                }

                line = line + "    </string-array>\n"
              else
                line = line + "    <string name=\"#{identifier}\"><![CDATA[#{text}]]></string>\n"
              end

              f.write(line)
            }
            f.write("</resources>\n")
          end
        end
        }
      end

      def self.createiOSFileEndString(destinationPath, support_spm)

        bundle = support_spm ? "let bundle = Bundle.module" : "let bundle = Bundle(for: LocalizationHelper.self)"

        puts destinationPath

        if destinationPath.include?(".bundle")

          bundle = %Q(let bundleUrl = Bundle(for: LocalizationHelper.self).url(forResource: "#{destinationPath.split('/').last.gsub(".bundle", "")}", withExtension: "bundle")
        \n\t\tlet bundle = Bundle(url: bundleUrl!)!)
        end

        return %Q(
        \n\nprivate class LocalizationHelper { }
        \n\nextension Localization {
        \n\tprivate static func localized(identifier key: String, _ args: CVarArg...) -> String {
        \n\t\t#{bundle}
        \n\t\tlet format = NSLocalizedString(key, tableName: nil, bundle: bundle, comment: \"\")
        \n\t\tguard !args.isEmpty else { return format }
        \n\t\treturn String(format: format, locale: .current, arguments: args)
        \n\t}
        \n})
      end

      def self.createiOSFunction(constantName, identifier, arguments, support_objc)
          functionTitle = "#{getiOSAttributes(support_objc)}public static func #{constantName}("

          arguments.each_with_index do |item, index|
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

      def self.getiOSTypeDefinition(support_objc)
        return support_objc ? "public class Localization: NSObject" : "public struct Localization"
      end

      def self.getiOSAttributes(support_objc)
        return support_objc ? "@objc " : ""
      end

      def self.findArgumentsInText(text)

        if text.include?("one|")
          text = text.dup.split("|")[1]
        end

        result = Array.new
        filtered = self.mapInvalidPlaceholder(text)

        stringIndexes = self.scan_str(filtered, /%[0-9]?[s@]/)
        intIndexes = self.scan_str(filtered, /%[0-9]?[d]/)
        floatIndexes = self.scan_str(filtered, /%[0-9]?[.f]/)
        doubleIndexes = self.scan_str(filtered, /%[0-9]?ld/)

        if stringIndexes.count > 0
          result = result + stringIndexes.map { |e| { "index": e[0], "offset": e[1], "type": "String" }}
        end

        if intIndexes.count > 0
          result = result + intIndexes.map { |e| { "index": e[0], "offset": e[1], "type": "Int" }}
        end

        if floatIndexes.count > 0
          result = result + floatIndexes.map { |e| { "index": e[0], "offset": e[1], "type": "Float" }}
        end

        if doubleIndexes.count > 0
          result = result + doubleIndexes.map { |e| { "index": e[0], "offset": e[1], "type": "Double" }}
        end

        result = result.sort_by { |hsh| hsh[:offset] }

        return result
      end

      def self.scan_str(str, pattern)
        res = []
        (0..str.length).each do |i|
          res << [Regexp.last_match.to_s, i] if str[i..-1] =~ /^#{pattern}/
        end
        res
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
                               description: "Platform, ios or android",
                                  optional: true,
                             default_value: Actions.lane_context[Actions::SharedValues::PLATFORM_NAME].to_s,
                     default_value_dynamic: true,
                                      type: String),
          FastlaneCore::ConfigItem.new(key: :tabs,
                                  env_name: "TABS",
                               description: "Array of all Google Sheet Tabs",
                               default_value: [],
                                  optional: true,
                                      type: Array),
          FastlaneCore::ConfigItem.new(key: :support_spm,
                                  env_name: "SUPPORT_SPM",
                               description: "Is Swift Package",
                             default_value: false,
                                      type: Boolean),
          FastlaneCore::ConfigItem.new(key: :language_titles,
                                  env_name: "LANGUAGE_TITLES",
                               description: "Alle language titles",
                                  optional: false,
                                      type: Array),
          FastlaneCore::ConfigItem.new(key: :default_language,
                                  env_name: "DEFAULT_LANGUAGE",
                               description: "Default Language",
                                  optional: true,
                                      type: String),
          FastlaneCore::ConfigItem.new(key: :comment_example_language,
                                  env_name: "COMMENT_EXAMPLE_LANGUAGE",
                               description: "Comment Example Language",
                                  optional: true,
                                      type: String),
          FastlaneCore::ConfigItem.new(key: :base_language,
                                  env_name: "BASE_LANGUAGE",
                               description: "Base language for Xcode projects",
                                  optional: true,
                                      type: String),
          FastlaneCore::ConfigItem.new(key: :localization_path,
                                  env_name: "LOCALIZATION_PATH",
                               description: "Output path",
                                  optional: false,
                                      type: String),
          FastlaneCore::ConfigItem.new(key: :identifier_name,
                                  env_name: "IDENTIFIER_NAME",
                               description: "Identifier for Platform",
                                  optional: true,
                                      type: String),
          FastlaneCore::ConfigItem.new(key: :code_generation_path,
                                  env_name: "CODEGENERATIONPATH",
                               description: "Code generation path for the Swift file",
                                  optional: true,
                                      type: String),
          FastlaneCore::ConfigItem.new(key: :support_objc,
                                  env_name: "OBJC_SUPPORT",
                               description: "Whether the generated code should support Obj-C. Only relevant for the ios platform",
                                      type: Boolean,
                             default_value: false)
        ]
      end

      def self.is_supported?(platform)
         [:ios, :mac, :android].include?(platform)
      end
    end
  end
end
