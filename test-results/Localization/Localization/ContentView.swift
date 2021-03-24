//
//  ContentView.swift
//  Localization
//
//  Created by Mario Hahn on 24.03.21.
//

import SwiftUI

struct ContentView: View {
    var body: some View {
        Text(Localization.markus3Test(3.4568))
            .padding()
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
