//
//  Sum.swift
//  MyCalculator
//
//  Created by user on 01.10.2022.
//

import SwiftUI

struct Sum: View {
    @State private var sum = 0
    
    var body: some View {
        Text(String(self.sum).ruble).font(.largeTitle)
            .task {
                do {
                    self.sum = try MyCalculator.realm.objects(Item.self).sum(of: \.amount)
                } catch {
                    print(error)
                }
            }
    }
}
