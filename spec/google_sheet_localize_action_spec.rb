describe Fastlane::Actions::GoogleSheetLocalizeAction do
  describe '#run' do
    it 'prints a message' do
      expect(Fastlane::UI).to receive(:message).with("The google_sheet_localize plugin is working!")

      Fastlane::Actions::GoogleSheetLocalizeAction.run(nil)
    end
  end
end
