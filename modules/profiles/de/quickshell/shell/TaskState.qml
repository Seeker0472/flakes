pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import "TaskLogic.js" as TaskLogic

Singleton {
    id: root

    readonly property bool enabled: Commands.taskEnabled

    property var tasks: []
    property string selectedView: "today"
    property bool ready: false
    property bool loading: false
    property bool mutating: false
    property bool refreshQueued: false
    property string errorMessage: ""
    property string noticeMessage: ""
    property string pendingSuccessMessage: ""
    property string currentOperation: ""
    property string completingUuid: ""
    property date currentTime: new Date()

    property bool canUndo: false
    property string undoMessage: ""
    property bool syncChecked: false
    property bool syncConfigured: false
    property bool syncing: false
    property bool syncQueued: false
    property bool syncAfterProbe: false
    property bool pendingSync: false
    property string syncStatus: "local"
    property string syncMessage: "Stored locally"
    property date lastSyncTime: new Date(0)

    readonly property bool busy: root.mutating || root.syncing
    readonly property var visibleTasks: root.filteredTasks(root.tasks, root.selectedView, root.currentTime)
    readonly property int totalCount: root.tasks.length
    readonly property int inboxCount: root.countTasks(root.tasks, "inbox", root.currentTime)
    readonly property int overdueCount: root.countTasks(root.tasks, "overdue", root.currentTime)
    readonly property int todayCount: root.countTasks(root.tasks, "today", root.currentTime)
    readonly property int upcomingCount: root.countTasks(root.tasks, "upcoming", root.currentTime)
    readonly property string headerSummary: root.errorMessage.length > 0
        ? root.errorMessage
        : root.totalCount + " pending" + (root.overdueCount > 0 ? " · " + root.overdueCount + " overdue" : "")
    readonly property string syncStatusLabel: {
        if (!root.syncConfigured) return "Local"
        if (root.syncing) return "Syncing"
        if (root.syncStatus === "error") return "Sync error"
        if (root.pendingSync) return "Pending sync"
        return "Synced"
    }

    signal mutationFinished(string operation, bool success)

    Process {
        id: queryProcess
        command: [Commands.task, "rc.json.array=on", "rc.color=off", "status:pending", "export"]
        stdout: StdioCollector { id: queryOutput }
        stderr: StdioCollector { id: queryError }
        onExited: exitCode => root.finishRefresh(exitCode, queryOutput.text, queryError.text)
    }

    Process {
        id: mutationProcess
        stdout: StdioCollector { id: mutationOutput }
        stderr: StdioCollector { id: mutationError }
        onExited: exitCode => root.finishMutation(exitCode, mutationOutput.text, mutationError.text)
    }

    Process {
        id: syncProbeProcess
        command: [Commands.task, "rc.color=off", "show", "sync.server.url"]
        stdout: StdioCollector { id: syncProbeOutput }
        onExited: exitCode => root.finishSyncProbe(exitCode, syncProbeOutput.text)
    }

    Process {
        id: syncProcess
        command: [Commands.task, "rc.confirmation=off", "rc.color=off", "sync"]
        stdout: StdioCollector { id: syncOutput }
        stderr: StdioCollector { id: syncError }
        onExited: exitCode => root.finishSync(exitCode, syncOutput.text, syncError.text)
    }

    Timer {
        interval: 60000
        running: root.enabled
        repeat: true
        onTriggered: {
            root.currentTime = new Date()
            root.refresh()
        }
    }

    Timer {
        interval: 300000
        running: root.syncConfigured
        repeat: true
        onTriggered: root.syncNow()
    }

    Timer {
        id: noticeTimer
        interval: 3500
        repeat: false
        onTriggered: if (!root.canUndo) root.noticeMessage = ""
    }

    Timer {
        id: undoTimer
        interval: 8000
        repeat: false
        onTriggered: {
            root.canUndo = false
            root.undoMessage = ""
            root.noticeMessage = ""
            root.syncNow()
        }
    }

    Timer {
        id: syncDebounceTimer
        interval: 8000
        repeat: false
        onTriggered: root.syncNow()
    }

    Component.onCompleted: {
        root.refresh()
        root.probeSyncConfiguration(false)
    }

    function pageOpened() {
        root.currentTime = new Date()
        if (!root.syncChecked) root.probeSyncConfiguration(true)
        else if (root.syncConfigured) root.syncNow()
        else root.refresh()
    }

    function refresh() {
        if (!root.enabled) return
        root.currentTime = new Date()
        if (queryProcess.running || root.syncing) {
            root.refreshQueued = true
            return
        }
        root.loading = true
        root.refreshQueued = false
        queryProcess.running = true
    }

    function probeSyncConfiguration(syncAfterProbe) {
        if (!root.enabled) return
        root.syncAfterProbe = root.syncAfterProbe || Boolean(syncAfterProbe)
        if (!syncProbeProcess.running) syncProbeProcess.running = true
    }

    function finishSyncProbe(exitCode, output) {
        root.syncChecked = true
        var text = String(output || "")
        root.syncConfigured = exitCode === 0 && /sync\.server\.url\s+\S+/.test(text)
        if (!root.syncConfigured) {
            root.syncStatus = "local"
            root.syncMessage = "Stored locally"
            root.pendingSync = false
        }
        var shouldSync = root.syncAfterProbe
        root.syncAfterProbe = false
        if (shouldSync && root.syncConfigured) root.syncNow()
    }

    function requestSync() {
        if (!root.syncChecked || !root.syncConfigured) root.probeSyncConfiguration(true)
        else root.syncNow()
    }

    function syncNow() {
        if (!root.syncConfigured) return
        if (root.canUndo) {
            root.pendingSync = true
            return
        }
        if (root.mutating || queryProcess.running || syncProcess.running) {
            root.syncQueued = true
            return
        }
        root.syncQueued = false
        root.syncing = true
        root.syncStatus = "syncing"
        root.syncMessage = "Synchronizing tasks"
        syncProcess.running = true
    }

    function finishSync(exitCode, output, errorOutput) {
        root.syncing = false
        if (exitCode === 0) {
            root.pendingSync = false
            root.syncStatus = "synced"
            root.syncMessage = root.cleanSyncMessage(output)
            root.lastSyncTime = new Date()
            root.refresh()
        } else {
            root.pendingSync = true
            root.syncStatus = "error"
            root.syncMessage = root.cleanError(errorOutput || output, "Unable to sync tasks")
        }
        if (root.syncQueued) {
            root.syncQueued = false
            Qt.callLater(() => root.syncNow())
        }
    }

    function addTask(fields) {
        var normalized = root.validateFields(fields)
        if (!normalized || root.busy) return false
        var command = [Commands.task, "rc.confirmation=off", "rc.verbose=nothing", "add",
            "description:" + normalized.description]
        root.appendFieldArguments(command, normalized, null)
        return root.runMutation(command, "add", "Task added", "")
    }

    function modifyTask(task, fields) {
        var uuid = String((task && task.uuid) || "")
        var normalized = root.validateFields(fields)
        if (uuid.length === 0 || !normalized || root.busy) return false
        var command = [Commands.task, "rc.confirmation=off", "rc.verbose=nothing", uuid, "modify",
            "description:" + normalized.description]
        root.appendFieldArguments(command, normalized, task)
        return root.runMutation(command, "edit", "Task updated", "")
    }

    function completeTask(uuid) {
        var taskUuid = String(uuid || "")
        if (taskUuid.length === 0 || root.busy) return false
        return root.runMutation(
            [Commands.task, "rc.confirmation=off", "rc.verbose=nothing", taskUuid, "done"],
            "complete", "Task completed", taskUuid
        )
    }

    function deleteTask(uuid) {
        var taskUuid = String(uuid || "")
        if (taskUuid.length === 0 || root.busy) return false
        return root.runMutation(
            [Commands.task, "rc.confirmation=off", "rc.verbose=nothing", taskUuid, "delete"],
            "delete", "Task deleted", ""
        )
    }

    function undoLastCompletion() {
        if (!root.canUndo || root.busy) return false
        undoTimer.stop()
        root.canUndo = false
        root.undoMessage = ""
        return root.runMutation(
            [Commands.task, "rc.confirmation=off", "rc.verbose=nothing", "undo"],
            "undo", "Completion undone", ""
        )
    }

    function runMutation(command, operation, successMessage, completingUuid) {
        if (mutationProcess.running || root.syncing) return false
        if (root.canUndo) {
            undoTimer.stop()
            root.canUndo = false
            root.undoMessage = ""
        }
        root.mutating = true
        root.errorMessage = ""
        root.noticeMessage = ""
        root.pendingSuccessMessage = successMessage
        root.currentOperation = operation
        root.completingUuid = completingUuid
        mutationProcess.command = command
        mutationProcess.running = true
        return true
    }

    function finishRefresh(exitCode, output, errorOutput) {
        root.loading = false
        root.completingUuid = ""
        if (exitCode !== 0) {
            root.errorMessage = root.cleanError(errorOutput, "Unable to load tasks")
        } else {
            try {
                var text = String(output || "").trim()
                var parsed = JSON.parse(text.length > 0 ? text : "[]")
                if (!Array.isArray(parsed)) throw new Error("Taskwarrior returned a non-array response")
                root.tasks = root.sortTasks(parsed)
                root.errorMessage = ""
                root.ready = true
            } catch (error) {
                root.errorMessage = "Invalid Taskwarrior response"
                console.warn("Failed to parse Taskwarrior export: " + error)
            }
        }
        if (root.refreshQueued) {
            root.refreshQueued = false
            root.refresh()
        } else if (root.syncQueued) {
            root.syncQueued = false
            root.syncNow()
        }
    }

    function finishMutation(exitCode, output, errorOutput) {
        var operation = root.currentOperation
        root.mutating = false
        root.currentOperation = ""
        if (exitCode !== 0) {
            root.errorMessage = root.cleanError(errorOutput || output, "Taskwarrior command failed")
            root.pendingSuccessMessage = ""
            root.completingUuid = ""
            root.mutationFinished(operation, false)
            return
        }

        root.errorMessage = ""
        root.noticeMessage = root.pendingSuccessMessage
        root.pendingSuccessMessage = ""
        root.pendingSync = root.syncConfigured
        if (operation === "complete") {
            root.canUndo = true
            root.undoMessage = "Task completed"
            undoTimer.restart()
        } else {
            root.canUndo = false
            root.undoMessage = ""
            noticeTimer.restart()
            if (root.syncConfigured) syncDebounceTimer.restart()
        }
        root.mutationFinished(operation, true)
        root.refresh()
    }

    function validateFields(fields) {
        var description = String((fields && fields.description) || "").trim()
        var due = String((fields && fields.due) || "").trim()
        var project = String((fields && fields.project) || "").trim()
        var priority = String((fields && fields.priority) || "").toUpperCase()
        if (description.length === 0) {
            root.errorMessage = "Description is required"
            return null
        }
        if (!TaskLogic.isValidDateInput(due)) {
            root.errorMessage = "Due date must be a valid YYYY-MM-DD date"
            return null
        }
        if (["", "H", "M", "L"].indexOf(priority) < 0) {
            root.errorMessage = "Priority must be H, M, or L"
            return null
        }
        return {
            description: description,
            due: due,
            project: project,
            priority: priority,
            tags: root.parseTags(fields && fields.tags)
        }
    }

    function parseTags(value) {
        return TaskLogic.parseTags(value)
    }

    function appendFieldArguments(command, fields, existingTask) {
        command.push("due:" + fields.due)
        command.push("project:" + fields.project)
        command.push("priority:" + fields.priority)
        var existingTags = root.parseTags(existingTask && existingTask.tags)
        for (var i = 0; i < existingTags.length; i++) {
            if (fields.tags.indexOf(String(existingTags[i])) < 0) command.push("-" + existingTags[i])
        }
        for (var j = 0; j < fields.tags.length; j++) {
            if (existingTags.indexOf(fields.tags[j]) < 0) command.push("+" + fields.tags[j])
        }
    }

    function cleanError(value, fallback) {
        var lines = String(value || "").split("\n")
        for (var i = 0; i < lines.length; i++) {
            var line = lines[i].trim()
            if (line.length === 0 || line.indexOf("Configuration override ") === 0) continue
            return line
        }
        return fallback
    }

    function cleanSyncMessage(value) {
        var lines = String(value || "").split("\n")
        for (var i = lines.length - 1; i >= 0; i--) {
            var line = lines[i].trim()
            if (line.length > 0 && line.indexOf("Configuration override ") !== 0) return line
        }
        return "Sync complete"
    }

    function parseDate(value) {
        return TaskLogic.parseDate(value)
    }

    function startOfDay(now) { return TaskLogic.startOfDay(now) }
    function startOfTomorrow(now) { return TaskLogic.startOfTomorrow(now) }
    function taskDue(task) { return TaskLogic.taskDue(task) }
    function dueInput(task) {
        var due = root.taskDue(task)
        return due === null ? "" : Qt.formatDate(due, "yyyy-MM-dd")
    }
    function isOverdue(task) {
        var due = root.taskDue(task)
        return due !== null && due < root.startOfDay(root.currentTime)
    }
    function isDueToday(task) {
        var due = root.taskDue(task)
        return due !== null && due >= root.startOfDay(root.currentTime) && due < root.startOfTomorrow(root.currentTime)
    }
    function dueLabel(task) {
        var due = root.taskDue(task)
        if (due === null) return ""
        if (due < root.startOfDay(root.currentTime)) return "Overdue · " + Qt.formatDate(due, "MMM d")
        if (due < root.startOfTomorrow(root.currentTime)) return "Today"
        var afterTomorrow = new Date(root.currentTime.getFullYear(), root.currentTime.getMonth(), root.currentTime.getDate() + 2)
        if (due < afterTomorrow) return "Tomorrow"
        return Qt.formatDate(due, "MMM d")
    }
    function taskContext(task) {
        var parts = []
        if (task && task.priority) parts.push("P" + task.priority)
        if (task && task.project) parts.push(String(task.project))
        if (task && Array.isArray(task.tags)) {
            for (var i = 0; i < task.tags.length; i++) parts.push("+" + task.tags[i])
        }
        return parts.join(" · ")
    }
    function countTasks(values, kind, now) {
        return TaskLogic.countTasks(values, kind, now)
    }
    function filteredTasks(values, view, now) {
        return TaskLogic.filteredTasks(values, view, now)
    }
    function priorityRank(value) {
        return TaskLogic.priorityRank(value)
    }
    function sortTasks(values) {
        return TaskLogic.sortTasks(values)
    }
}
