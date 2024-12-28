//
//  ContentView.swift
//  Todos
//
//  Created by 林悠斗 on 2024/12/28.
//

import ComposableArchitecture
import SwiftUI

enum Filter: LocalizedStringKey, CaseIterable, Hashable {
    case all = "All"
    case active = "Active"
    case completed = "Completed"
}

@Reducer
struct TodosReducer {
    @ObservableState
    struct State: Equatable {
        var editMode: EditMode = .inactive
        var filter: Filter = .all
        var todos: IdentifiedArrayOf<TodoReducer.State> = []

        var filteredTodos: IdentifiedArrayOf<TodoReducer.State> {
            switch filter {
            case .active: self.todos.filter { !$0.isComplete }
            case .all: self.todos
            case .completed: self.todos.filter(\.isComplete)
            }
        }
    }

    enum Action: BindableAction, Sendable {
        case addTodoButtonTapped
        case binding(BindingAction<State>)
        case todos(IdentifiedActionOf<TodoReducer>)
    }

    @Dependency(\.uuid) var uuid

    var body: some Reducer<State, Action> {
        BindingReducer()
        Reduce { state, action in
            switch action {
            case .addTodoButtonTapped:
                state.todos.insert(TodoReducer.State(id: self.uuid()), at: 0)
                return .none
            case .binding:
                return .none
            case .todos:
                return .none
            }
        }
        .forEach(\.todos, action: \.todos) {
            TodoReducer()
        }
    }
}

struct ContentView: View {
    @Bindable var store: StoreOf<TodosReducer>

    var body: some View {
        NavigationStack {
            VStack {
                Picker("Filter", selection: $store.filter.animation()) {
                    ForEach(Filter.allCases, id: \.self) { filter in
                        Text(filter.rawValue).tag(filter)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)

                List(store.scope(state: \.filteredTodos,
                                 action: \.todos)) { store in
                    TodoView(store: store)
                }
            }
            .navigationTitle("Todoリスト")
            .navigationBarItems(trailing: HStack {
                Button("追加") {
                    store.send(.addTodoButtonTapped, animation: .default)
                }
            })
        }
    }
}

extension IdentifiedArrayOf<TodoReducer.State> {
    static let mock: Self = [
        TodoReducer.State(id: UUID(),
                          description: "Check Mail",
                          isComplete: false)
    ]
}

#Preview {
    ContentView(store: Store(initialState: TodosReducer.State(todos: .mock)) {
        TodosReducer()
    })
}
