//
//  ContentView.swift
//  Localization
//
//  Created by Mario Hahn on 24.03.21.
//

import SwiftUI

struct ContentView: View {
    var body: some View {
        Text(Localization.exampleExampleTest2(1, "Mario"))
            .padding()
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
