//
//  TodoView.swift
//  Todos
//
//  Created by 林悠斗 on 2024/12/28.
//

import ComposableArchitecture
import SwiftUI

@Reducer
struct TodoReducer {
    @ObservableState
    struct State: Codable, Equatable, Identifiable {
        let id: UUID
        var description = ""
        var isComplete = false
    }

    enum Action: BindableAction, Sendable {
        case binding(BindingAction<State>)
    }

    var body: some Reducer<State, Action> {
        BindingReducer()
    }
}

struct TodoView: View {
    @Bindable var store: StoreOf<TodoReducer>

    var body: some View {
        HStack {
            Button {
                store.isComplete.toggle()
            } label: {
                Image(systemName: store.isComplete ? "checkmark.square" : "square")
            }
            .buttonStyle(.plain)

            TextField("Untitled Todo", text: $store.description)
        }
        .foregroundColor(store.isComplete ? .gray : nil)
    }
}
