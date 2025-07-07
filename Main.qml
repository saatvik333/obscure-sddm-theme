import QtQuick 2.15
import QtQuick.Controls 2.15
import SddmComponents 2.0

Rectangle {
    id: root

    // Constants
    readonly property color textColor: config.stringValue("textColor") || "#ffffff"
    readonly property color errorColor: config.stringValue("errorColor") || "#ff4444"
    readonly property color backgroundColor: config.stringValue("backgroundColor") || "#000000"
    readonly property string fontFamily: config.stringValue("fontFamily") || "Inter"
    readonly property int baseFontSize: Math.max(12, Math.min(18, config.intValue("baseFontSize") || 14))
    readonly property int animationDuration: config.intValue("animationDuration") || 300
    readonly property int sessionsFontSize: config.intValue("sessionsFontSize") || 24
    readonly property real backgroundOpacity: config.realValue("backgroundOpacity") || 0.8
    readonly property bool allowEmptyPassword: config.boolValue("allowEmptyPassword") || false
    readonly property bool showUserRealName: config.boolValue("showUserRealName") || false
    readonly property var ipaChars: [
    "ɐ", "ɑ", "ɒ", "æ", "ɓ", "ʙ", "β", "ɔ", "ɕ", "ç", "ɗ", "ɖ", "ð", "ʤ", "ə", "ɘ",
    "ɚ", "ɛ", "ɜ", "ɝ", "ɞ", "ɟ", "ʄ", "ɡ", "ɠ", "ɢ", "ʛ", "ɦ", "ɧ", "ħ", "ɥ", "ʜ",
    "ɨ", "ɪ", "ʝ", "ɟ", "ʄ", "ɫ", "ɬ", "ɭ", "ɮ", "ʟ", "ɰ", "ɱ", "ɯ", "ɲ", "ɳ", "ɴ",
    "ŋ", "ɵ", "ɶ", "ɷ", "ɸ", "ʂ", "ʃ", "ʅ", "ʆ", "ʇ", "θ", "ʉ", "ʊ", "ʋ", "ʌ", "ɣ",
    "ɤ", "ʍ", "χ", "ʎ", "ʏ", "ʐ", "ʑ", "ʒ", "ʓ", "ʔ", "ʕ", "ʖ", "ʗ", "ʘ", "ʙ", "ʚ"
    ]
    // State management
    property int currentUserIndex: {
        if (userModel && userModel.lastIndex !== undefined) {
            return userModel.lastIndex;
        }
        return 0;
    }
    property bool isLoginInProgress: false
    property bool showSessionSelector: config.boolValue("showSessionSelector") || false
    property bool showUserSelector: config.boolValue("showUserSelector") || false
    property bool loginFailed: false
    property int currentSessionsIndex: sessionModel?.lastIndex ?? 0

    // Constants for roles
    readonly property int sessionNameRole: Qt.UserRole + 4
    readonly property int userNameRole: Qt.UserRole + 1

    // Computed properties
    readonly property string currentUsername: getCurrentUsername()
    readonly property string currentSession: getCurrentSession()
    readonly property bool hasMultipleUsers: userModel?.count > 1
    readonly property bool hasMultipleSessions: sessionModel?.rowCount() > 1

    anchors.fill: parent

    // Background
    Rectangle {
        id: backgroundLayer
        anchors.fill: parent
        color: backgroundColor

        Image {
            id: backgroundImage
            anchors.fill: parent
            source: config.stringValue("backgroundImage") || ""
            visible: source !== ""  // Only show if we have a source

            fillMode: {
                if (source === "") return Image.Stretch;
                switch(config.stringValue("backgroundFillMode")) {
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
            opacity: backgroundOpacity

            onStatusChanged: {
                if (status === Image.Error) {
                    console.warn("Failed to load background image:", source)
                }
            }
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

        // Login container
        Column {
            id: loginContainer
            width: Math.min(400, parent.width * 0.7)
            anchors.centerIn: parent
            spacing: 28

            // User selector
            UserSelector {
                id: userSelector
                visible: showUserSelector
                width: parent.width
                currentUser: currentUsername
                onUserChanged: cycleUser(direction)
                height: 40
                fontFamily: root.fontFamily
                fontPointSize: root.baseFontSize + 2
            }

            // Password input
                        // Replace the passwordContainer with this implementation
            Rectangle {
                id: passwordContainer
                width: parent.width
                height: 56
                color: Qt.rgba(1, 1, 1, 0)
                radius: 8
                border.color: passwordInput.activeFocus ? textColor : Qt.rgba(1, 1, 1, 0.2)
                border.width: 1

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
                    cursorVisible: true
                    focus: true

                    onAccepted: attemptLogin()
                    onTextChanged: clearError()

                    Keys.onEscapePressed: clear()
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
                    text: {
                        var displayText = ""
                        // Limit the number of characters based on container width
                        var maxChars = Math.floor((width - 8) / (font.pixelSize * 0.7))
                        var length = Math.min(passwordInput.text.length, maxChars)
                        for (var i = 0; i < length; i++) {
                            var randomIndex = Math.floor(Math.random() * ipaChars.length)
                            displayText += ipaChars[randomIndex]
                        }
                        return displayText
                    }
                    clip: true  // Ensure text doesn't overflow
                }
            }

            // Error message
            Text {
                id: errorMessage
                width: parent.width
                visible: loginFailed
                text: ">_> FUCK OFF!!"
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
                visible: showSessionSelector  // Use config-controlled property
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
        passwordInput.forceActiveFocus()
        validateConfiguration()
        console.log("Theme initialized. Background:", backgroundImage.source)
    }

    // Helper functions
    function getCurrentUsername() {
        if (!userModel || currentUserIndex < 0 || currentUserIndex >= userModel.count) {
            return "Unknown User"
        }
        return userModel.data(userModel.index(currentUserIndex, 0), userNameRole) || "Unknown User"
    }

    function getCurrentSession() {
        if (!sessionModel || currentSessionsIndex < 0 || currentSessionsIndex >= sessionModel.rowCount()) {
            return "Unknown Session"
        }
        return sessionModel.data(sessionModel.index(currentSessionsIndex, 0), sessionNameRole) || "Unknown Session"
    }

    function getBackgroundFillMode() {
        const mode = config.stringValue("backgroundFillMode")
        switch (mode) {
            case "stretch": return Image.Stretch
            case "tile": return Image.Tile
            case "center": return Image.Pad
            case "aspectFit": return Image.PreserveAspectFit
            case "aspectCrop":
            default: return Image.PreserveAspectCrop
        }
    }

    function cycleUser(direction) {
        if (!hasMultipleUsers) return

        const newIndex = direction > 0
            ? (currentUserIndex + 1) % userModel.count
            : (currentUserIndex - 1 + userModel.count) % userModel.count

        currentUserIndex = newIndex
    }

    function sessionsCycleSelectPrev() {
        if (!hasMultipleSessions) return
        currentSessionsIndex = currentSessionsIndex > 0 ? currentSessionsIndex - 1 : sessionModel.rowCount() - 1
    }

    function sessionsCycleSelectNext() {
        if (!hasMultipleSessions) return
        currentSessionsIndex = currentSessionsIndex < sessionModel.rowCount() - 1 ? currentSessionsIndex + 1 : 0
    }

    function toggleUserSelector() {
        showUserSelector = !showUserSelector
    }

    function toggleSessionSelector() {
        sessionSelector.visible = !sessionSelector.visible
    }

    function attemptLogin() {
        if (isLoginInProgress || !userModel || !sessionModel) return

        const password = passwordInput.text
        const username = userModel.data(userModel.index(currentUserIndex, 0), userNameRole) || ""

        if (!password && !config.boolValue("allowEmptyPassword")) return

        isLoginInProgress = true
        sddm.login(username, password, currentSessionsIndex)
    }

    function handleLoginFailed() {
        if (!isLoginInProgress) return

        isLoginInProgress = false
        loginFailed = true
        passwordInput.clear()

        errorBorder.border.width = 3
        errorBorderTimer.start()
        passwordInput.forceActiveFocus()
    }

    function handleLoginSucceeded() {
        isLoginInProgress = false
        loginFailed = false
        errorBorder.border.width = 0
    }

    function clearError() {
        if (loginFailed && passwordInput.text.length > 0) {
            loginFailed = false
            errorBorder.border.width = 0
            errorBorderTimer.stop()
        }
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
        if (currentUserIndex < 0 || currentUserIndex >= userModel.count) {
            currentUserIndex = userModel.lastIndex
        }

        if (currentSessionsIndex < 0 || currentSessionsIndex >= sessionModel.rowCount()) {
            currentSessionsIndex = sessionModel.lastIndex
        }
    }

    // Error border reset timer
    Timer {
        id: errorBorderTimer
        interval: 2000
        onTriggered: errorBorder.border.width = 0
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
