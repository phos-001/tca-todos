//
//  ContentView.swift
//  Todos
//
//  Created by 林悠斗 on 2024/12/28.
//

import ComposableArchitecture
import SwiftUI

struct ContentView: View {
    @Bindable var store: StoreOf<TodoReducer>

    var body: some View {
        VStack {
            TodoView(store: store)
        }
        .padding()
    }
}

#Preview {
    ContentView(store: Store(initialState: TodoReducer.State(id: UUID())) {
        TodoReducer()
    })
}
