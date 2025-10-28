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
    readonly property bool backgroundGlassEnabled: configUtil.boolValue("backgroundGlassEnabled", false)
    readonly property real backgroundGlassIntensity: configUtil.realValue("backgroundGlassIntensity", 50, 0, 100)
    readonly property real backgroundGlassRadius: backgroundGlassEnabled
        ? configUtil.clamp(Math.round(16 + (backgroundGlassIntensity / 100) * 48), 0, 64)
        : 0
    readonly property color backgroundTintBaseColor: configUtil.colorValue("backgroundTintColor", Qt.rgba(0, 0, 0, 1))
    readonly property real backgroundTintIntensity: configUtil.realValue("backgroundTintIntensity", 0.0, 0.0, 1.0)
    readonly property color backgroundTintColor: Qt.rgba(
        backgroundTintBaseColor.r,
        backgroundTintBaseColor.g,
        backgroundTintBaseColor.b,
        Math.min(1, Math.max(0, backgroundTintIntensity))
    )
    readonly property bool hasBackgroundTint: backgroundTintColor.a > 0.001
    readonly property color controlAccentColor: configUtil.colorValue("controlAccentColor", Qt.rgba(textColor.r, textColor.g, textColor.b, 0.8))
    readonly property real controlCornerRadius: configUtil.realValue("controlCornerRadius", 16, 0, 64)
    readonly property color controlFillBase: Qt.rgba(controlAccentColor.r, controlAccentColor.g, controlAccentColor.b, 0.2)
    readonly property color controlFillHover: Qt.rgba(controlAccentColor.r, controlAccentColor.g, controlAccentColor.b, 0.28)
    readonly property color controlFillFocus: Qt.rgba(controlAccentColor.r, controlAccentColor.g, controlAccentColor.b, 0.34)
    readonly property color controlFillPressed: Qt.rgba(controlAccentColor.r, controlAccentColor.g, controlAccentColor.b, 0.42)
    readonly property color controlBorderBase: Qt.rgba(controlAccentColor.r, controlAccentColor.g, controlAccentColor.b, 0.26)
    readonly property color controlBorderActive: Qt.rgba(controlAccentColor.r, controlAccentColor.g, controlAccentColor.b, 0.62)
    readonly property int passwordFlashLoops: Math.max(1, configUtil.intValue("passwordFlashLoops", 2, 1, 6))
    readonly property int passwordFlashOnDuration: Math.max(30, configUtil.intValue("passwordFlashOnDuration", 160, 20, 1000))
    readonly property int passwordFlashOffDuration: Math.max(30, configUtil.intValue("passwordFlashOffDuration", 220, 20, 1000))
    readonly property bool allowEmptyPassword: configUtil.boolValue("allowEmptyPassword", false)
    readonly property bool showUserRealName: configUtil.boolValue("showUserRealName", false)
    readonly property bool randomizePasswordMask: configUtil.boolValue("randomizePasswordMask", false)
    readonly property url backgroundImageSource: resolveImageSource(configUtil.stringValue("backgroundImage", ""))
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
    property bool passwordVisible: false
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
    readonly property bool userSelectorVisible: showUserSelector && userCount() > 0
    readonly property bool sessionSelectorVisible: showSessionSelector && sessionCount() > 0
    readonly property bool isGlassBackgroundActive: backgroundGlassEnabled && backgroundGlassRadius > 0

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
            visible: source !== ""

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
            opacity: isGlassBackgroundActive && status === Image.Ready ? 0 : backgroundOpacity

            onStatusChanged: {
                if (status === Image.Error) {
                    console.warn("Failed to load background image:", source)
                }
            }
        }

        FastBlur {
            anchors.fill: backgroundImage
            source: backgroundImage
            radius: backgroundGlassRadius
            transparentBorder: true
            visible: isGlassBackgroundActive && backgroundImage.status === Image.Ready
            opacity: backgroundOpacity
        }

        Rectangle {
            anchors.fill: parent
            visible: hasBackgroundTint
            color: backgroundTintColor
        }

    }

    // Removed screen-edge flash; retained premium minimalism

    // Main content container
    Item {
        id: mainContent
        anchors.fill: parent

        // Login container
        Column {
            id: loginContainer
            width: Math.min(400, parent.width * 0.7)
            anchors.centerIn: parent
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
                radius: controlCornerRadius
                color: passwordInput.activeFocus
                    ? controlFillFocus
                    : passwordMouseArea.containsMouse
                        ? controlFillHover
                        : controlFillBase
                border.color: passwordInput.activeFocus ? controlBorderActive : controlBorderBase
                border.width: 1
                antialiasing: true

                onWidthChanged: updatePasswordMask()

                Behavior on color { ColorAnimation { duration: 150 } }

                Behavior on border.color {
                    ColorAnimation { duration: 200 }
                }

                // Hidden text input for actual password
                Rectangle {
                    id: passwordToggleButton
                    width: 36
                    height: 36
                    radius: width / 2
                    anchors {
                        right: parent.right
                        rightMargin: 12
                        verticalCenter: parent.verticalCenter
                    }
                    color: toggleMouse.pressed
                        ? controlFillPressed
                        : passwordVisible
                            ? controlFillFocus
                            : toggleMouse.containsMouse
                                ? controlFillHover
                                : controlFillBase
                    border.color: passwordVisible ? controlBorderActive : controlBorderBase
                    border.width: 1
                    antialiasing: true
                    z: 3

                    Behavior on color { ColorAnimation { duration: 150 } }

                    Image {
                        id: passwordToggleIcon
                        anchors.centerIn: parent
                        source: passwordVisible ? "assets/hide.svg" : "assets/show.svg"
                        sourceSize: Qt.size(18, 18)
                        asynchronous: true
                        smooth: true
                        visible: false
                    }

                    ColorOverlay {
                        anchors.fill: passwordToggleIcon
                        source: passwordToggleIcon
                        color: Qt.rgba(textColor.r, textColor.g, textColor.b, toggleMouse.containsMouse || passwordVisible ? 0.92 : 0.78)
                    }

                    MouseArea {
                        id: toggleMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: togglePasswordVisibility()
                    }
                }

                TextInput {
                    id: passwordInput
                    anchors {
                        left: parent.left
                        leftMargin: 16 + passwordToggleButton.width / 2
                        right: parent.right
                        rightMargin: 16 + passwordToggleButton.width / 2
                        top: parent.top
                        topMargin: 16
                        bottom: parent.bottom
                        bottomMargin: 16
                    }

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
                    anchors {
                        left: parent.left
                        leftMargin: 16 + passwordToggleButton.width / 2
                        right: parent.right
                        rightMargin: 16 + passwordToggleButton.width / 2
                        top: parent.top
                        topMargin: 16
                        bottom: parent.bottom
                        bottomMargin: 16
                    }

                    font.family: fontFamily
                    font.pixelSize: baseFontSize + 8
                    color: textColor
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                    text: passwordMask
                    clip: true  // Ensure text doesn't overflow
                    onWidthChanged: updatePasswordMask()
                }

                Rectangle {
                    id: passwordErrorOverlay
                    anchors.fill: parent
                    radius: controlCornerRadius
                    border.color: errorColor
                    border.width: 2
                    color: "transparent"
                    opacity: 0
                    visible: opacity > 0
                    z: 1
                }

                SequentialAnimation {
                    id: passwordErrorFlash
                    running: false
                    loops: passwordFlashLoops
                    NumberAnimation {
                        target: passwordErrorOverlay
                        property: "opacity"
                        to: 1
                        duration: passwordFlashOnDuration
                        easing.type: Easing.OutQuad
                    }
                    NumberAnimation {
                        target: passwordErrorOverlay
                        property: "opacity"
                        to: 0
                        duration: passwordFlashOffDuration
                        easing.type: Easing.InQuad
                    }
                    onStopped: passwordErrorOverlay.opacity = 0
                }

                MouseArea {
                    id: passwordMouseArea
                    anchors.fill: parent
                    hoverEnabled: true
                    acceptedButtons: Qt.NoButton
                    cursorShape: Qt.IBeamCursor
                    onEntered: passwordInput.forceActiveFocus()
                    z: 0
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
        context: Qt.ApplicationShortcut
        onActivated: toggleUserSelector()
    }

    Shortcut {
        sequences: ["Ctrl+F2", "Alt+Ctrl+U"]
        context: Qt.ApplicationShortcut
        onActivated: cycleUser(-1)
    }

    Shortcut {
        sequences: ["F3", "Alt+S"]
        context: Qt.ApplicationShortcut
        onActivated: toggleSessionSelector()
    }

    Shortcut {
        sequences: ["Ctrl+F3", "Alt+Ctrl+S"]
        context: Qt.ApplicationShortcut
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
    function setLoginError(message, overrideFlag) {
        const normalized = typeof message === "string" ? message.trim() : ""
        loginErrorMessage = normalized
        if (typeof overrideFlag === "boolean") {
            loginFailed = overrideFlag
        } else {
            loginFailed = normalized.length > 0
        }
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
        if (!userModel || userCount() === 0) {
            return
        }
        showUserSelector = !showUserSelector
    }

    function toggleSessionSelector() {
        if (!sessionModel || sessionCount() === 0) {
            return
        }
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
        passwordVisible = false
        resetPasswordMaskCache()
        updatePasswordMask()
        setLoginError("", true)

        passwordErrorFlash.stop()
        passwordErrorOverlay.opacity = 0
        passwordErrorFlash.start()
        passwordInput.forceActiveFocus()
    }

    function handleLoginSucceeded() {
        isLoginInProgress = false
        setLoginError("")
        passwordVisible = false
        passwordErrorFlash.stop()
        passwordErrorOverlay.opacity = 0
    }

    function clearError() {
        setLoginError("")
        passwordVisible = false
        passwordErrorFlash.stop()
        passwordErrorOverlay.opacity = 0
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
        const leftMargin = passwordInput.anchors && passwordInput.anchors.leftMargin !== undefined
            ? passwordInput.anchors.leftMargin
            : 16
        const rightMargin = passwordInput.anchors && passwordInput.anchors.rightMargin !== undefined
            ? passwordInput.anchors.rightMargin
            : 16
        const availableWidth = Math.max(0, passwordContainer.width - (leftMargin + rightMargin))
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

        const now = Date.now() % 2147483647

        while (passwordMaskRandomIndices.length < length) {
            const position = passwordMaskRandomIndices.length
            const seed = (now + position * 3517 + passwordInput.length * 811) % 2147483647
            const noise = ((seed ^ (seed >>> 15)) * 16807 + position * 69069 + now) % ipaChars.length
            passwordMaskRandomIndices.push(Math.abs(noise))
        }
        if (passwordMaskRandomIndices.length > length) {
            passwordMaskRandomIndices.splice(length, passwordMaskRandomIndices.length - length)
        }

        // Introduce a light shuffle on the newest tail to enhance variation
        for (var i = Math.max(0, length - 4); i < length - 1; ++i) {
            const jSeed = (now + i * 1103515245) % length
            const j = Math.max(0, Math.min(length - 1, jSeed))
            const tmp = passwordMaskRandomIndices[i]
            passwordMaskRandomIndices[i] = passwordMaskRandomIndices[j]
            passwordMaskRandomIndices[j] = tmp
        }
    }

    function resetPasswordMaskCache() {
        passwordMaskRandomIndices = []
    }

    function updatePasswordMask() {
        const textLength = passwordInput.text.length
        const capacity = maxMaskLength()
        const maskLength = Math.min(textLength, capacity)

        if (capacity <= 0) {
            passwordMask = ""
            if (textLength === 0) {
                resetPasswordMaskCache()
            }
            return
        }

        if (passwordVisible) {
            const startIndex = Math.max(0, textLength - capacity)
            const visibleTail = passwordInput.text.slice(startIndex, textLength)
            passwordMask = centerMask(visibleTail, capacity)
            if (textLength === 0) {
                resetPasswordMaskCache()
            }
            return
        }

        if (randomizePasswordMask) {
            ensureRandomMaskCapacity(textLength)
            var randomizedMask = ""
            const startIndex = Math.max(0, textLength - maskLength)
            for (var randomIndex = 0; randomIndex < maskLength; ++randomIndex) {
                randomizedMask += ipaChars[passwordMaskRandomIndices[startIndex + randomIndex] % ipaChars.length]
            }
            passwordMask = centerMask(randomizedMask, capacity)
        } else {
            var deterministicMask = ""
            const startIndex = Math.max(0, textLength - maskLength)
            for (var index = 0; index < maskLength; ++index) {
                var code = passwordInput.text.charCodeAt(startIndex + index)
                if (!isFinite(code)) {
                    code = 0
                }
                deterministicMask += ipaChars[code % ipaChars.length]
            }
            passwordMask = centerMask(deterministicMask, capacity)
        }

        if (textLength === 0) {
            resetPasswordMaskCache()
        }
    }

    function centerMask(maskString, capacity) {
        if (capacity <= 0) {
            return ""
        }

        const lengthDifference = capacity - maskString.length
        if (lengthDifference <= 0) {
            return maskString
        }

        const padding = Math.floor(lengthDifference / 2)
        const needsExtra = lengthDifference % 2
        var paddingChars = ""
        for (var padIndex = 0; padIndex < padding; ++padIndex) {
            paddingChars += " "
        }
        var centered = paddingChars + maskString + paddingChars
        if (needsExtra) {
            centered += " "
        }
        return centered
    }

    function togglePasswordVisibility() {
        passwordVisible = !passwordVisible
        updatePasswordMask()
    }

    // Custom components
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

        Rectangle {
            id: prevButton
            width: 34
            height: 34
            radius: width / 2
            anchors {
                left: parent.left
                leftMargin: 8
                verticalCenter: parent.verticalCenter
            }
            color: prevMouseArea.pressed
                ? controlFillPressed
                : prevMouseArea.containsMouse
                    ? controlFillHover
                    : controlFillBase
            border.color: controlBorderBase
            border.width: 1
            antialiasing: true

            Behavior on color { ColorAnimation { duration: 150 } }

            Text {
                anchors.centerIn: parent
                anchors.verticalCenterOffset: -2
                text: baseSelector.prevText
                color: textColor
                font.family: baseSelector.fontFamily
                font.pointSize: baseSelector.fontPointSize
            }

            MouseArea {
                id: prevMouseArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: baseSelector.prevClicked()
            }
        }

        Rectangle {
            id: nextButton
            width: 34
            height: 34
            radius: width / 2
            anchors {
                right: parent.right
                rightMargin: 8
                verticalCenter: parent.verticalCenter
            }
            color: nextMouseArea.pressed
                ? controlFillPressed
                : nextMouseArea.containsMouse
                    ? controlFillHover
                    : controlFillBase
            border.color: controlBorderBase
            border.width: 1
            antialiasing: true

            Behavior on color { ColorAnimation { duration: 150 } }

            Text {
                anchors.centerIn: parent
                anchors.verticalCenterOffset: -2
                text: baseSelector.nextText
                color: textColor
                font.family: baseSelector.fontFamily
                font.pointSize: baseSelector.fontPointSize
            }

            MouseArea {
                id: nextMouseArea
                anchors.fill: parent
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
        radius: controlCornerRadius

        color: mouseArea.pressed
            ? controlFillPressed
            : mouseArea.containsMouse
                ? controlFillHover
                : controlFillBase

        border.color: mouseArea.pressed || mouseArea.containsMouse
            ? controlBorderActive
            : controlBorderBase
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
