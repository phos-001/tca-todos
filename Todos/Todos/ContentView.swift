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
        case delete(IndexSet)
        case move(IndexSet, Int)
        case sortCompletedTodos
        case todos(IdentifiedActionOf<TodoReducer>)
    }

    @Dependency(\.continuousClock) var clock
    @Dependency(\.uuid) var uuid
    private enum CancelID { case todoCompletion }

    var body: some Reducer<State, Action> {
        BindingReducer()
        Reduce { state, action in
            switch action {
            case .addTodoButtonTapped:
                state.todos.insert(TodoReducer.State(id: self.uuid()), at: 0)
                return .none
            case .binding:
                return .none
            case let .delete(indexSet):
                let filteredTodos = state.filteredTodos
                indexSet.forEach {
                    state.todos.remove(id: filteredTodos[$0].id)
                }
                return .none
            case var .move(source, destination):
                if state.filter == .completed {
                    source = IndexSet(
                        source
                            .map { state.filteredTodos[$0] }
                            .compactMap { state.todos.index(id: $0.id) })
                    destination = (
                        destination < state.filteredTodos.endIndex
                        ? state.todos.index(id: state.filteredTodos[destination].id)
                        : state.todos.endIndex) ?? destination
                }
                state.todos.move(fromOffsets: source, toOffset: destination)
                return .run { send in
                    try await self.clock.sleep(for: .microseconds(100))
                    await send(.sortCompletedTodos)
                }
            case .sortCompletedTodos:
                state.todos.sort { $1.isComplete && !$0.isComplete }
                return .none
            case .todos(.element(id: _, action: .binding(\.isComplete))):
                return .run { send in
                    try await self.clock.sleep(for: .milliseconds(200))
                    await send(.sortCompletedTodos, animation: .default)
                }
                .cancellable(id: CancelID.todoCompletion, cancelInFlight: true)
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
                
                List() {
                    ForEach(store.scope(state: \.filteredTodos, action: \.todos)) { store in
                        TodoView(store: store)
                    }
                    .onDelete { store.send(.delete($0)) }
                    .onMove { store.send(.move($0, $1)) }
                }
            }
            .navigationTitle("Todoリスト")
            .navigationBarItems(trailing: HStack {
                Button.init(action: {
                    store.editMode = store.editMode.isEditing ? .inactive : .active
                }, label: {
                    if store.editMode.isEditing {
                        Text("完了")
                    } else {
                        Text("編集")
                    }
                })
                Button("追加") {
                    store.send(.addTodoButtonTapped, animation: .default)
                }
            })
            .environment(\.editMode, $store.editMode)
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
