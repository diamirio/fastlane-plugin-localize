# google_sheet_localize plugin

[![fastlane Plugin Badge](https://rawcdn.githack.com/fastlane/fastlane/master/fastlane/assets/plugin-badge.svg)](https://rubygems.org/gems/fastlane-plugin-google_sheet_localize)

## Getting Started

This project is a [_fastlane_](https://github.com/fastlane/fastlane) plugin. To get started with `fastlane-plugin-google_sheet_localize`, add it to your project by running:

```bash
fastlane add_plugin google_sheet_localize
```

## About google_sheet_localize

Creates .strings files for iOS and strings.xml files for Android

to use our plugin you have to duplicate this google sheet: https://docs.google.com/spreadsheets/d/1fwRj1ZFPu2XlrDqkaqmIpJulqR5OVFEZnN35a9v37yc/edit?usp=sharing

Google Drive access token: 
https://medium.com/@osanda.deshan/getting-google-oauth-access-token-using-google-apis-18b2ba11a11a

* The language_titles (the columns which should be exported)
* The default_language (If a string is not present in a specific language, this is the fallback)
* The base_language (The language which is placed in the base values folder)

## Sheet Language 

#### Plurals: (Android + iOS)
one|%d artist  
other|%d artists

#### String Array: (Android)
["Monday", "Tuesday", "Wednesday"]

## Example

```ruby
  lane :localize do
    google_sheet_localize(service_account_path: "./fastlane/google_drive_credentials.json",
                                      sheet_id: "sheet id",
                                      platform: "ios",
                                          tabs: ["3TV"], #array of tab titles in google sheet
                             localization_path: "./Kit/TVKit",
                               language_titles: ["de", "en"], #language titles in google sheet
                              default_language: "de", #default language for google sheet
                                 base_language: "en") #ios: Base.lproj android: values 
  end
```


## Run tests for this plugin

To run both the tests, and code style validation, run

```
rake
```

To automatically fix many of the styling issues, use
```
rubocop -a
```

## Issues and Feedback

For any other issues and feedback about this plugin, please submit it to this repository.

## Troubleshooting

If you have trouble using plugins, check out the [Plugins Troubleshooting](https://docs.fastlane.tools/plugins/plugins-troubleshooting/) guide.

## Using _fastlane_ Plugins

For more information about how the `fastlane` plugin system works, check out the [Plugins documentation](https://docs.fastlane.tools/plugins/create-plugin/).

## About _fastlane_

_fastlane_ is the easiest way to automate beta deployments and releases for your iOS and Android apps. To learn more, check out [fastlane.tools](https://fastlane.tools).
