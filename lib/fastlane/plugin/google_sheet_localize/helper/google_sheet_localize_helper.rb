require 'fastlane_core/ui/ui'

module Fastlane
  UI = FastlaneCore::UI unless Fastlane.const_defined?("UI")

  module Helper
    class GoogleSheetLocalizeHelper
        def generateJSONObject(contentRows, index)
            result = Array.new
            for i in 0..contentRows.count - 1
                item = generateSingleObject(contentRows[i], index)
                
                if item[:identifierIos] != "" && item[:identifierAndroid] != ""
                    result.push(item)
                end
            end
            
            return result
            
        end
        
        def writeToJSONFile(languages)
            File.open("output.json","w") do |f|
                f.write(JSON.pretty_generate(languages))
            end
        end
        
        def generateSingleObject(row, column)
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
        
        def createiOSFiles(languages)
            languages.each { |language| createFileForLanguage(language) }
        end
        
        def createFileForLanguage(language)
            FileUtils.mkdir_p language['language']
            File.open("#{language['language']}/Localizable.strings", "w") do |f|
                language["items"].each { |item|
                    f.write("//#{item['comment']}\n\"#{item['identifierIos']}\"=\"#{item['text']}\";\n")
                }
            end
        end
        
        
        def numberOfLanguages(worksheet)
            i = worksheet.num_cols
            return i - 3
        end

    end
  end
end
