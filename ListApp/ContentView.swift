import SwiftUI

// Model zadania
struct Task: Identifiable {
    var id = UUID()
    var title: String
    var isCompleted: Bool = false
    var dueDate: Date?
    var notes: String?
}

// Model listy zadań
class TaskList: ObservableObject, Identifiable {
    var id = UUID()
    @Published var name: String
    @Published var tasks: [Task]
    
    init(name: String, tasks: [Task] = []) {
        self.name = name
        self.tasks = tasks
    }
}

// Model zarządzający wszystkimi listami zadań
class TaskManager: ObservableObject {
    @Published var taskLists: [TaskList] = []
    
    func addTaskList(name: String) {
        let newList = TaskList(name: name)
        taskLists.append(newList)
    }
    
    func removeTaskList(at indexSet: IndexSet) {
        taskLists.remove(atOffsets: indexSet)
    }
    
    func moveTaskList(from source: IndexSet, to destination: Int) {
        taskLists.move(fromOffsets: source, toOffset: destination)
    }
}

// Widok główny
struct ContentView: View {
    @StateObject var taskManager = TaskManager()
    @State private var newListName = ""
    
    var body: some View {
        NavigationView {
            List {
                ForEach(taskManager.taskLists) { taskList in
                    NavigationLink(destination: TaskListView(taskList: taskList)) {
                        Text(taskList.name)
                    }
                }
                .onDelete(perform: taskManager.removeTaskList)
                .onMove(perform: taskManager.moveTaskList)
                .listRowBackground(Color.clear)
                
                HStack {
                    TextField("Nowa lista", text: $newListName)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .background(Color.clear)
                    Button(action: {
                        if !newListName.trimmingCharacters(in: .whitespaces).isEmpty {
                            taskManager.addTaskList(name: newListName)
                            newListName = ""
                        }
                    }) {
                        Text("Dodaj")
                    }
                    .disabled(newListName.trimmingCharacters(in: .whitespaces).isEmpty)
                }
                .padding(.vertical)
                .listRowBackground(Color.clear)
            }
            .navigationTitle("Listy")
            .toolbar {
                EditButton()
            }
            .background(Color.clear)
        }
        .background(Color.clear)
    }
}

// Widok do edytowania zadania
struct EditTaskView: View {
    @Binding var task: Task
    @State private var newTitle: String
    @State private var newDueDate: Date?
    @State private var newNotes: String
    
    init(task: Binding<Task>) {
        self._task = task
        self._newTitle = State(initialValue: task.wrappedValue.title)
        self._newDueDate = State(initialValue: task.wrappedValue.dueDate)
        self._newNotes = State(initialValue: task.wrappedValue.notes ?? "")
    }
    
    var body: some View {
        Form {
            TextField("Tytuł", text: $newTitle)
                .textFieldStyle(RoundedBorderTextFieldStyle())
            DatePicker("Data wykonania", selection: Binding($newDueDate, replacingNilWith: Date()), displayedComponents: .date)
            TextEditor(text: $newNotes)
                .frame(height: 100)
                .border(Color.gray, width: 1)
            Button("Zapisz") {
                task.title = newTitle
                task.dueDate = newDueDate
                task.notes = newNotes
            }
        }
        .navigationTitle("Edytuj")
        .background(Color.clear)
    }
}

// Binding helper to replace nil values
extension Binding where Value: Equatable {
    init(_ source: Binding<Value?>, replacingNilWith nilReplacement: Value) {
        self.init(
            get: { source.wrappedValue ?? nilReplacement },
            set: { newValue in source.wrappedValue = (newValue == nilReplacement ? nil : newValue) }
        )
    }
}

// Widok dla poszczególnych list zadań
struct TaskListView: View {
    @ObservedObject var taskList: TaskList
    @State private var newTaskTitle = ""
    @State private var showingEditTaskView = false
    @State private var taskToEdit: Task?
    @State private var showIncompleteOnly = false
    
    var body: some View {
        VStack {
            Toggle("Pokaż tylko nieodznaczone", isOn: $showIncompleteOnly)
                .padding()
            
            List {
                ForEach(filteredTasks) { task in
                    HStack {
                        Button(action: {
                            if let index = taskList.tasks.firstIndex(where: { $0.id == task.id }) {
                                taskList.tasks[index].isCompleted.toggle()
                            }
                        }) {
                            Image(systemName: task.isCompleted ? "checkmark.circle.fill" : "circle")
                                .foregroundColor(task.isCompleted ? .green : .gray)
                        }
                        VStack(alignment: .leading) {
                            Text(task.title)
                                .onTapGesture {
                                    taskToEdit = task
                                    showingEditTaskView = true
                                }
                            if let notes = task.notes {
                                Text(notes)
                                    .font(.subheadline)
                                    .foregroundColor(.gray)
                            }
                        }
                        Spacer()
                        if let dueDate = task.dueDate {
                            Text(dueDate, style: .date)
                                .foregroundColor(.gray)
                        }
                    }
                }
                .onDelete { indexSet in
                    taskList.tasks.remove(atOffsets: indexSet)
                }
                .onMove { source, destination in
                    taskList.tasks.move(fromOffsets: source, toOffset: destination)
                }
                .listRowBackground(Color.clear)
                
                HStack {
                    TextField("Nowe", text: $newTaskTitle)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                    Button(action: {
                        if !newTaskTitle.trimmingCharacters(in: .whitespaces).isEmpty {
                            let newTask = Task(title: newTaskTitle)
                            taskList.tasks.append(newTask)
                            newTaskTitle = ""
                        }
                    }) {
                        Text("Dodaj")
                    }
                    .disabled(newTaskTitle.trimmingCharacters(in: .whitespaces).isEmpty)
                }
                .listRowBackground(Color.clear)
            }
            .navigationTitle(taskList.name)
            .toolbar {
                EditButton()
                Button(action: toggleAllTasksCompletion) {
                    Text("Zaznacz wszystkie jako ukończone/nieukończone")
                }
            }
            .sheet(item: $taskToEdit) { task in
                if let taskIndex = taskList.tasks.firstIndex(where: { $0.id == task.id }) {
                    EditTaskView(task: $taskList.tasks[taskIndex])
                }
            }
            .background(Color.clear)
        }
        .background(Color.clear)
    }
    
    private var filteredTasks: [Task] {
        if showIncompleteOnly {
            return taskList.tasks.filter { !$0.isCompleted }
        }
        return taskList.tasks
    }
    
    private func toggleAllTasksCompletion() {
        let allCompleted = taskList.tasks.allSatisfy { $0.isCompleted }
        for index in taskList.tasks.indices {
            taskList.tasks[index].isCompleted = !allCompleted
        }
    }
}

// Główna aplikacja SwiftUI
@main
struct TaskApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
