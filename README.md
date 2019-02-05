# google_sheet_localize plugin

[![fastlane Plugin Badge](https://rawcdn.githack.com/fastlane/fastlane/master/fastlane/assets/plugin-badge.svg)](https://rubygems.org/gems/fastlane-plugin-google_sheet_localize)

## Getting Started

This project is a [_fastlane_](https://github.com/fastlane/fastlane) plugin. To get started with `fastlane-plugin-google_sheet_localize`, add it to your project by running:

```bash
fastlane add_plugin google_sheet_localize
```

## About google_sheet_localize

Creates .strings files for iOS and strings.xml files for Android

to use this plugin you have to copy this google sheet: https://docs.google.com/spreadsheets/d/1fwRj1ZFPu2XlrDqkaqmIpJulqR5OVFEZnN35a9v37yc/edit?usp=sharing


## Example

Check out the [example `Fastfile`](fastlane/Fastfile) to see how to use this plugin. Try it by cloning the repo, running `fastlane install_plugins` and `bundle exec fastlane test`.

```bash
  lane :localize do
    google_sheet_localize(service_account_path: "./fastlane/google_drive_credentials.json",
                                      sheet_id: "12P-zhTl3frWOh_jc9eITzvv7kNhQ2J-7V26SWQZRYLQ",
                                      platform: "ios",
                                          tabs: ["3TV"],
                             localization_path: "./Kit/TVKit",
                               language_titles: ["de", "en"],
                              default_language: "de")
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
