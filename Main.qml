import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQml 2.15
import SddmComponents 2.0
import Qt5Compat.GraphicalEffects

Rectangle {
    id: root

    QtObject {
        id: configUtil

        function stringValue(key, fallback) {
            const value = config.stringValue(key)
            if (typeof value !== "string") {
                return fallback
            }
            var trimmed = value.trim()
            const commentIndex = trimmed.search(/\s#/)
            if (commentIndex >= 0) {
                trimmed = trimmed.slice(0, commentIndex).trim()
            }
            return trimmed.length > 0 ? trimmed : fallback
        }

        function colorValue(key, fallback) {
            const candidate = stringValue(key, "")
            if (!candidate) {
                return fallback
            }
            const normalized = candidate.trim()
            try {
                Qt.darker(normalized, 1.0)
                return normalized
            } catch (error) {
                console.warn("Invalid color for", key, ":", candidate, "- falling back to", fallback)
                return fallback
            }
        }

        function boolValue(key, fallback) {
            const value = config.boolValue(key)
            if (typeof value === "boolean") {
                return value
            }
            if (typeof value === "string") {
                const lowered = value.toLowerCase()
                if (lowered === "true") return true
                if (lowered === "false") return false
            }
            return fallback
        }

        function clamp(value, min, max) {
            if (!isFinite(value)) {
                return min
            }
            return Math.max(min, Math.min(max, value))
        }

        function intValue(key, fallback, min, max) {
            const raw = config.intValue(key)
            const numeric = Number(raw)
            if (!isFinite(numeric)) {
                return fallback
            }
            if (typeof min === "number" && typeof max === "number") {
                return clamp(Math.round(numeric), min, max)
            }
            return Math.round(numeric)
        }

        function realValue(key, fallback, min, max) {
            const raw = config.realValue(key)
            const numeric = Number(raw)
            if (!isFinite(numeric)) {
                return fallback
            }
            if (typeof min === "number" && typeof max === "number") {
                return clamp(numeric, min, max)
            }
            return numeric
        }
    }

    // Constants
    readonly property color textColor: configUtil.colorValue("textColor", "#ffffff")
    readonly property color errorColor: configUtil.colorValue("errorColor", "#ff4444")
    readonly property color backgroundColor: configUtil.colorValue("backgroundColor", "#000000")
    readonly property string fontFamily: configUtil.stringValue("fontFamily", "Inter")
    readonly property int baseFontSize: configUtil.intValue("baseFontSize", 14, 12, 18)
    readonly property int animationDuration: configUtil.intValue("animationDuration", 300, 0, 5000)
    readonly property int sessionsFontSize: configUtil.intValue("sessionsFontSize", 24, 14, 64)
    readonly property real backgroundOpacity: configUtil.realValue("backgroundOpacity", 0.8, 0, 1)
    readonly property bool backgroundBlurEnabled: configUtil.boolValue("backgroundBlurEnabled", false)
    readonly property real backgroundBlurRadius: configUtil.realValue("backgroundBlurRadius", 0, 0, 64)
    readonly property bool allowEmptyPassword: configUtil.boolValue("allowEmptyPassword", false)
    readonly property bool showUserRealName: configUtil.boolValue("showUserRealName", false)
    readonly property bool randomizePasswordMask: configUtil.boolValue("randomizePasswordMask", false)
    readonly property url backgroundImageSource: resolveImageSource(configUtil.stringValue("backgroundImage", ""))
    readonly property bool glassmorphismEnabled: configUtil.boolValue("glassmorphismEnabled", true)
    readonly property real glassBlurRadius: configUtil.realValue("glassBlurRadius", 36, 0, 64)
    readonly property real glassCornerRadius: configUtil.realValue("glassCornerRadius", 26, 0, 64)
    readonly property color glassTintColor: Qt.rgba(1, 1, 1, 0.12)
    readonly property color glassBorderColor: Qt.rgba(1, 1, 1, 0.28)
    readonly property color glassHighlightColor: Qt.rgba(1, 1, 1, 0.32)
    readonly property var ipaChars: [
    "ɐ", "ɑ", "ɒ", "æ", "ɓ", "ʙ", "β", "ɔ", "ɕ", "ç", "ɗ", "ɖ", "ð", "ʤ", "ə", "ɘ",
    "ɚ", "ɛ", "ɜ", "ɝ", "ɞ", "ɟ", "ʄ", "ɡ", "ɠ", "ɢ", "ʛ", "ɦ", "ɧ", "ħ", "ɥ", "ʜ",
    "ɨ", "ɪ", "ʝ", "ɟ", "ʄ", "ɫ", "ɬ", "ɭ", "ɮ", "ʟ", "ɰ", "ɱ", "ɯ", "ɲ", "ɳ", "ɴ",
    "ŋ", "ɵ", "ɶ", "ɷ", "ɸ", "ʂ", "ʃ", "ʅ", "ʆ", "ʇ", "θ", "ʉ", "ʊ", "ʋ", "ʌ", "ɣ",
    "ɤ", "ʍ", "χ", "ʎ", "ʏ", "ʐ", "ʑ", "ʒ", "ʓ", "ʔ", "ʕ", "ʖ", "ʗ", "ʘ", "ʙ", "ʚ"
    ]
    // State management
    property int currentUserIndex: {
        const count = userCount()
        if (count === 0) {
            return 0
        }
        if (userModel && typeof userModel.lastIndex === "number") {
            return clampIndex(userModel.lastIndex, count)
        }
        return 0
    }
    property bool isLoginInProgress: false
    property bool showSessionSelector: configUtil.boolValue("showSessionSelector", false)
    property bool showUserSelector: configUtil.boolValue("showUserSelector", false)
    property bool loginFailed: false
    property string loginErrorMessage: ""
    property string passwordMask: ""
    property var passwordMaskRandomIndices: []
    property int currentSessionsIndex: {
        const sessions = sessionCount()
        if (sessions === 0) {
            return 0
        }
        if (sessionModel && typeof sessionModel.lastIndex === "number") {
            return clampIndex(sessionModel.lastIndex, sessions)
        }
        return 0
    }

    // Constants for roles
    readonly property int sessionNameRole: Qt.UserRole + 4
    readonly property int userNameRole: Qt.UserRole + 1

    // Computed properties
    readonly property string currentUsername: getCurrentUsername()
    readonly property string currentSession: getCurrentSession()
    readonly property bool hasMultipleUsers: userCount() > 1
    readonly property bool hasMultipleSessions: sessionCount() > 1
    readonly property bool userSelectorVisible: showUserSelector && hasMultipleUsers
    readonly property bool sessionSelectorVisible: showSessionSelector && hasMultipleSessions
    readonly property bool isBackgroundBlurActive: backgroundBlurEnabled && backgroundBlurRadius > 0 && !glassmorphismEnabled

    anchors.fill: parent

    // Background
    Rectangle {
        id: backgroundLayer
        anchors.fill: parent
        color: backgroundColor

        Image {
            id: backgroundImage
            anchors.fill: parent
            source: backgroundImageSource
            visible: source !== "" && status === Image.Ready

            fillMode: {
                if (source === "") return Image.Stretch;
                switch(configUtil.stringValue("backgroundFillMode", "")) {
                    case "stretch": return Image.Stretch;
                    case "tile": return Image.Tile;
                    case "center": return Image.Pad;
                    case "aspectFit": return Image.PreserveAspectFit;
                    default: return Image.PreserveAspectCrop;
                }
            }
            smooth: true
            cache: true
            asynchronous: true
            opacity: isBackgroundBlurActive ? 0 : backgroundOpacity

            onStatusChanged: {
                if (status === Image.Error) {
                    console.warn("Failed to load background image:", source)
                }
            }
        }

        FastBlur {
            anchors.fill: backgroundImage
            source: backgroundImage
            radius: isBackgroundBlurActive ? backgroundBlurRadius : 0
            transparentBorder: true
            visible: isBackgroundBlurActive && backgroundImage.status === Image.Ready
            opacity: backgroundOpacity
        }
    }

    // Error border overlay
    Rectangle {
        id: errorBorder
        anchors.fill: parent
        color: "transparent"
        border.color: errorColor
        border.width: 0
        radius: 8
        opacity: 0.8

        Behavior on border.width {
            NumberAnimation {
                duration: animationDuration
                easing.type: Easing.OutCubic
            }
        }
    }

    // Main content container
    Item {
        id: mainContent
        anchors.fill: parent

        // Login container with glassmorphism panel
        Item {
            id: loginPanel
            width: Math.min(420, parent.width * 0.7)
            height: loginContainer.implicitHeight + glassPanelPadding * 2
            anchors.centerIn: parent

            readonly property bool glassPanelActive: glassmorphismEnabled && (backgroundImage.status === Image.Ready || backgroundImage.status === Image.Error || backgroundImage.source === "")
            readonly property int glassPanelPadding: glassPanelActive ? 24 : 0

            DropShadow {
                id: loginPanelShadow
                anchors.fill: glassSurface
                source: glassSurface
                visible: glassSurface.visible
                horizontalOffset: 0
                verticalOffset: 18
                samples: 24
                radius: 32
                spread: 0.08
                color: Qt.rgba(0, 0, 0, 0.35)
                transparentBorder: true
                z: -3
            }

            GlassPanel {
                id: glassSurface
                anchors.fill: parent
                visible: loginPanel.glassPanelActive
                target: backgroundLayer
                blurRadius: glassBlurRadius
                tintColor: glassTintColor
                borderColor: glassBorderColor
                highlightColor: glassHighlightColor
                cornerRadius: glassCornerRadius
                z: -2
            }

            Column {
                id: loginContainer
                width: Math.max(0, parent.width - loginPanel.glassPanelPadding * 2)
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.top: parent.top
                anchors.topMargin: loginPanel.glassPanelPadding
                spacing: 28

                // User selector
                UserSelector {
                    id: userSelector
                    visible: userSelectorVisible
                    width: parent.width
                    currentUser: currentUsername
                    onUserChanged: cycleUser(direction)
                    height: 40
                    fontFamily: root.fontFamily
                    fontPointSize: root.baseFontSize + 2
                }

                // Password input
                Rectangle {
                    id: passwordContainer
                    width: parent.width
                    height: 56
                    color: Qt.rgba(1, 1, 1, 0)
                    radius: 12
                    border.color: passwordInput.activeFocus ? Qt.rgba(textColor.r, textColor.g, textColor.b, 0.9) : Qt.rgba(1, 1, 1, 0.18)
                    border.width: 1

                    onWidthChanged: updatePasswordMask()

                    Behavior on border.color {
                        ColorAnimation { duration: 200 }
                    }

                    // Hidden text input for actual password
                    TextInput {
                        id: passwordInput
                        anchors.fill: parent
                        anchors.margins: 16

                        font.family: fontFamily
                        font.pixelSize: baseFontSize + 8
                        color: "transparent"
                        echoMode: TextInput.NoEcho
                        selectByMouse: false
                        selectionColor: "transparent"
                        selectedTextColor: "transparent"
                        cursorVisible: false
                        cursorDelegate: Item {
                            visible: false
                            width: 0
                            height: 0
                        }
                        focus: true
                        enabled: !isLoginInProgress

                        onAccepted: attemptLogin()
                        onTextChanged: {
                            if (loginFailed) {
                                clearError()
                            }
                            updatePasswordMask()
                        }

                        Keys.onEscapePressed: {
                            clear()
                            resetPasswordMaskCache()
                            updatePasswordMask()
                        }
                    }

                    // Visible display of IPA characters
                    Text {
                        id: passwordDisplay
                        anchors.fill: parent
                        anchors.margins: 16

                        font.family: fontFamily
                        font.pixelSize: baseFontSize + 8
                        color: textColor
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                        text: passwordMask
                        clip: true  // Ensure text doesn't overflow
                        onWidthChanged: updatePasswordMask()
                    }
                }

                // Error message
                Text {
                    id: errorMessage
                    width: parent.width
                    visible: loginFailed && loginErrorMessage.length > 0
                    text: loginErrorMessage
                    color: errorColor
                    font.family: fontFamily
                    font.pixelSize: baseFontSize - 1
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.WordWrap

                    opacity: visible ? 1 : 0
                    Behavior on opacity {
                        NumberAnimation { duration: animationDuration }
                    }
                }

                // Session selector
                SessionSelector {
                    id: sessionSelector
                    text: currentSession
                    visible: sessionSelectorVisible
                    width: parent.width
                    height: 40
                    fontFamily: root.fontFamily
                    fontPointSize: root.baseFontSize + 2

                    onPrevClicked: sessionsCycleSelectPrev()
                    onNextClicked: sessionsCycleSelectNext()
                }
            }
        }

        // Power controls (centered at bottom)
        Row {
            id: powerControls
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 20
            spacing: 12

            PowerButton {
                id: suspendButton
                visible: sddm.canSuspend
                iconSource: "./assets/suspend.svg"
                tooltip: "Suspend"
                onClicked: sddm.suspend()
            }

            PowerButton {
                id: rebootButton
                visible: sddm.canReboot
                iconSource: "./assets/reboot.svg"
                tooltip: "Reboot"
                onClicked: sddm.reboot()
            }

            PowerButton {
                id: shutdownButton
                visible: sddm.canPowerOff
                iconSource: "./assets/shutdown.svg"
                tooltip: "Shutdown"
                onClicked: sddm.powerOff()
            }
        }

        // Keyboard shortcuts help
        Text {
            id: helpText
            visible: false
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.margins: 20

            text: "F1: Toggle help • F2: Users • F3: Sessions • F10: Suspend • F11: Shutdown • F12: Reboot"
            color: Qt.rgba(textColor.r, textColor.g, textColor.b, 0.7)
            font.family: fontFamily
            font.pixelSize: baseFontSize - 2
        }
    }

    // Keyboard shortcuts
    Shortcut {
        sequence: "F1"
        onActivated: helpText.visible = !helpText.visible
    }

    Shortcut {
        sequences: ["F2", "Alt+U"]
        onActivated: toggleUserSelector()
    }

    Shortcut {
        sequences: ["Ctrl+F2", "Alt+Ctrl+U"]
        onActivated: cycleUser(-1)
    }

    Shortcut {
        sequences: ["F3", "Alt+S"]
        onActivated: toggleSessionSelector()
    }

    Shortcut {
        sequences: ["Ctrl+F3", "Alt+Ctrl+S"]
        onActivated: sessionsCycleSelectPrev()
    }

    Shortcut {
        sequence: "F10"
        onActivated: if (sddm.canSuspend) sddm.suspend()
    }

    Shortcut {
        sequence: "F11"
        onActivated: if (sddm.canPowerOff) sddm.powerOff()
    }

    Shortcut {
        sequence: "F12"
        onActivated: if (sddm.canReboot) sddm.reboot()
    }

    // SDDM event handlers
    Connections {
        target: sddm

        function onLoginFailed() {
            handleLoginFailed()
        }

        function onLoginSucceeded() {
            handleLoginSucceeded()
        }
    }

    // Component initialization
    Component.onCompleted: {
        if (userCount() > 0) {
            passwordInput.forceActiveFocus()
        }
        validateConfiguration()
        updatePasswordMask()
        console.log("Theme initialized. Background:", backgroundImage.source)
    }

    // Helper functions
    function setLoginError(message) {
        const normalized = typeof message === "string" ? message.trim() : ""
        loginErrorMessage = normalized
        loginFailed = normalized.length > 0
    }

    function userCount() {
        if (!userModel || typeof userModel.count !== "number") {
            return 0
        }
        return userModel.count
    }

    function sessionCount() {
        if (!sessionModel || typeof sessionModel.rowCount !== "function") {
            return 0
        }
        return sessionModel.rowCount()
    }

    function clampIndex(value, size) {
        if (size <= 0) {
            return 0
        }
        const numeric = Number(value)
        if (!isFinite(numeric)) {
            return 0
        }
        const index = Math.floor(numeric)
        if (index < 0) {
            return 0
        }
        if (index >= size) {
            return size - 1
        }
        return index
    }

    function getCurrentUsername() {
        const count = userCount()
        if (count === 0 || currentUserIndex < 0 || currentUserIndex >= count) {
            return "Unknown User"
        }
        return userModel.data(userModel.index(currentUserIndex, 0), userNameRole) || "Unknown User"
    }

    function getCurrentSession() {
        const sessions = sessionCount()
        if (sessions === 0 || currentSessionsIndex < 0 || currentSessionsIndex >= sessions) {
            return "Unknown Session"
        }
        return sessionModel.data(sessionModel.index(currentSessionsIndex, 0), sessionNameRole) || "Unknown Session"
    }

    function getBackgroundFillMode() {
        const mode = configUtil.stringValue("backgroundFillMode", "")
        switch (mode) {
            case "stretch": return Image.Stretch
            case "tile": return Image.Tile
            case "center": return Image.Pad
            case "aspectFit": return Image.PreserveAspectFit
            case "aspectCrop":
            default: return Image.PreserveAspectCrop
        }
    }

    function resolveImageSource(path) {
        if (typeof path !== "string") {
            return ""
        }

        var normalized = path.trim()
        if (!normalized.length) {
            return ""
        }

        if (normalized.startsWith("file:/") || normalized.indexOf("://") !== -1 || normalized.startsWith("qrc:")) {
            return normalized
        }

        if (normalized.startsWith("~")) {
            console.warn("Background image path uses '~' which cannot be expanded automatically:", normalized)
            return ""
        }

        if (/^[a-zA-Z]:[\\/]/.test(normalized)) {
            const normalizedWindowsPath = normalized.replace(/\\/g, "/")
            return "file:///" + normalizedWindowsPath
        }

        if (normalized.startsWith("/")) {
            return "file://" + normalized
        }

        return Qt.resolvedUrl(normalized)
    }

    function cycleUser(direction) {
        if (!hasMultipleUsers) return

        const count = userCount()
        const newIndex = direction > 0
            ? (currentUserIndex + 1) % count
            : (currentUserIndex - 1 + count) % count

        currentUserIndex = newIndex
        ensureValidUserIndex()
    }

    function sessionsCycleSelectPrev() {
        if (!hasMultipleSessions) return
        const sessions = sessionCount()
        currentSessionsIndex = currentSessionsIndex > 0 ? currentSessionsIndex - 1 : sessions - 1
        ensureValidSessionIndex()
    }

    function sessionsCycleSelectNext() {
        if (!hasMultipleSessions) return
        const sessions = sessionCount()
        currentSessionsIndex = currentSessionsIndex < sessions - 1 ? currentSessionsIndex + 1 : 0
        ensureValidSessionIndex()
    }

    function toggleUserSelector() {
        if (!hasMultipleUsers) return
        showUserSelector = !showUserSelector
    }

    function toggleSessionSelector() {
        if (!hasMultipleSessions) return
        showSessionSelector = !showSessionSelector
    }

    function attemptLogin() {
        if (isLoginInProgress) {
            return
        }

        const users = userCount()
        if (users === 0) {
            setLoginError("No user accounts are available.")
            return
        }

        const sessions = sessionCount()
        if (sessions === 0) {
            setLoginError("No sessions are available.")
            return
        }

        const password = passwordInput.text || ""
        if (!password.length && !allowEmptyPassword) {
            setLoginError("Password is required.")
            return
        }

        const username = userModel.data(userModel.index(clampIndex(currentUserIndex, users), 0), userNameRole) || ""
        const sessionIndex = clampIndex(currentSessionsIndex, sessions)

        setLoginError("")
        isLoginInProgress = true
        sddm.login(username, password, sessionIndex)
    }

    function handleLoginFailed() {
        if (!isLoginInProgress) return

        isLoginInProgress = false
        passwordInput.clear()
        resetPasswordMaskCache()
        updatePasswordMask()
        setLoginError("Incorrect credentials. Please try again.")

        errorBorder.border.width = 3
        errorBorderTimer.restart()
        passwordInput.forceActiveFocus()
    }

    function handleLoginSucceeded() {
        isLoginInProgress = false
        setLoginError("")
        errorBorder.border.width = 0
    }

    function clearError() {
        setLoginError("")
        errorBorder.border.width = 0
        errorBorderTimer.stop()
    }

    function validateConfiguration() {
        if (!userModel) {
            console.error("User model not available")
            return
        }

        if (!sessionModel) {
            console.error("Session model not available")
            return
        }

        // Ensure valid indices
        ensureValidUserIndex()
        ensureValidSessionIndex()
    }

    // Error border reset timer
    Timer {
        id: errorBorderTimer
        interval: 2000
        repeat: false
        onTriggered: errorBorder.border.width = 0
    }

    function ensureValidUserIndex() {
        const count = userCount()
        if (count === 0) {
            currentUserIndex = 0
            return
        }
        currentUserIndex = clampIndex(currentUserIndex, count)
    }

    function ensureValidSessionIndex() {
        const sessions = sessionCount()
        if (sessions === 0) {
            currentSessionsIndex = 0
            return
        }
        currentSessionsIndex = clampIndex(currentSessionsIndex, sessions)
    }

    function maxMaskLength() {
        const availableWidth = Math.max(0, passwordContainer.width - 32)
        const charWidth = (baseFontSize + 8) * 0.7
        const capacity = Math.floor(availableWidth / Math.max(1, charWidth))
        return Math.max(0, capacity)
    }

    function ensureRandomMaskCapacity(length) {
        if (!Array.isArray(passwordMaskRandomIndices)) {
            passwordMaskRandomIndices = []
        }
        if (length <= 0) {
            passwordMaskRandomIndices = []
            return
        }
        while (passwordMaskRandomIndices.length < length) {
            passwordMaskRandomIndices.push(Math.floor(Math.random() * ipaChars.length))
        }
        if (passwordMaskRandomIndices.length > length) {
            passwordMaskRandomIndices.splice(length, passwordMaskRandomIndices.length - length)
        }
    }

    function resetPasswordMaskCache() {
        passwordMaskRandomIndices = []
    }

    function updatePasswordMask() {
        const textLength = passwordInput.text.length
        const maskLength = Math.min(textLength, maxMaskLength())

        if (randomizePasswordMask) {
            ensureRandomMaskCapacity(textLength)
            var randomizedMask = ""
            for (var randomIndex = 0; randomIndex < maskLength; ++randomIndex) {
                randomizedMask += ipaChars[passwordMaskRandomIndices[randomIndex] % ipaChars.length]
            }
            passwordMask = randomizedMask
        } else {
            var deterministicMask = ""
            for (var index = 0; index < maskLength; ++index) {
                var code = passwordInput.text.charCodeAt(index)
                if (!isFinite(code)) {
                    code = 0
                }
                deterministicMask += ipaChars[code % ipaChars.length]
            }
            passwordMask = deterministicMask
        }

        if (textLength === 0) {
            resetPasswordMaskCache()
        }
    }

    // Custom components
    component GlassPanel: Item {
        id: glassPanel

        property Item target: null
        property real blurRadius: 32
        property color tintColor: Qt.rgba(1, 1, 1, 0.1)
        property color borderColor: Qt.rgba(1, 1, 1, 0.25)
        property color highlightColor: Qt.rgba(1, 1, 1, 0.3)
        property real cornerRadius: 24

        z: -1
        clip: false

        function calculateSourceRect() {
            if (!target) {
                return Qt.rect(0, 0, width, height)
            }
            const topLeft = glassPanel.mapToItem(target, 0, 0)
            return Qt.rect(topLeft.x, topLeft.y, width, height)
        }

        ShaderEffectSource {
            id: glassSource
            anchors.fill: parent
            visible: glassPanel.visible && glassPanel.target
            live: true
            recursive: false
            sourceItem: glassPanel.target
            sourceRect: {
                glassPanel.x; glassPanel.y;
                return glassPanel.calculateSourceRect()
            }
        }

        FastBlur {
            anchors.fill: parent
            source: glassSource
            radius: blurRadius
            transparentBorder: true
            visible: glassSource.visible
        }

        Rectangle {
            anchors.fill: parent
            radius: cornerRadius
            color: tintColor
        }

        Rectangle {
            anchors.fill: parent
            radius: cornerRadius
            color: "transparent"
            gradient: Gradient {
                GradientStop { position: 0.0; color: Qt.rgba(highlightColor.r, highlightColor.g, highlightColor.b, Math.min(1, highlightColor.a + 0.1)) }
                GradientStop { position: 0.4; color: Qt.rgba(highlightColor.r, highlightColor.g, highlightColor.b, highlightColor.a * 0.35) }
                GradientStop { position: 1.0; color: Qt.rgba(highlightColor.r, highlightColor.g, highlightColor.b, 0.0) }
            }
            opacity: 0.7
            visible: glassSource.visible
        }

        Rectangle {
            anchors.fill: parent
            radius: cornerRadius
            color: "transparent"
            border.color: borderColor
            border.width: 1
            opacity: 0.8
        }
    }

    component BaseSelector: Item {
        id: baseSelector

        property string text: ""
        property string prevText: "‹"
        property string nextText: "›"
        property int fontPointSize: baseFontSize + 2
        property string fontFamily: root.fontFamily

        signal prevClicked()
        signal nextClicked()

        implicitWidth: Math.max(mainText.implicitWidth + 80)
        implicitHeight: 40

        Rectangle {
            anchors.fill: parent
            color: "transparent"
            radius: 8
            border.color: Qt.rgba(1, 1, 1, 0.1)
            border.width: 0
        }

        Text {
            id: mainText
            anchors.centerIn: parent
            font.family: baseSelector.fontFamily
            font.pointSize: baseSelector.fontPointSize
            color: textColor
            text: baseSelector.text
            elide: Text.ElideRight
            maximumLineCount: 1
        }

        Text {
            id: prevButton
            anchors {
                left: parent.left
                leftMargin: 12
                verticalCenter: parent.verticalCenter
            }
            text: baseSelector.prevText
            color: prevMouseArea.containsMouse ? Qt.lighter(textColor) : textColor
            font.family: baseSelector.fontFamily
            font.pointSize: baseSelector.fontPointSize + 2

            MouseArea {
                id: prevMouseArea
                anchors.fill: parent
                anchors.margins: -8
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: baseSelector.prevClicked()
            }
        }

        Text {
            id: nextButton
            anchors {
                right: parent.right
                rightMargin: 12
                verticalCenter: parent.verticalCenter
            }
            text: baseSelector.nextText
            color: nextMouseArea.containsMouse ? Qt.lighter(textColor) : textColor
            font.family: baseSelector.fontFamily
            font.pointSize: baseSelector.fontPointSize + 2

            MouseArea {
                id: nextMouseArea
                anchors.fill: parent
                anchors.margins: -8
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: baseSelector.nextClicked()
            }
        }
    }

    component UserSelector: BaseSelector {
        property string currentUser: ""
        signal userChanged(int direction)

        text: currentUser
        onPrevClicked: userChanged(-1)
        onNextClicked: userChanged(1)
    }

    component SessionSelector: BaseSelector {
        text: currentSession
        fontPointSize: sessionsFontSize
    }

    component PowerButton: Rectangle {
        property string iconSource: ""
        property string tooltip: ""
        signal clicked()

        width: 48
        height: 48
        radius: 22

        color: mouseArea.pressed
            ? Qt.rgba(1, 1, 1, 0.3)
            : mouseArea.containsMouse
                ? Qt.rgba(1, 1, 1, 0.2)
                : Qt.rgba(1, 1, 1, 0.1)

        border.color: Qt.rgba(1, 1, 1, 0.2)
        border.width: 1

        Behavior on color { ColorAnimation { duration: 150 } }

        Image {
            anchors.centerIn: parent
            source: parent.iconSource
            sourceSize: Qt.size(26, 26)
            fillMode: Image.PreserveAspectFit
            smooth: true
            antialiasing: true
        }

        MouseArea {
            id: mouseArea
            anchors.fill: parent
            hoverEnabled: true
            onClicked: parent.clicked()
        }
    }
}
