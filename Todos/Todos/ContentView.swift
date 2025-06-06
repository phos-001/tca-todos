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
        @Shared(.todos) var todos: IdentifiedArrayOf<TodoReducer.State> = []
        var editMode: EditMode = .inactive
        var filter: Filter = .all

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
        case toggleEditMode
    }

    @Dependency(\.uuid) var uuid
    private enum CancelID { case todoCompletion }

    var body: some Reducer<State, Action> {
        BindingReducer()
        Reduce { state, action in
            switch action {
            case .addTodoButtonTapped:
                state.$todos.withLock {
                    $0.insert(TodoReducer.State(id: self.uuid()), at: 0)
                }
                return .none
            case .binding:
                return .none
            case let .delete(indexSet):
                let filteredTodos = state.filteredTodos
                for index in indexSet {
                    state.$todos.withLock { todos in
                        todos.remove(id: filteredTodos[index].id)
                    }
                }
                return .none
            case var .move(source, destination):
                state.$todos.withLock {
                    $0.move(fromOffsets: source, toOffset: destination)
                }
                return .run { send in
                    await send(.sortCompletedTodos)
                }
            case .sortCompletedTodos:
                state.$todos.withLock {
                    $0.sort { $1.isComplete && !$0.isComplete }
                }
                return .none
            case .todos(.element(id: _, action: .binding(\.isComplete))):
                return .run { send in
                    await send(.sortCompletedTodos, animation: .default)
                }
                .cancellable(id: CancelID.todoCompletion, cancelInFlight: true)
            case .todos:
                return .none
            case .toggleEditMode:
                state.editMode = state.editMode.isEditing ? .inactive : .active
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
                    ForEach(store.todos.filter { todo in
                        switch store.filter {
                        case .all: return true
                        case .active: return !todo.isComplete
                        case .completed: return todo.isComplete
                        }
                    }) { todo in
                        if let todoStore = store.scope(state: \.todos[id: todo.id],
                                                       action: \.todos[id: todo.id]) {
                            TodoView(store: todoStore)
                        }
                    }
                }
            }
            .navigationTitle("Todoリスト")
            .navigationBarItems(trailing: HStack {
                Button.init(action: {
                    store.send(.toggleEditMode)
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

extension SharedKey where Self == FileStorageKey<IdentifiedArrayOf<TodoReducer.State>> {
    fileprivate static var todos: Self {
        fileStorage(.documentsDirectory.appending(component: "todos.json"))
    }
}

#Preview {
    ContentView(store: Store(initialState: TodosReducer.State(todos: .mock)) {
        TodosReducer()
    })
}
