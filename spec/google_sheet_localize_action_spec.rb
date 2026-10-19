describe Fastlane::Actions::GoogleSheetLocalizeAction do
  describe '.available_options' do
    it 'defines the required options' do
      keys = Fastlane::Actions::GoogleSheetLocalizeAction.available_options.map(&:key)
      expect(keys).to include(:service_account_path, :sheet_id, :language_titles, :localization_path)
    end
  end

  describe Fastlane::Helper::GoogleSheetLocalizeHelper do
    it 'builds a service account authorization' do
      require 'openssl'
      require 'json'
      require 'tempfile'
      key = Tempfile.new(['key', '.json'])
      key.write(JSON.generate(type: 'service_account', client_email: 'a@b.iam.gserviceaccount.com',
                              private_key: OpenSSL::PKey::RSA.new(2048).to_pem, token_uri: 'https://oauth2.googleapis.com/token'))
      key.close
      expect { described_class.new(key.path, 'sheet') }.not_to raise_error
    end
  end

  describe '.run' do
    let(:rows) do
      [
        ['Identifier iOS', 'Identifier Android', 'de', 'en', 'Comment'],
        ['hello.world', 'hello_world', 'Hallo %s', 'Hello %s', 'greeting'],
        ['bye', 'bye', 'Tschüss', '', '']
      ]
    end
    let(:helper) do
      double('helper', worksheet_titles: ['Sheet'],
                       worksheet: Fastlane::Helper::GoogleSheetLocalizeHelper::Worksheet.new('Sheet', rows))
    end

    def run_action(platform, dir, **options)
      allow(Fastlane::Helper::GoogleSheetLocalizeHelper).to receive(:new).and_return(helper)
      config = FastlaneCore::Configuration.create(
        Fastlane::Actions::GoogleSheetLocalizeAction.available_options,
        service_account_path: 'key.json', sheet_id: 'id', platform: platform, localization_path: dir,
        language_titles: %w[de en], default_language: 'de', **options
      )
      Fastlane::Actions::GoogleSheetLocalizeAction.run(config)
    end

    it 'writes iOS files and falls back to the default language' do
      Dir.mktmpdir do |dir|
        run_action('ios', dir)
        strings = File.read("#{dir}/en.lproj/Localizable.strings", encoding: 'UTF-8')
        expect(strings).to eq("\"hello.world\" = \"Hello %@\"; //greeting\n\"bye\" = \"Tschüss\";\n")
        expect(File.read("#{dir}/Localization.swift",
                         encoding: 'UTF-8')).to include('public static func helloWorld(_ arg0: String)')
      end
    end

    it 'generates Swift with the given access level' do
      Dir.mktmpdir do |dir|
        run_action('ios', dir, access_level: 'package')
        swift = File.read("#{dir}/Localization.swift", encoding: 'UTF-8')
        expect(swift).to include('package struct Localization')
        expect(swift).to include('package static func helloWorld(_ arg0: String)')
        expect(swift).to include('package static let bye = localized(identifier: "bye")')
        expect(swift).not_to include('public ')
      end
    end

    it 'generates a configurable struct with one localized string resource per text' do
      Dir.mktmpdir do |dir|
        run_action('ios', dir, swift_type: 'configurable_struct', type_name: 'AppTexts', support_spm: true,
                               file_header: '// Generated; do not edit.')
        swift = File.read("#{dir}/AppTexts.swift", encoding: 'UTF-8')
        expect(File.exist?("#{dir}/Localization.swift")).to be(false)
        expect(swift).to start_with("// Generated; do not edit.\n\nimport Foundation")
        expect(swift).not_to include('swiftlint')
        expect(swift).to include('public struct AppTexts: Sendable')
        expect(swift).to include("public var bye = LocalizedStringResource(\n        \"bye\",\n        " \
                                 "defaultValue: \"Tschüss\",\n        bundle: AppTexts.bundle\n    )")
        expect(swift).to include('LocalizedStringResource.BundleDescription.atURL(Bundle.module.bundleURL)')
      end
    end

    it 'groups texts by the first segment of their identifier' do
      Dir.mktmpdir do |dir|
        run_action('ios', dir, swift_type: 'configurable_struct', type_name: 'AppTexts')
        swift = File.read("#{dir}/AppTexts.swift", encoding: 'UTF-8')
        expect(swift).to include('public var hello = Hello()')
        expect(swift).to include('public struct Hello: Sendable')
        expect(swift).to include("        /// Hallo %s\n        ///\n        /// Sheet comment:\n        /// greeting\n")
        expect(swift).to include('public var world: @Sendable (_ arg0: String) -> LocalizedStringResource = { arg0 in')
        expect(swift).to include('defaultValue: "Hallo \\(arg0)"')
        expect(swift).to include('LocalizedStringResource.BundleDescription.main')
      end
    end

    it 'interpolates placeholders and uses the other form of plurals as default values' do
      action = Fastlane::Actions::GoogleSheetLocalizeAction
      expect(action.swift_default_value('Seite %1$s von %2$s')).to eq('Seite \\(arg0) von \\(arg1)')
      expect(action.swift_default_value("one|%d weitere Leistung\nother|%d weitere Leistungen"))
        .to eq('\\(arg0) weitere Leistungen')
      expect(action.swift_default_value("Sag \"hi\"\nzu")).to eq('Sag \\"hi\\"\\nzu')
    end

    it 'rejects an unknown access level' do
      Dir.mktmpdir do |dir|
        expect { run_action('ios', dir, access_level: 'open') }.to raise_error(FastlaneCore::Interface::FastlaneError)
      end
    end

    context 'with a string array containing apostrophes' do
      let(:rows) do
        [['Identifier iOS', 'Identifier Android', 'de', 'en', 'Comment'],
         ['arr', 'arr', '["a", "d\'b"]', '["a", "d\'b"]', '']]
      end

      it 'escapes the apostrophes in the Android string array' do
        Dir.mktmpdir do |dir|
          run_action('android', dir)
          xml = File.read("#{dir}/values-en/strings.xml", encoding: 'UTF-8')
          expect(xml).to include("<item><![CDATA[d\\'b]]></item>")
        end
      end
    end

    it 'writes Android files' do
      Dir.mktmpdir do |dir|
        run_action('android', dir)
        expect(File.read("#{dir}/values-en/strings.xml",
                         encoding: 'UTF-8')).to include('<string name="hello_world"><![CDATA[Hello %s]]></string>')
      end
    end
  end
end
