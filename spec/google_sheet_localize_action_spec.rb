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

    def run_action(platform, dir)
      allow(Fastlane::Helper::GoogleSheetLocalizeHelper).to receive(:new).and_return(helper)
      config = FastlaneCore::Configuration.create(
        Fastlane::Actions::GoogleSheetLocalizeAction.available_options,
        service_account_path: 'key.json', sheet_id: 'id', platform: platform, localization_path: dir,
        language_titles: %w[de en], default_language: 'de'
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
