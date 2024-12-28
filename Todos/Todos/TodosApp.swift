//
//  TodosApp.swift
//  Todos
//
//  Created by 林悠斗 on 2024/12/28.
//

import ComposableArchitecture
import SwiftUI

@main
struct TodosApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView(store: Store(initialState: TodoReducer.State(id: UUID())) {
                TodoReducer()
            })
        }
    }
}
