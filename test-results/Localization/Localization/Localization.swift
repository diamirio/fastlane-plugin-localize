import Foundation

// swiftlint:disable all
public struct Localization {

    /**
    %.2f GB
    
    - Sheet comment:
    ````
    Markus Test 3
    ````
    */
    public static func markus3Test(_ arg0: Float) -> String {
		return localized(identifier: "markus3.test", arg0)
	}
    /**
    %s\n\nFehlercode: %d
    
    - Sheet comment:
    ````
    Markus 2 test
    ````
    */
    public static func murkus2Test(_ arg0: String, _ arg1: Int) -> String {
		return localized(identifier: "murkus2.test", arg0, arg1)
	}
    /**
    of %d %s used
    
    - Sheet comment:
    ````
    Markus test
    ````
    */
    public static func markusTest(_ arg0: Int, _ arg1: String) -> String {
		return localized(identifier: "markus.test", arg0, arg1)
	}
    /**
    Mario hat %1$s %2$s gegessen
    
    - Sheet comment:
    ````
    beispiel beispiel
    ````
    */
    public static func exampleExampleTest(_ arg0: String, _ arg1: String) -> String {
		return localized(identifier: "example.example.test", arg0, arg1)
	}
    /**
    Mario hat %1$d %2$d gegessen
    */
    public static func halloTest(_ arg0: Int, _ arg1: Int) -> String {
		return localized(identifier: "hallo.test", arg0, arg1)
	}
    /**
    Mario hat %1$d %2$s gegessen
    */
    public static func exampleExampleTest2(_ arg0: Int, _ arg1: String) -> String {
		return localized(identifier: "example.example.test2", arg0, arg1)
	}
    /**
    Test01
    
    - Sheet comment:
    ````
    Test01 is used because de is the default language
    ````
    */
    public static let iosTest01 = localized(identifier: "ios.test01")

    /**
    Bitte drücken Sie "Fortsetzen"
    */
    public static let iosTest02 = localized(identifier: "ios.test02")

    /**
    Hallo
    
    - Sheet comment:
    ````
    Hallo is used because de is the default language
    ````
    */
    public static let iosTest03 = localized(identifier: "ios.test03")

    /**
    Continue test
    
    - Sheet comment:
    ````
    Continue is supported as a Variable name 
    ````
    */
    public static let `continue` = localized(identifier: "continue")

    /**
    Switch test
    
    - Sheet comment:
    ````
    Switch is supported as a Variable name 
    ````
    */
    public static let `switch` = localized(identifier: "switch")

    /**
    Los geht's
    
    - Sheet comment:
    ````
    "'"test for Android
    ````
    */
    public static let iosTest04 = localized(identifier: "ios.test04")

    /**
    upcase, downcase test 
    */
    public static let viewControllerPurchaseButtonTitle = localized(identifier: "viewController.purchaseButton.title")

    /**
    one|%d Stunde
other|%d Stunden
    
    - Sheet comment:
    ````
    Plurals example 
    ````
    */
    public static func simulationTimeHour(_ arg0: Int) -> String {
		return localized(identifier: "simulation.time.hour", arg0)
	}
    /**
    one|%d Stunde
other|%d Stunden
    */
    public static func simulationTimeHour1(_ arg0: Int) -> String {
		return localized(identifier: "simulation.time.hour1", arg0)
	}
    /**
    Es ist ein %s
    
    - Sheet comment:
    ````
    Always use %s for strings, on iOS its converted to %@
    ````
    */
    public static func iosTest05(_ arg0: String) -> String {
		return localized(identifier: "ios.test05", arg0)
	}
    /**
    Links oder Rechts doppelklicken, um %d Sekunden zu überspringen
    */
    public static func iosTest06(_ arg0: Int) -> String {
		return localized(identifier: "ios.test06", arg0)
	}
    /**
    snake_case
    */
    public static let iAmATest = localized(identifier: "i_am_a_test")

}
        

private class LocalizationHelper { }
        

extension Localization {
        
	private static func localized(identifier key: String, _ args: CVarArg...) -> String {
        
		let bundle = Bundle(for: LocalizationHelper.self)
        
		let format = NSLocalizedString(key, tableName: nil, bundle: bundle, comment: "")
        
		guard !args.isEmpty else { return format }
        
		return String(format: format, locale: .current, arguments: args)
        
	}
        
}