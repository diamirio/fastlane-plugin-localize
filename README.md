# google_sheet_localize plugin

[![CI](https://github.com/diamirio/fastlane-plugin-localize/actions/workflows/ci.yml/badge.svg)](https://github.com/diamirio/fastlane-plugin-localize/actions/workflows/ci.yml)
[![fastlane Plugin Badge](https://rawcdn.githack.com/fastlane/fastlane/master/fastlane/assets/plugin-badge.svg)](https://rubygems.org/gems/fastlane-plugin-google_sheet_localize)

## Getting Started

This project is a [_fastlane_](https://github.com/fastlane/fastlane) plugin. To get started with `fastlane-plugin-google_sheet_localize`, add it to your project by running:

```bash
fastlane add_plugin google_sheet_localize
```

## About google_sheet_localize

Creates .strings files for iOS and strings.xml files for Android

to use our plugin you have to duplicate this google sheet: [_Example_](https://docs.google.com/spreadsheets/d/1fwRj1ZFPu2XlrDqkaqmIpJulqR5OVFEZnN35a9v37yc/edit?usp=sharing) 

Authentication uses a Google service account key (JSON file, passed as `service_account_path`). Enable the Google Sheets API for the service account's project and share the sheet with the service account's email address (read access is enough).

* The language_titles (the columns which should be exported)
* The default_language (If a string is not present in a specific language, this is the fallback)
* The base_language (The language which is placed in the base values folder)

## Sheet Language 

#### Arguments: (Android + iOS + Web)  
English: `Mario ate a %2s %1s`.   
German: `Mario hat %1s einen %2s gegessen`.   
  
In this case `%2s` stands for __Apple__ and `%1s` for __Today__, the order is different in this example, so we need to take care of it.  

Mapped iOS: `Mario ate a %2$@ %1$@`.   
Mapped Android: `Mario ate a %2s %1s`.   
Mapped Web: `Mario ate a {2} {1}`.   

#### Plurals: (Android + iOS)
one|%d artist  
other|%d artists

#### String Array: (Android)
["Monday", "Tuesday", "Wednesday"]

## iOS specifics

In order to support Objective-C, the plugin provides the `support_objc` argument, which is default `false`.  
Therefore, if you need Objective-C support pass `support_objc: true`.

### Generated Swift

The `Localization.swift` the plugin generates is `public` by default. A Swift package that uses it only internally can pass `access_level: "package"` (or `"internal"`), so the type does not become part of its API or clash with an app's own `Localization`.

`swift_type: "configurable_struct"` generates a struct instead, with one `LocalizedStringResource` per text, looked up in the generated files. Texts with arguments are closures that return the resource. An app, or the users of a framework, can replace any text with its own, for example with a string literal that Xcode extracts into the app's String Catalog:

```ruby
google_sheet_localize(..., swift_type: "configurable_struct", type_name: "AppTexts")
```

```swift
var texts = AppTexts()
texts.common.cancel = "Abort"
texts.review.page = { page, count in "Sheet \(page) of \(count)" }

Button(texts.common.cancel) { ... }
```

The default value of each resource is the text in `comment_example_language`, with its placeholders interpolated in order; plural texts use their `other` form.

Texts are grouped into nested structs by the first segment of their identifier, so `review.page.title` becomes `review.pageTitle`. `type_name` names the struct and its file (`Localization` by default).

`file_header` is written at the top of the generated Swift file, for example `"// swift-format-ignore-file"` to keep a formatter away from it.

## Example

```ruby
  lane :localize do
    google_sheet_localize(service_account_path: "./fastlane/service_account.json",
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

Requires Ruby 3.0 or newer. To run both the tests and code style validation, run

```
bundle exec rake
```

## Issues and Feedback

For any other issues and feedback about this plugin, please submit it to this repository.

## Troubleshooting

If you have trouble using plugins, check out the [Plugins Troubleshooting](https://docs.fastlane.tools/plugins/plugins-troubleshooting/) guide.

## Using _fastlane_ Plugins

For more information about how the `fastlane` plugin system works, check out the [Plugins documentation](https://docs.fastlane.tools/plugins/create-plugin/).

## About _fastlane_

_fastlane_ is the easiest way to automate beta deployments and releases for your iOS and Android apps. To learn more, check out [fastlane.tools](https://fastlane.tools).
