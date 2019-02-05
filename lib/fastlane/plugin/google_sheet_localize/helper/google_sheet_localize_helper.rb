require 'fastlane_core/ui/ui'
require 'google_drive'

module Fastlane
  UI = FastlaneCore::UI unless Fastlane.const_defined?("UI")

  module Helper
    class GoogleSheetLocalizeHelper
    end
  end
end
