//
//  MyCalculator.swift
//  MyCalculator
//
//  Created by user on 26.09.2022.
//

import SwiftUI
import Realm
import RealmSwift

final class Item: Object, Codable {
    @Persisted var info: String
    @Persisted var amount: Int
    @Persisted var createdAt: Date
    @Persisted var itemId: String
    
    enum Keys: CodingKey {
        case info, amount, createdAt, itemId
    }
    
    convenience init(from decoder: Decoder) throws {
        self.init()
        
        let container = try decoder.container(keyedBy: Keys.self)
        
        let createdAt = try container.decode(String.self, forKey: .createdAt)
        var createdAtString = Substring(createdAt)
        
        let hour: Int
        if case let hourPrefix = createdAtString.prefix(while: { $0.isHexDigit }), let hourValue = Int(hourPrefix) {
            hour = hourValue
            createdAtString = createdAtString.dropFirst(hourPrefix.count)
        } else {
            throw NSError(description: "Incorrect hour in \(createdAt)")
        }
        
        guard createdAtString.first == ":" else { throw NSError(description: "Incorrect colon in \(createdAt)") }
        createdAtString = createdAtString.dropFirst(1)
        
        let minute: Int
        if case let minutePrefix = createdAtString.prefix(while: { $0.isHexDigit }), let minuteValue = Int(minutePrefix) {
            minute = minuteValue
            createdAtString = createdAtString.dropFirst(minutePrefix.count)
        } else {
            throw NSError(description: "Incorrect minute in \(createdAt)")
        }
        
        guard createdAtString.first == ":" else { throw NSError(description: "Incorrect colon in \(createdAt)") }
        createdAtString = createdAtString.dropFirst(1)
        
        let second: Int
        if case let secondPrefix = createdAtString.prefix(while: { $0.isHexDigit }), let secondValue = Int(secondPrefix) {
            second = secondValue
            createdAtString = createdAtString.dropFirst(secondPrefix.count)
        } else {
            throw NSError(description: "Incorrect second in \(createdAt)")
        }
        
        createdAtString = createdAtString.drop(while: { $0.isWhitespace })
        
        let day: Int
        if case let dayPrefix = createdAtString.prefix(while: { $0.isHexDigit }), let dayValue = Int(dayPrefix) {
            day = dayValue
            createdAtString = createdAtString.dropFirst(dayPrefix.count)
        } else {
            throw NSError(description: "Incorrect day in \(createdAt)")
        }
        
        guard createdAtString.first == "." else { throw NSError(description: "Incorrect dot in \(createdAt)") }
        createdAtString = createdAtString.dropFirst(1)
        
        let month: Int
        if case let monthPrefix = createdAtString.prefix(while: { $0.isHexDigit }), let monthValue = Int(monthPrefix) {
            month = monthValue
            createdAtString = createdAtString.dropFirst(monthPrefix.count)
        } else {
            throw NSError(description: "Incorrect month in \(createdAt)")
        }
        
        guard createdAtString.first == "." else { throw NSError(description: "Incorrect dot in \(createdAt)") }
        createdAtString = createdAtString.dropFirst(1)
        
        let year: Int
        if let yearValue = Int(createdAtString) {
            year = yearValue
        } else {
            throw NSError(description: "Incorrect year in \(createdAt)")
        }
        
        if let date = DateComponents(calendar: Self.calendar,
                                     year: year, month: month, day: day, hour: hour, minute: minute, second: second).date {
            self.createdAt = date
        } else {
            throw NSError(description: "Cannot form a date from \(createdAt)")
        }
        
        self.info = try container.decode(String.self, forKey: .info)
        self.amount = try container.decode(Int.self, forKey: .amount)
        
        if let itemId = try container.decodeIfPresent(String.self, forKey: .itemId) {
            self.itemId = itemId
        } else {
            self.itemId = UUID().uuidString
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: Keys.self)
        
        try container.encode(self.info, forKey: .info)
        try container.encode(self.amount, forKey: .amount)
        
        let dateComponents = Self.calendar.dateComponents([.hour, .minute, .second, .day, .month, .year], from: self.createdAt)
        if let hour = dateComponents.hour,
            let minute = dateComponents.minute,
            let second = dateComponents.second,
            let day = dateComponents.day,
            let month = dateComponents.month,
            let year = dateComponents.year {
            try container.encode(String(format: "%02d:%02d:%02d %02d.%02d.%04d", hour, minute, second, day, month, year), forKey: .createdAt)
        } else {
            throw NSError(description: "Cannot encode a date.")
        }
        
        try container.encode(self.itemId, forKey: .itemId)
    }
    
    private static let calendar = Calendar(identifier: .gregorian)
}

struct MyCalculator: View {
    enum Sign {
        case expenses, incomes
    }
    struct Model: Identifiable {
        let info: String
        let amount: String
        let date: String
        let id: String
    }
    let sign: Sign
    
    @State private var isNumberInputPresented = false
    @State private var isFileImporterPresented = false
    @State private var number = ""
    @State private var info = ""
    
    @State private var models: [Model] = []
    
    var title: String {
        switch self.sign {
        case .expenses:
            return "Расходы"
        case .incomes:
            return "Доходы"
        }
    }
    
    static var realm: Realm {
        get throws {
            return try Realm(configuration: .init(schemaVersion: 0,
                                                  migrationBlock: { migration, oldSchemaVersion in
                
            },
                                                  objectTypes: [Item.self]))
        }
    }
    
    private let dateFormatter: DateFormatter = {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "HH:mm:ss\ndd MMMM yyyy"
        
        return dateFormatter
    }()
    
    @ViewBuilder
    private var mainView: some View {
        if self.models.isEmpty {
            ProgressView()
        } else {
            List(content: {
                ForEach(self.models) { model in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(model.amount.ruble)
                            Text(model.info).font(.caption2)
                        }
                        Spacer()
                        Text(model.date)
                    }
                }.onDelete { indexSet in
                    Task {
                        let ids: [String] = indexSet.map { index in
                            self.models[index].id
                        }
                        do {
                            let realm = try Self.realm
                            let items = realm.objects(Item.self).filter(NSPredicate(format: "\(Item.Keys.itemId.stringValue) IN %@", ids))
                            try realm.write({
                                realm.delete(items)
                            })
                            self.models.remove(atOffsets: indexSet)
                        } catch {
                            print(error)
                        }
                    }
                }
            })
        }
    }
    
    var body: some View {
        self.mainView.navigationTitle(self.title)
            .fileImporter(isPresented: self.$isFileImporterPresented, allowedContentTypes: [.text],
                          onCompletion: { result in
                Task {
                    do {
                        let url = try result.get()
                        let data = try Data(contentsOf: url)
                        
                        if case let newItems = try JSONDecoder().decode([FailableJsonValue<Item>].self, from: data).compactMap({ $0.value }), newItems.isEmpty == false {
                            let realm = try Self.realm
                            let ids: [String] = newItems.map({ $0.itemId })
                            try realm.write({
                                realm.delete(realm.objects(Item.self).filter("\(Item.Keys.itemId.stringValue) IN %@", ids))
                                realm.add(newItems)
                            })
                            self.validateView()
                        }
                    } catch {
                        print(error)
                    }
                }
            })
                .toolbar {
                    ToolbarItem(placement: .navigationBarLeading) {
                        ShareLink(item: ExportData(), preview: SharePreview("data.json"))
                        {
                            Text("Сохранить")
                        }
                    }
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button("Загрузить") {
                            self.isFileImporterPresented = true
                        }
                    }
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Добавить") {
                            self.isNumberInputPresented = true
                        }.sheet(isPresented: self.$isNumberInputPresented,
                                onDismiss: {
                            let number = self.number
                            let info = self.info
                            self.number = ""
                            self.info = ""
                            
                            Task {
                                if let amount = Int(number.trimmingCharacters(in: .whitespacesAndNewlines)), case let info = info.trimmingCharacters(in: .whitespacesAndNewlines), info.isEmpty == false {
                                    let amountValue: Int
                                    let newItem = Item()
                                    switch self.sign {
                                    case .incomes:
                                        amountValue = abs(amount)
                                    case .expenses:
                                        amountValue = -abs(amount)
                                    }
                                    newItem.amount = amountValue
                                    newItem.info = info
                                    newItem.itemId = UUID().uuidString
                                    
                                    do {
                                        let realm = try Self.realm
                                        try realm.write({
                                            realm.add(newItem)
                                        })
                                        self.models.insert(.init(info: info, amount: String(amountValue),
                                                                 date: self.dateFormatter.string(from: newItem.createdAt),
                                                                 id: newItem.itemId), at: 0)
                                    } catch {
                                        print(error)
                                    }
                                }
                            }
                        }, content: {
                            NavigationView {
                                List {
                                    Section(header: Text("Сумма")) {
                                        TextField("", text: self.$number)
                                            .textInputAutocapitalization(.never)
                                            .disableAutocorrection(true)
                                            .keyboardType(.numberPad)
                                    }
                                    Section(header: Text("Подробности")) {
                                        TextField("", text: self.$info)
                                    }
                                }.navigationTitle(self.title)
                                    .toolbar{
                                        ToolbarItem(placement: .navigationBarLeading) {
                                            Button("Отмена") {
                                                self.info = ""
                                                self.number = ""
                                                self.isNumberInputPresented = false
                                            }
                                        }
                                        ToolbarItem(placement: .navigationBarTrailing) {
                                            Button("Добавить") {
                                                self.isNumberInputPresented = false
                                            }
                                        }
                                    }
                            }
                        })
                    }
                }.task {
                    if self.isNumberInputPresented == false, self.models.isEmpty {
                        self.validateView()
                    }
                }
    }
    
    private func validateView() {
        do {
            let format: String
            let amount = Item.Keys.amount.stringValue
            switch self.sign {
            case .incomes:
                format = "\(amount) > 0"
            case .expenses:
                format = "\(amount) < 0"
            }
            self.models = try Self.realm.objects(Item.self)
                .filter(format)
                .sorted(by: \.createdAt, ascending: false)
                .map({ item in
                        .init(info: item.info, amount: String(item.amount),
                              date: self.dateFormatter.string(from: item.createdAt), id: item.itemId)
            })
        } catch {
            print(error)
        }
    }
}

struct ExportData: Transferable {
    static var transferRepresentation: some TransferRepresentation {
        return DataRepresentation<Self>(exportedContentType: .json,
                                        exporting: { sSelf in
            let objects = try MyCalculator.realm.objects(Item.self).sorted(by: \.createdAt, ascending: false)
            let encoder = JSONEncoder()
            encoder.outputFormatting = .prettyPrinted
            return try encoder.encode(objects)
        }).suggestedFileName("data.json")
    }
}

struct FailableJsonValue<Dec: Decodable>: Decodable {
    let value: Dec?
    
    init(from decoder: Decoder) throws {
        do {
            self.value = try Dec(from: decoder)
        } catch {
            print(error)
            self.value = nil
        }
    }
}
