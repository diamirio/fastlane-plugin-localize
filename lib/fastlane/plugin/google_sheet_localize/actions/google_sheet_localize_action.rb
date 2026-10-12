require 'fastlane/action'
require 'json'

require_relative '../helper/google_sheet_localize_helper'

module Fastlane
  module Actions
    class GoogleSheetLocalizeAction < Action
      def self.run(params)
        sheets = Helper::GoogleSheetLocalizeHelper.new(params[:service_account_path], params[:sheet_id])
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
          identifier_name = 'Identifier iOS' if platform == 'ios'
          identifier_name = 'Identifier Android' if platform == 'android'
          identifier_name = 'Identifier Web' if platform == 'web'
        end

        comment_example_language = default_language if comment_example_language.to_s.empty?

        titles = sheets.worksheet_titles
        titles = titles.select { |title| tabs.include?(title) } unless tabs.count.zero?
        filtered_worksheets = titles.map { |title| sheets.worksheet(title) }

        result = []

        filtered_worksheets.each do |worksheet|
          identifier_index = 0

          rows = worksheet.rows
          next if rows.empty?

          (0..worksheet.max_cols).each do |i|
            identifier_index = i if rows[0][i] == identifier_name

            title = rows[0][i]

            next unless language_titles.include?(title)

            language = result.select { |item| item['language'] == title }.first

            if language.nil?
              language = {
                'language' => title,
                'items' => []
              }
            end

            content_rows = rows.drop(1)

            items = language['items']
            items += generate_json_object(content_rows, i, identifier_index)

            language['items'] = items

            result.push(language)
          end
        end
        create_files(result, platform, path, default_language, base_language, code_generation_path,
                     comment_example_language, support_objc, support_spm)
      end

      def self.generate_json_object(content_rows, index, identifier_index)
        result = []
        (0..content_rows.count - 1).each do |i|
          item = generate_single_object(content_rows[i], index, identifier_index)

          result.push(item) if item[:identifier] != ''
        end

        result
      end

      def self.generate_single_object(row, column, identifier_index)
        identifier = row[identifier_index]

        text = row[column]
        comment = row.last

        { 'identifier' => identifier,
          'text' => text,
          'comment' => comment }
      end

      def self.filter_unused_rows(items, identifier, filter_comment)
        filtered = items.select do |item|
          current_identifier = item[identifier]
          current_identifier != 'NR' && current_identifier != '' && current_identifier != 'TBD'
        end

        return filtered if filter_comment == 'false'

        filtered.reject do |item|
          item[identifier].include?('//')
        end
      end

      def self.create_files(languages, platform, destination_path, default_language, base_language, code_generation_path,
                            comment_example_language, support_objc, support_spm)
        create_files_for_languages(languages, platform, destination_path, default_language, base_language)

        if platform == 'web'
          json_file_name = 'Localization.json'

          json_filepath = "#{destination_path}/#{json_file_name}"

          File.open(json_filepath, 'w') do |f|
            json_item = {}

            languages.each do |language|
              filtered_items = filter_unused_rows(language['items'], 'identifier', 'true')

              all_keys = {}

              filtered_items.each do |item|
                identifier = item['identifier']

                text = item['text']

                matches = text.scan(/%[0-9][sdf]/)
                matches.each do |match|
                  text = text.gsub(match, "{#{match[1]}}")
                end

                all_keys[identifier] = text unless identifier.include?('//')
              end
              json_item[language['language']] = all_keys
            end

            json_string = JSON.pretty_generate(json_item)
            f.write(json_string)
          end
        end

        return unless platform == 'ios'

        swift_filename = 'Localization.swift'

        swift_path = code_generation_path

        swift_path = destination_path if code_generation_path.to_s.empty?

        language_items = languages.select { |item| item['language'] == comment_example_language }.first

        filtered_items = filter_unused_rows(language_items['items'], 'identifier', 'true')

        swift_filepath = "#{swift_path}/#{swift_filename}"

        File.open(swift_filepath, 'w') do |f|
          f.write("import Foundation\n\n// swiftlint:disable all\n#{get_ios_type_definition(support_objc)} {\n")
          filtered_items.each do |item|
            identifier = item['identifier']

            values = identifier.dup.split(/\.|_/)

            constant_name = ''

            values.each_with_index do |item, index|
              item[0] = if index.zero?
                          item[0].downcase
                        else
                          item[0].upcase
                        end
              constant_name += item
            end

            constant_name = '`continue`' if constant_name == 'continue'

            constant_name = '`switch`' if constant_name == 'switch'

            text = map_invalid_placeholder(item['text'])

            arguments = find_arguments_in_text(text)

            f.write(create_comment(item['comment'], item['text']))
            if arguments.count.zero?
              f.write("#{get_ios_attributes(support_objc)}public static let #{constant_name} = localized(identifier: \"#{identifier}\")\n")
            else
              f.write(create_ios_function(constant_name, identifier, arguments, support_objc))
            end
          end
          f.write("\n}")
          f.write(create_ios_file_end_string(destination_path, support_spm))
        end
      end

      def self.create_comment(comment, example)
        if comment.to_s.empty?
          return %(
    /**
    #{example}
    */
    )
        end

        %(
    /**
    #{example}

    - Sheet comment:
    ````
    #{comment}
    ````
    */
    )
      end

      def self.create_files_for_languages(languages, platform, destination_path, default_language, base_language)
        languages.each do |language|
          if platform == 'ios'

            filtered_items = filter_unused_rows(language['items'], 'identifier', 'false')

            string_file_name = 'Localizable.strings'
            plurals_file_name = 'Localizable.stringsdict'

            language_name = language['language']

            language_name = 'Base' if language_name == base_language

            string_filepath = "#{destination_path}/#{language_name}.lproj/#{string_file_name}"
            plurals_filepath = "#{destination_path}/#{language_name}.lproj/#{plurals_file_name}"
            FileUtils.mkdir_p "#{destination_path}/#{language_name}.lproj"

            File.open(string_filepath, 'w') do |f|
              filtered_items.each_with_index do |item, index|
                text = map_invalid_placeholder(item['text'])
                comment = item['comment']
                identifier = item['identifier']

                line = ''
                if identifier.include?('//')
                  line = "\n\n#{identifier}\n"
                else

                  if ['', 'TBD'].include?(text) && !default_language.to_s.empty?
                    default_language_object = languages.select do |language_item|
                      language_item['language'] == default_language
                    end.first['items']
                    default_language_object = filter_unused_rows(default_language_object, 'identifier', 'false')

                    default_language_text = default_language_object[index]['text']
                    puts "found empty text for:\n\tidentifier: #{identifier}\n\tlanguage:#{language['language']}\n\treplacing it with: #{default_language_text}"
                    text = map_invalid_placeholder(default_language_text)
                  end

                  unless text.include?('one|')

                    text = text.gsub('$s', '$@').gsub('%s', '%@')

                    line = "\"#{identifier}\" = \"#{text}\";"
                    line = if !comment.to_s.empty?
                             line + " //#{comment}\n"
                           else
                             "#{line}\n"
                           end
                  end
                end
                f.write(line)
              end
            end

            File.open(plurals_filepath, 'w') do |f|
              f.write("<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n")
              f.write("<!DOCTYPE plist PUBLIC \"-//Apple//DTD PLIST 1.0//EN\" \"http://www.apple.com/DTDs/PropertyList-1.0.dtd\">\n")
              f.write("<plist version=\"1.0\">\n")
              f.write("<dict>\n")

              filtered_items.each_with_index do |item, index|
                text = map_invalid_placeholder(item['text'])
                identifier = item['identifier']

                if ['', 'TBD'].include?(text) && !default_language.to_s.empty?
                  default_language_object = languages.select do |language_item|
                    language_item['language'] == default_language
                  end.first['items']
                  default_language_object = filter_unused_rows(default_language_object, 'identifier', 'false')

                  default_language_text = default_language_object[index]['text']
                  puts "found empty text for:\n\tidentifier: #{identifier}\n\tlanguage:#{language['language']}\n\treplacing it with: #{default_language_text}"
                  text = map_invalid_placeholder(default_language_text)
                end

                next unless !identifier.include?('//') && text.include?('one|')

                text = text.gsub("\n", '|')

                format_identifier = identifier.gsub('.', '')

                f.write("\t\t<key>#{identifier}</key>\n")
                f.write("\t\t<dict>\n")
                f.write("\t\t\t<key>NSStringLocalizedFormatKey</key>\n")
                f.write("\t\t\t<string>%#@#{format_identifier}@</string>\n")
                f.write("\t\t\t<key>#{format_identifier}</key>\n")
                f.write("\t\t\t<dict>\n")
                f.write("\t\t\t\t<key>NSStringFormatSpecTypeKey</key>\n")
                f.write("\t\t\t\t<string>NSStringPluralRuleType</string>\n")
                f.write("\t\t\t\t<key>NSStringFormatValueTypeKey</key>\n")
                f.write("\t\t\t\t<string>d</string>\n")

                text.split('|').each_with_index do |word, word_index|
                  if word_index.even?
                    f.write("\t\t\t\t<key>#{word}</key>\n")
                  else
                    f.write("\t\t\t\t<string>#{word}</string>\n")
                  end
                end
                f.write("\t\t\t</dict>\n")
                f.write("\t\t</dict>\n")
              end
              f.write("</dict>\n")
              f.write("</plist>\n")
            end
          end

          next unless platform == 'android'

          language_dir = language['language']

          language_dir = if language_dir == base_language
                           'values'
                         else
                           "values-#{language_dir}"
                         end

          FileUtils.mkdir_p "#{destination_path}/#{language_dir}"
          File.open("#{destination_path}/#{language_dir}/strings.xml", 'w') do |f|
            f.write("<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n")
            f.write("<resources>\n")

            filtered_items = filter_unused_rows(language['items'], 'identifier', 'false')

            filtered_items.each_with_index do |item, index|
              comment = item['comment']
              identifier = item['identifier']
              text = item['text']

              line = ''

              line += "    <!--#{comment}-->\n" unless comment.to_s.empty?

              if ['', 'TBD'].include?(text) && !default_language.to_s.empty?
                default_language_object = languages.select do |language_item|
                  language_item['language'] == default_language
                end.first['items']
                default_language_object = filter_unused_rows(default_language_object, 'identifier', 'false')

                default_language_text = default_language_object[index]['text']
                puts "found empty text for:\n\tidentifier: #{identifier}\n\tlanguage:#{language['language']}\n\treplacing it with: #{default_language_text}"
                text = default_language_text
              end

              raw_text = text
              text = text.gsub(/\\?'/, "\\\\'")

              if text.include?('one|')

                text = text.gsub("\n", '|')

                line += "    <plurals name=\"#{identifier}\">\n"

                plural = ''

                text.split('|').each_with_index do |word, word_index|
                  if word_index.even?
                    plural = "        <item quantity=\"#{word}\">"
                  else
                    plural += "<![CDATA[#{word}]]></item>\n"
                    line += plural
                  end
                end
                line += "    </plurals>\n"
              elsif text.start_with?('["') && text.end_with?('"]')

                line += "    <string-array name=\"#{identifier}\">\n"

                # JSON does not allow \' escapes, so parse the text before the apostrophes got escaped
                JSON.parse(raw_text.gsub("\\'", "'")).each do |array_item|
                  array_item = array_item.gsub("'", "\\\\'")

                  line += "        <item><![CDATA[#{array_item}]]></item>\n"
                end

                line += "    </string-array>\n"
              else
                line += "    <string name=\"#{identifier}\"><![CDATA[#{text}]]></string>\n"
              end

              f.write(line)
            end
            f.write("</resources>\n")
          end
        end
      end

      def self.create_ios_file_end_string(destination_path, support_spm)
        bundle = support_spm ? 'let bundle = Bundle.module' : 'let bundle = Bundle(for: LocalizationHelper.self)'

        puts destination_path

        if destination_path.include?('.bundle')

          bundle_name = destination_path.split('/').last.gsub('.bundle', '')
          bundle = %(let bundleUrl = Bundle(for: LocalizationHelper.self).url(forResource: "#{bundle_name}", withExtension: "bundle")
        \n\t\tlet bundle = Bundle(url: bundleUrl!)!)
        end

        %(
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

      def self.create_ios_function(constant_name, identifier, arguments, support_objc)
        function_title = "#{get_ios_attributes(support_objc)}public static func #{constant_name}("

        arguments.each_with_index do |item, index|
          function_title += "_ arg#{index}: #{item[:type]}"
          function_title = if index < arguments.count - 1
                             "#{function_title}, "
                           else
                             "#{function_title}) -> String {\n"
                           end
        end
        function_title += "\t\treturn localized(identifier: \"#{identifier}\", "
        arguments.each_with_index do |_item, index|
          function_title += "arg#{index}"
          function_title = if index < arguments.count - 1
                             "#{function_title}, "
                           else
                             "#{function_title})\n\t}"
                           end
        end

        function_title
      end

      def self.get_ios_type_definition(support_objc)
        support_objc ? 'public class Localization: NSObject' : 'public struct Localization'
      end

      def self.get_ios_attributes(support_objc)
        support_objc ? '@objc ' : ''
      end

      def self.find_arguments_in_text(text)
        text = text.dup.split('|')[1] if text.include?('one|')

        result = []
        filtered = map_invalid_placeholder(text)

        string_indexes = scan_str(filtered, /%([0-9]+)?\$?[s@]/)
        int_indexes = scan_str(filtered, /%([0-9]+)?\$?d/)
        float_indexes = scan_str(filtered, /%([0-9]+)?\$?([0-9]+)?.?([0-9]+)?f/)
        double_indexes = scan_str(filtered, /%([0-9]+)?\$?([0-9]+)?.?([0-9]+)?ld/)

        result += string_indexes.map { |e| { "index": e[0], "offset": e[1], "type": 'String' } } if string_indexes.count.positive?

        if int_indexes.count.positive?
          result += int_indexes.map do |e|
            { "index": e[0], "offset": e[1], "type": 'Int' }
          end
        end

        if float_indexes.count.positive?
          result += float_indexes.map do |e|
            { "index": e[0], "offset": e[1], "type": 'Float' }
          end
        end

        result += double_indexes.map { |e| { "index": e[0], "offset": e[1], "type": 'Double' } } if double_indexes.count.positive?

        result.sort_by { |hsh| hsh[:offset] }
      end

      def self.scan_str(str, pattern)
        res = []
        (0..str.length).each do |i|
          res << [Regexp.last_match.to_s, i] if str[i..] =~ /^#{pattern}/
        end
        res
      end

      def self.map_invalid_placeholder(text)
        text.gsub('%s', '%@').gsub('"', '\"')
      end

      def self.description
        'Creates .strings files for iOS and strings.xml files for Android'
      end

      def self.authors
        ['Mario Hahn', 'Thomas Koller']
      end

      def self.return_value
        # If your method provides a return value, you can describe here what it does
      end

      def self.details
        # Optional:
        'Creates .strings files for iOS and strings.xml files for Android. The localization is mananged on a google sheet.'
      end

      def self.available_options
        [
          FastlaneCore::ConfigItem.new(key: :service_account_path,
                                       env_name: 'SERVICE_ACCOUNT_PATH',
                                       description: 'Credentials path',
                                       optional: false,
                                       type: String),
          FastlaneCore::ConfigItem.new(key: :sheet_id,
                                       env_name: 'SHEET_ID',
                                       description: 'Your Google-spreadsheet id',
                                       optional: false,
                                       type: String),
          FastlaneCore::ConfigItem.new(key: :platform,
                                       env_name: 'PLATFORM',
                                       description: 'Platform, ios or android',
                                       optional: true,
                                       default_value: Actions.lane_context[Actions::SharedValues::PLATFORM_NAME].to_s,
                                       default_value_dynamic: true,
                                       type: String),
          FastlaneCore::ConfigItem.new(key: :tabs,
                                       env_name: 'TABS',
                                       description: 'Array of all Google Sheet Tabs',
                                       default_value: [],
                                       optional: true,
                                       type: Array),
          FastlaneCore::ConfigItem.new(key: :support_spm,
                                       env_name: 'SUPPORT_SPM',
                                       description: 'Is Swift Package',
                                       default_value: false,
                                       type: Boolean),
          FastlaneCore::ConfigItem.new(key: :language_titles,
                                       env_name: 'LANGUAGE_TITLES',
                                       description: 'Alle language titles',
                                       optional: false,
                                       type: Array),
          FastlaneCore::ConfigItem.new(key: :default_language,
                                       env_name: 'DEFAULT_LANGUAGE',
                                       description: 'Default Language',
                                       optional: true,
                                       type: String),
          FastlaneCore::ConfigItem.new(key: :comment_example_language,
                                       env_name: 'COMMENT_EXAMPLE_LANGUAGE',
                                       description: 'Comment Example Language',
                                       optional: true,
                                       type: String),
          FastlaneCore::ConfigItem.new(key: :base_language,
                                       env_name: 'BASE_LANGUAGE',
                                       description: 'Base language for Xcode projects',
                                       optional: true,
                                       type: String),
          FastlaneCore::ConfigItem.new(key: :localization_path,
                                       env_name: 'LOCALIZATION_PATH',
                                       description: 'Output path',
                                       optional: false,
                                       type: String),
          FastlaneCore::ConfigItem.new(key: :identifier_name,
                                       env_name: 'IDENTIFIER_NAME',
                                       description: 'Identifier for Platform',
                                       optional: true,
                                       type: String),
          FastlaneCore::ConfigItem.new(key: :code_generation_path,
                                       env_name: 'CODEGENERATIONPATH',
                                       description: 'Code generation path for the Swift file',
                                       optional: true,
                                       type: String),
          FastlaneCore::ConfigItem.new(key: :support_objc,
                                       env_name: 'OBJC_SUPPORT',
                                       description: 'Whether the generated code should support Obj-C. Only relevant for the ios platform',
                                       type: Boolean,
                                       default_value: false)
        ]
      end

      # fastlane calls this method by name, so it cannot be renamed to `supported?`
      def self.is_supported?(platform) # rubocop:disable Naming/PredicatePrefix
        %i[ios mac android].include?(platform)
      end
    end
  end
end
