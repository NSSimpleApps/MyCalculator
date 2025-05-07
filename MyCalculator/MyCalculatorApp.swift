//
//  MyCalculatorApp.swift
//  MyCalculator
//
//  Created by user on 26.09.2022.
//

import SwiftUI

@main
struct MyCalculatorApp: App {
    var body: some Scene {
        WindowGroup {
            TabView(content: {
                let expensesCalculator = MyCalculator(sign: .expenses)
                let expensesTitle = expensesCalculator.title
                NavigationStack {
                    expensesCalculator
                }.tabItem {
                    Label {
                        Text(expensesTitle)
                    } icon: {
                        Image("expenses")
                    }
                }.tag(0)
                
                let incomesCalculator = MyCalculator(sign: .incomes)
                let incomesTitle = incomesCalculator.title
                NavigationStack {
                    incomesCalculator
                }.tabItem {
                    Label {
                        Text(incomesTitle)
                    } icon: {
                        Image("incomes")
                    }
                }.tag(1)
                
                NavigationStack {
                    Sum().navigationTitle("Сумма")
                }.tabItem {
                    Label {
                        Text("Сумма")
                    } icon: {
                        Image("sigma")
                    }
                }.tag(2)
            })
        }
    }
}

extension String {
    var ruble: String {
        return self.appending(" ₽")
    }
}

extension NSError {
    convenience init(description: String) {
        self.init(domain: "DOMAIN", code: -1, userInfo: [NSLocalizedDescriptionKey: description])
    }
}
