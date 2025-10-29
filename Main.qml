import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQml 2.15
import SddmComponents 2.0
import Qt5Compat.GraphicalEffects

Rectangle {
    id: root

    // ---------------------------------------------------------------------
    // Utility modules
    // ---------------------------------------------------------------------
    QtObject {
        id: configUtil

        function sanitizedString(rawValue, fallback) {
            if (typeof rawValue !== "string") {
                return fallback
            }
            var trimmed = rawValue.trim()
            const commentIndex = trimmed.search(/\s#/)
            if (commentIndex >= 0) {
                trimmed = trimmed.slice(0, commentIndex).trim()
            }
            return trimmed.length > 0 ? trimmed : fallback
        }

        function stringValue(key, fallback) {
            return sanitizedString(config.stringValue(key), fallback)
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
            const rounded = Math.round(numeric)
            if (typeof min === "number" && typeof max === "number") {
                return clamp(rounded, min, max)
            }
            return rounded
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

    QtObject {
        id: palette

        readonly property color text: configUtil.colorValue("textColor", "#ffffff")
        readonly property color error: configUtil.colorValue("errorColor", "#ff4444")
        readonly property color background: configUtil.colorValue("backgroundColor", "#000000")
        readonly property color accent: configUtil.colorValue("controlAccentColor", Qt.rgba(text.r, text.g, text.b, 0.8))
        readonly property real baseOpacity: configUtil.realValue("controlOpacity", 0.24, 0.0, 1.0)

        function applyAlpha(colorValue, alpha) {
            return Qt.rgba(colorValue.r, colorValue.g, colorValue.b, Math.min(1, Math.max(0, alpha)))
        }

        readonly property color fillBase: applyAlpha(accent, baseOpacity)
        readonly property color fillHover: applyAlpha(accent, baseOpacity + 0.08)
        readonly property color fillFocus: applyAlpha(accent, baseOpacity + 0.14)
        readonly property color fillPressed: applyAlpha(accent, baseOpacity + 0.20)
        readonly property color borderBase: applyAlpha(accent, baseOpacity + 0.06)
        readonly property color borderActive: applyAlpha(accent, baseOpacity + 0.32)
    }

    QtObject {
        id: backgroundTokens

        readonly property bool glassEnabled: configUtil.boolValue("backgroundGlassEnabled", false)
        readonly property real blurIntensity: configUtil.realValue("backgroundGlassIntensity", 50, 0, 100)
        readonly property real blurRadius: glassEnabled ? configUtil.clamp(Math.round(16 + (blurIntensity / 100) * 48), 0, 64) : 0
        readonly property color tintBase: configUtil.colorValue("backgroundTintColor", Qt.rgba(0, 0, 0, 1))
        readonly property real tintOpacity: configUtil.realValue("backgroundTintIntensity", 0.0, 0.0, 1.0)
        readonly property color tint: Qt.rgba(tintBase.r, tintBase.g, tintBase.b, Math.min(1, Math.max(0, tintOpacity)))
        readonly property bool hasTint: tint.a > 0.001

        function fillMode() {
            switch (configUtil.stringValue("backgroundFillMode", "")) {
            case "stretch":   return Image.Stretch
            case "tile":      return Image.Tile
            case "center":    return Image.Pad
            case "aspectFit": return Image.PreserveAspectFit
            case "aspectCrop":
            default:          return Image.PreserveAspectCrop
            }
        }
    }

    QtObject {
        id: maskEngine

        property var indices: []

        function reset() {
            indices = []
        }

        function ensureCapacity(length, passwordLength) {
            if (!Array.isArray(indices)) {
                indices = []
            }
            if (length <= 0) {
                reset()
                return
            }

            const now = Date.now() % 2147483647

            while (indices.length < length) {
                const position = indices.length
                const seed = (now + position * 3517 + passwordLength * 811) % 2147483647
                const noise = ((seed ^ (seed >>> 15)) * 16807 + position * 69069 + now) % root.ipaChars.length
                indices.push(Math.abs(noise))
            }

            if (indices.length > length) {
                indices.splice(length, indices.length - length)
            }

            for (var i = Math.max(0, length - 4); i < length - 1; ++i) {
                const jSeed = (now + i * 1103515245) % length
                const j = Math.max(0, Math.min(length - 1, jSeed))
                const tmp = indices[i]
                indices[i] = indices[j]
                indices[j] = tmp
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

        function compute(passwordText, capacity, revealPlainText, randomize) {
            const textLength = passwordText.length
            const maskLength = Math.min(textLength, capacity)

            if (capacity <= 0) {
                if (textLength === 0) {
                    reset()
                }
                return ""
            }

            if (revealPlainText) {
                const startIndex = Math.max(0, textLength - capacity)
                const visibleTail = passwordText.slice(startIndex, textLength)
                if (textLength === 0) {
                    reset()
                }
                return centerMask(visibleTail, capacity)
            }

            if (randomize) {
                ensureCapacity(textLength, textLength)
                var randomizedMask = ""
                const startIndex = Math.max(0, textLength - maskLength)
                for (var randomIndex = 0; randomIndex < maskLength; ++randomIndex) {
                    randomizedMask += root.ipaChars[indices[startIndex + randomIndex] % root.ipaChars.length]
                }
                if (textLength === 0) {
                    reset()
                }
                return centerMask(randomizedMask, capacity)
            }

            var deterministicMask = ""
            const deterministicStart = Math.max(0, textLength - maskLength)
            for (var index = 0; index < maskLength; ++index) {
                var code = passwordText.charCodeAt(deterministicStart + index)
                if (!isFinite(code)) {
                    code = 0
                }
                deterministicMask += root.ipaChars[code % root.ipaChars.length]
            }

            if (textLength === 0) {
                reset()
            }
            return centerMask(deterministicMask, capacity)
        }
    }

    // ---------------------------------------------------------------------
    // Theme tokens
    // ---------------------------------------------------------------------
    readonly property color textColor: palette.text
    readonly property color errorColor: palette.error
    readonly property color backgroundColor: palette.background
    readonly property color controlAccentColor: palette.accent
    readonly property real controlOpacity: palette.baseOpacity
    readonly property real controlCornerRadius: configUtil.realValue("controlCornerRadius", 16, 0, 64)

    readonly property color controlFillBase: palette.fillBase
    readonly property color controlFillHover: palette.fillHover
    readonly property color controlFillFocus: palette.fillFocus
    readonly property color controlFillPressed: palette.fillPressed
    readonly property color controlBorderBase: palette.borderBase
    readonly property color controlBorderActive: palette.borderActive

    readonly property string fontFamily: configUtil.stringValue("fontFamily", "Inter")
    readonly property int baseFontSize: configUtil.intValue("baseFontSize", 14, 12, 18)
    readonly property int sessionsFontSize: configUtil.intValue("sessionsFontSize", 24, 14, 64)
    readonly property int animationDuration: configUtil.intValue("animationDuration", 300, 0, 5000)

    readonly property real backgroundOpacity: configUtil.realValue("backgroundOpacity", 0.8, 0, 1)
    readonly property bool backgroundGlassEnabled: backgroundTokens.glassEnabled
    readonly property real backgroundGlassRadius: backgroundTokens.blurRadius
    readonly property color backgroundTintColor: backgroundTokens.tint
    readonly property bool hasBackgroundTint: backgroundTokens.hasTint
    readonly property url backgroundImageSource: resolveImageSource(configUtil.stringValue("backgroundImage", ""))

    readonly property int passwordFlashLoops: Math.max(1, configUtil.intValue("passwordFlashLoops", 2, 1, 6))
    readonly property int passwordFlashOnDuration: Math.max(30, configUtil.intValue("passwordFlashOnDuration", 160, 20, 1000))
    readonly property int passwordFlashOffDuration: Math.max(30, configUtil.intValue("passwordFlashOffDuration", 220, 20, 1000))
    readonly property bool randomizePasswordMask: configUtil.boolValue("randomizePasswordMask", false)
    readonly property bool allowEmptyPassword: configUtil.boolValue("allowEmptyPassword", false)
    readonly property bool showUserRealName: configUtil.boolValue("showUserRealName", false)

    readonly property var ipaChars: [
        "ɐ", "ɑ", "ɒ", "æ", "ɓ", "ʙ", "β", "ɔ", "ɕ", "ç", "ɗ", "ɖ", "ð", "ʤ", "ə", "ɘ",
        "ɚ", "ɛ", "ɜ", "ɝ", "ɞ", "ɟ", "ʄ", "ɡ", "ɠ", "ɢ", "ʛ", "ɦ", "ɧ", "ħ", "ɥ", "ʜ",
        "ɨ", "ɪ", "ʝ", "ɟ", "ʄ", "ɫ", "ɬ", "ɭ", "ɮ", "ʟ", "ɰ", "ɱ", "ɯ", "ɲ", "ɳ", "ɴ",
        "ŋ", "ɵ", "ɶ", "ɷ", "ɸ", "ʂ", "ʃ", "ʅ", "ʆ", "ʇ", "θ", "ʉ", "ʊ", "ʋ", "ʌ", "ɣ",
        "ɤ", "ʍ", "χ", "ʎ", "ʏ", "ʐ", "ʑ", "ʒ", "ʓ", "ʔ", "ʕ", "ʖ", "ʗ", "ʘ", "ʙ", "ʚ"
    ]

    // ---------------------------------------------------------------------
    // State
    // ---------------------------------------------------------------------
    property bool isLoginInProgress: false
    property bool loginFailed: false
    property string loginErrorMessage: ""
    property string passwordMask: ""
    property bool passwordVisible: false

    property bool showUserSelector: configUtil.boolValue("showUserSelector", false)
    property bool showSessionSelector: configUtil.boolValue("showSessionSelector", false)

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

    // ---------------------------------------------------------------------
    // Derived properties
    // ---------------------------------------------------------------------
    readonly property int sessionNameRole: Qt.UserRole + 4
    readonly property int userNameRole: Qt.UserRole + 1
    readonly property string currentUsername: getCurrentUsername()
    readonly property string currentSession: getCurrentSession()
    readonly property bool hasMultipleUsers: userCount() > 1
    readonly property bool hasMultipleSessions: sessionCount() > 1
    readonly property bool userSelectorVisible: showUserSelector && userCount() > 0
    readonly property bool sessionSelectorVisible: showSessionSelector && sessionCount() > 0
    readonly property bool isGlassBackgroundActive: backgroundGlassEnabled && backgroundGlassRadius > 0

    anchors.fill: parent

    // ---------------------------------------------------------------------
    // Background
    // ---------------------------------------------------------------------
    Item {
        id: backgroundLayer
        anchors.fill: parent

        Rectangle {
            anchors.fill: parent
            color: backgroundColor
        }

        Image {
            id: backgroundImage
            anchors.fill: parent
            source: backgroundImageSource
            visible: source !== ""
            fillMode: backgroundTokens.fillMode()
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

    // ---------------------------------------------------------------------
    // Reusable components
    // ---------------------------------------------------------------------
    component PasswordField: Item {
        id: passwordFieldRoot

        property alias containerItem: passwordContainer
        property alias textInput: passwordInput
        property alias displayText: passwordDisplay
        property alias toggleButton: passwordToggleButton
        property alias errorOverlay: passwordErrorOverlay
        property alias errorFlash: passwordErrorFlash

        property color textColor: "#ffffff"
        property color accentFillBase: "#333333"
        property color accentFillHover: "#444444"
        property color accentFillFocus: "#555555"
        property color accentFillPressed: "#666666"
        property color accentBorderBase: "#444444"
        property color accentBorderActive: "#888888"
        property color errorColor: "#ff4444"

        property int fontPixelSize: 18
        property string fontFamily: "Inter"
        property real cornerRadius: 16

        property bool passwordVisible: false
        property string passwordMask: ""
        property bool isBusy: false

        property int passwordFlashLoops: 2
        property int passwordFlashOnDuration: 160
        property int passwordFlashOffDuration: 220

        signal visibilityToggled()
        signal passwordChanged()
        signal passwordAccepted()
        signal passwordCleared()

        implicitHeight: 56
        width: 0

        Rectangle {
            id: passwordContainer
            anchors.fill: parent
            radius: cornerRadius
            color: passwordInput.activeFocus
                ? accentFillFocus
                : passwordMouseArea.containsMouse
                    ? accentFillHover
                    : accentFillBase
            border.color: passwordInput.activeFocus ? accentBorderActive : accentBorderBase
            border.width: 1
            antialiasing: true

            Behavior on color { ColorAnimation { duration: 150 } }
            Behavior on border.color { ColorAnimation { duration: 200 } }

            Rectangle {
                id: passwordToggleButton
                width: 36
                height: 36
                radius: width / 2
                anchors.right: parent.right
                anchors.rightMargin: 12
                anchors.verticalCenter: parent.verticalCenter
                color: toggleMouse.pressed
                    ? accentFillPressed
                    : passwordFieldRoot.passwordVisible
                        ? accentFillFocus
                        : toggleMouse.containsMouse
                            ? accentFillHover
                            : accentFillBase
                border.color: (passwordFieldRoot.passwordVisible || toggleMouse.containsMouse)
                    ? accentBorderActive
                    : accentBorderBase
                border.width: 1
                antialiasing: true
                z: 3

                Behavior on color { ColorAnimation { duration: 150 } }

                Image {
                    id: passwordToggleIcon
                    anchors.centerIn: parent
                    source: passwordFieldRoot.passwordVisible ? "assets/hide.svg" : "assets/show.svg"
                    sourceSize: Qt.size(18, 18)
                    asynchronous: true
                    smooth: true
                    visible: false
                }

                ColorOverlay {
                    anchors.fill: passwordToggleIcon
                    source: passwordToggleIcon
                    color: passwordFieldRoot.textColor
                }

                MouseArea {
                    id: toggleMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: passwordFieldRoot.visibilityToggled()
                }
            }

            TextInput {
                id: passwordInput
                anchors.left: parent.left
                anchors.leftMargin: 16 + passwordToggleButton.width / 2
                anchors.right: parent.right
                anchors.rightMargin: 16 + passwordToggleButton.width / 2
                anchors.top: parent.top
                anchors.topMargin: 10
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 10

                font.family: passwordFieldRoot.fontFamily
                font.pixelSize: passwordFieldRoot.fontPixelSize
                color: "transparent"
                echoMode: TextInput.NoEcho
                selectByMouse: false
                selectionColor: "transparent"
                selectedTextColor: "transparent"
                cursorVisible: false
                cursorDelegate: Item { visible: false; width: 0; height: 0 }
                focus: false
                focusPolicy: Qt.ClickFocus
                enabled: !passwordFieldRoot.isBusy

                onAccepted: passwordFieldRoot.passwordAccepted()
                onTextChanged: passwordFieldRoot.passwordChanged()

                Keys.onEscapePressed: {
                    clear()
                    passwordFieldRoot.passwordCleared()
                }
            }

            Text {
                id: passwordDisplay
                anchors.left: parent.left
                anchors.leftMargin: 16 + passwordToggleButton.width / 2
                anchors.right: parent.right
                anchors.rightMargin: 16 + passwordToggleButton.width / 2
                anchors.top: parent.top
                anchors.topMargin: 10
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 10

                font.family: passwordFieldRoot.fontFamily
                font.pixelSize: passwordFieldRoot.fontPixelSize
                color: passwordFieldRoot.textColor
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
                text: passwordFieldRoot.passwordMask
                clip: true

                onWidthChanged: passwordFieldRoot.passwordChanged()
            }

            Rectangle {
                id: passwordErrorOverlay
                anchors.fill: parent
                radius: cornerRadius
                border.color: passwordFieldRoot.errorColor
                border.width: 2
                color: "transparent"
                opacity: 0
                visible: opacity > 0
                z: 1
            }

            SequentialAnimation {
                id: passwordErrorFlash
                running: false
                loops: passwordFieldRoot.passwordFlashLoops
                NumberAnimation {
                    target: passwordErrorOverlay
                    property: "opacity"
                    to: 1
                    duration: passwordFieldRoot.passwordFlashOnDuration
                    easing.type: Easing.OutQuad
                }
                NumberAnimation {
                    target: passwordErrorOverlay
                    property: "opacity"
                    to: 0
                    duration: passwordFieldRoot.passwordFlashOffDuration
                    easing.type: Easing.InQuad
                }
                onStopped: passwordErrorOverlay.opacity = 0
            }

            MouseArea {
                id: passwordMouseArea
                anchors.fill: parent
                hoverEnabled: true
                acceptedButtons: Qt.LeftButton
                cursorShape: Qt.IBeamCursor
                onClicked: passwordInput.forceActiveFocus()
                z: 0
            }
        }
    }

    component SelectorButton: Rectangle {
        id: selectorButton

        property string displayText: "‹"
        signal activated()

        width: 34
        height: 34
        radius: width / 2
        color: selectorMouseArea.pressed
            ? controlFillPressed
            : selectorMouseArea.containsMouse
                ? controlFillHover
                : controlFillBase
        border.color: selectorMouseArea.containsMouse ? controlBorderActive : controlBorderBase
        border.width: 1
        antialiasing: true

        Behavior on color { ColorAnimation { duration: 150 } }

        Text {
            anchors.centerIn: parent
            anchors.verticalCenterOffset: -2
            text: selectorButton.displayText
            color: textColor
            font.family: root.fontFamily
            font.pointSize: root.baseFontSize + 2
        }

        MouseArea {
            id: selectorMouseArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: selectorButton.activated()
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

        SelectorButton {
            anchors.left: parent.left
            anchors.leftMargin: 8
            anchors.verticalCenter: parent.verticalCenter
            displayText: baseSelector.prevText
            onActivated: baseSelector.prevClicked()
        }

        SelectorButton {
            anchors.right: parent.right
            anchors.rightMargin: 8
            anchors.verticalCenter: parent.verticalCenter
            displayText: baseSelector.nextText
            onActivated: baseSelector.nextClicked()
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
        id: powerButton
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
            id: powerIcon
            anchors.centerIn: parent
            source: iconSource
            sourceSize: Qt.size(26, 26)
            fillMode: Image.PreserveAspectFit
            smooth: true
            antialiasing: true
            visible: false
        }

        ColorOverlay {
            anchors.fill: powerIcon
            source: powerIcon
            color: textColor
        }

        MouseArea {
            id: mouseArea
            anchors.fill: parent
            hoverEnabled: true
            acceptedButtons: Qt.LeftButton
            cursorShape: Qt.PointingHandCursor
            onClicked: powerButton.clicked()
        }
    }

    // ---------------------------------------------------------------------
    // Main content
    // ---------------------------------------------------------------------
    Item {
        id: mainContent
        anchors.fill: parent

        Column {
            id: loginColumn
            width: Math.min(400, parent.width * 0.7)
            anchors.centerIn: parent
            spacing: 28

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

            PasswordField {
                id: passwordField
                width: parent.width
                textColor: root.textColor
                accentFillBase: controlFillBase
                accentFillHover: controlFillHover
                accentFillFocus: controlFillFocus
                accentFillPressed: controlFillPressed
                accentBorderBase: controlBorderBase
                accentBorderActive: controlBorderActive
                fontFamily: root.fontFamily
                fontPixelSize: root.baseFontSize + 8
                cornerRadius: controlCornerRadius
                passwordVisible: root.passwordVisible
                passwordMask: root.passwordMask
                isBusy: root.isLoginInProgress
                errorColor: root.errorColor
                passwordFlashLoops: root.passwordFlashLoops
                passwordFlashOnDuration: root.passwordFlashOnDuration
                passwordFlashOffDuration: root.passwordFlashOffDuration

                onVisibilityToggled: togglePasswordVisibility()
                onPasswordChanged: {
                    if (loginFailed) {
                        clearError()
                    }
                    updatePasswordMask()
                }
                onPasswordAccepted: attemptLogin()
                onPasswordCleared: {
                    resetPasswordMaskCache()
                    updatePasswordMask()
                }
            }

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

                Behavior on opacity { NumberAnimation { duration: animationDuration } }
            }

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

        Row {
            id: powerControls
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 20
            spacing: 12

            PowerButton {
                visible: sddm.canSuspend
                iconSource: "./assets/suspend.svg"
                tooltip: "Suspend"
                onClicked: sddm.suspend()
            }

            PowerButton {
                visible: sddm.canReboot
                iconSource: "./assets/reboot.svg"
                tooltip: "Reboot"
                onClicked: sddm.reboot()
            }

            PowerButton {
                visible: sddm.canPowerOff
                iconSource: "./assets/shutdown.svg"
                tooltip: "Shutdown"
                onClicked: sddm.powerOff()
            }
        }

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

    // ---------------------------------------------------------------------
    // Aliases for shared instances
    // ---------------------------------------------------------------------
    property alias passwordContainer: passwordField.containerItem
    property alias passwordInput: passwordField.textInput
    property alias passwordDisplay: passwordField.displayText
    property alias passwordToggleButton: passwordField.toggleButton
    property alias passwordErrorOverlay: passwordField.errorOverlay
    property alias passwordErrorFlash: passwordField.errorFlash

    // ---------------------------------------------------------------------
    // Keyboard shortcuts
    // ---------------------------------------------------------------------
    Shortcut { sequence: "F1"; onActivated: helpText.visible = !helpText.visible }

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

    Shortcut { sequence: "F10"; onActivated: if (sddm.canSuspend) sddm.suspend() }
    Shortcut { sequence: "F11"; onActivated: if (sddm.canPowerOff) sddm.powerOff() }
    Shortcut { sequence: "F12"; onActivated: if (sddm.canReboot) sddm.reboot() }

    // ---------------------------------------------------------------------
    // SDDM event handlers
    // ---------------------------------------------------------------------
    Connections {
        target: sddm
        function onLoginFailed() { handleLoginFailed() }
        function onLoginSucceeded() { handleLoginSucceeded() }
    }

    // ---------------------------------------------------------------------
    // Lifecycle
    // ---------------------------------------------------------------------
    Component.onCompleted: {
        validateConfiguration()
        updatePasswordMask()
        console.log("Theme initialized. Background:", backgroundImage.source)
    }

    // ---------------------------------------------------------------------
    // Model helpers
    // ---------------------------------------------------------------------
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

    // ---------------------------------------------------------------------
    // Background helpers
    // ---------------------------------------------------------------------
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

    // ---------------------------------------------------------------------
    // Navigation
    // ---------------------------------------------------------------------
    function cycleUser(direction) {
        if (!hasMultipleUsers) return
        const count = userCount()
        currentUserIndex = direction > 0
            ? (currentUserIndex + 1) % count
            : (currentUserIndex - 1 + count) % count
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

    // ---------------------------------------------------------------------
    // Authentication
    // ---------------------------------------------------------------------
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

    // ---------------------------------------------------------------------
    // Validation
    // ---------------------------------------------------------------------
    function validateConfiguration() {
        if (!userModel) {
            console.error("User model not available")
            return
        }
        if (!sessionModel) {
            console.error("Session model not available")
            return
        }
        ensureValidUserIndex()
        ensureValidSessionIndex()
    }

    function ensureValidUserIndex() {
        const count = userCount()
        currentUserIndex = count === 0 ? 0 : clampIndex(currentUserIndex, count)
    }

    function ensureValidSessionIndex() {
        const sessions = sessionCount()
        currentSessionsIndex = sessions === 0 ? 0 : clampIndex(currentSessionsIndex, sessions)
    }

    // ---------------------------------------------------------------------
    // Password masking
    // ---------------------------------------------------------------------
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

    function resetPasswordMaskCache() {
        maskEngine.reset()
    }

    function updatePasswordMask() {
        passwordMask = maskEngine.compute(
                    passwordInput.text || "",
                    maxMaskLength(),
                    passwordVisible,
                    randomizePasswordMask)
    }

    function togglePasswordVisibility() {
        passwordVisible = !passwordVisible
        updatePasswordMask()
    }

    // ---------------------------------------------------------------------
    // Error handling
    // ---------------------------------------------------------------------
    function setLoginError(message, overrideFlag) {
        const normalized = typeof message === "string" ? message.trim() : ""
        loginErrorMessage = normalized
        if (typeof overrideFlag === "boolean") {
            loginFailed = overrideFlag
        } else {
            loginFailed = normalized.length > 0
        }
    }
}
