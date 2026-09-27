/*
 * SPDX-FileCopyrightText: 2026 Float Frame contributors
 *
 * SPDX-License-Identifier: GPL-3.0-or-later
 */

pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import org.kde.ki18n
import org.kde.kirigami as Kirigami

import org.kde.haruna
import org.kde.haruna.settings
import org.kde.haruna.utilities

// Quick Settings sidebar modelled on IINA's: Video / Audio / Subtitles tabs
// with the controls people reach for while watching. Replaces Haruna's
// slide-in playlist panel on the right edge.
ResizeablePage {
    id: root

    edge: Qt.RightEdge
    customWidth: GeneralSettings.quickSettingsWidth
    width: limitWidth(customWidth)

    // ---- values mpv does not notify about; refreshed when the pane opens or the file changes
    property real aspectOverride: -1
    property int videoRotation: 0
    property bool deinterlace: false
    property bool flippedVideo: false
    property bool mirroredVideo: false
    property real brightness: 0
    property real contrast: 0
    property real saturation: 0
    property real gamma: 0
    property real hue: 0
    property real audioDelay: 0
    property real subDelay: 0
    property real subPos: 100
    property real subScale: 1
    property var videoTracks: []
    property int videoTrackId: 1
    property var audioDevices: []
    property string audioDevice: "auto"
    // 10-band equalizer, dB per band
    readonly property var eqBands: [31, 62, 125, 250, 500, 1000, 2000, 4000, 8000, 16000]
    property var eqGains: [0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
    property string eqPreset: "Flat"

    // value: what mpv reports back (a double); send: what we set
    readonly property var aspectPresets: [
        { text: KI18n.i18nc("@option aspect ratio", "Default"), value: -1, send: "-1" },
        { text: "4:3", value: 4 / 3, send: "4:3" }, { text: "16:9", value: 16 / 9, send: "16:9" }, { text: "16:10", value: 1.6, send: "16:10" },
        { text: "5:4", value: 1.25, send: "5:4" }, { text: "1:1", value: 1, send: "1:1" }, { text: "3:2", value: 1.5, send: "3:2" },
        { text: "2.21:1", value: 2.21, send: "2.21:1" }, { text: "2.35:1", value: 2.35, send: "2.35:1" }, { text: "2.39:1", value: 2.39, send: "2.39:1" }
    ]
    readonly property var cropPresets: [
        { text: KI18n.i18nc("@option crop", "None"), value: 0 },
        { text: "4:3", value: 4 / 3 }, { text: "16:9", value: 16 / 9 }, { text: "16:10", value: 1.6 },
        { text: "5:4", value: 1.25 }, { text: "1:1", value: 1 }, { text: "3:2", value: 1.5 },
        { text: "2.21:1", value: 2.21 }, { text: "2.35:1", value: 2.35 }, { text: "2.39:1", value: 2.39 }
    ]
    readonly property var eqPresets: ({
        "Flat":               [0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
        "Classical":          [0, 0, 0, 0, 0, 0, -7.2, -7.2, -7.2, -9.6],
        "Club":               [0, 0, 8, 5.6, 5.6, 5.6, 3.2, 0, 0, 0],
        "Dance":              [9.6, 7.2, 2.4, 0, 0, -5.6, -7.2, -7.2, 0, 0],
        "Full Bass":          [-8, 9.6, 9.6, 5.6, 1.6, -4, -8, -10.4, -11.2, -11.2],
        "Full Bass & Treble": [7.2, 5.6, 0, -7.2, -4.8, 1.6, 8, 11.2, 12, 12],
        "Full Treble":        [-9.6, -9.6, -9.6, -4, 2.4, 11.2, 16, 16, 16, 16.8],
        "Headphones":         [4.8, 11.2, 5.6, -3.2, -2.4, 1.6, 4.8, 9.6, 12.8, 14.4],
        "Large Hall":         [10.4, 10.4, 5.6, 5.6, 0, -4.8, -4.8, -4.8, 0, 0],
        "Live":               [-4.8, 0, 4, 5.6, 5.6, 5.6, 4, 2.4, 2.4, 2.4],
        "Party":              [7.2, 7.2, 0, 0, 0, 0, 0, 0, 7.2, 7.2],
        "Pop":                [-1.6, 4.8, 7.2, 8, 5.6, 0, -2.4, -2.4, -1.6, -1.6],
        "Reggae":             [0, 0, 0, -5.6, 0, 6.4, 6.4, 0, 0, 0],
        "Rock":               [8, 4.8, -5.6, -8, -3.2, 4, 8.8, 11.2, 11.2, 11.2],
        "Ska":                [-2.4, -4.8, -4, 0, 4, 5.6, 8.8, 9.6, 11.2, 9.6],
        "Soft":               [4.8, 1.6, 0, -2.4, 0, 4, 8, 9.6, 11.2, 12],
        "Soft Rock":          [4, 4, 2.4, 0, -4, -5.6, -3.2, 0, 2.4, 8.8],
        "Techno":             [8, 5.6, 0, -5.6, -4.8, 0, 8, 9.6, 9.6, 8.8]
    })

    function limitWidth(pWidth: real) : real {
        return Math.min(Math.max(pWidth, 300), root.mainWindowWidth - 50)
    }

    function toggle() : void {
        root.state = root.state === "visible" ? "hidden" : "visible"
    }

    function num(value: var, fallback: real) : real {
        const n = Number(value)
        return isNaN(n) ? fallback : n
    }

    function refresh() : void {
        const mpv = root.m_mpv
        root.aspectOverride = num(mpv.getProperty("video-aspect-override"), -1)
        root.videoRotation = num(mpv.getProperty("video-rotate"), 0)
        const deint = mpv.getProperty(MpvProperties.Deinterlace)
        root.deinterlace = deint === true || deint === "yes" || deint === "auto"
        root.brightness = num(mpv.getProperty(MpvProperties.Brightness), 0)
        root.contrast = num(mpv.getProperty(MpvProperties.Contrast), 0)
        root.saturation = num(mpv.getProperty(MpvProperties.Saturation), 0)
        root.gamma = num(mpv.getProperty(MpvProperties.Gamma), 0)
        root.hue = num(mpv.getProperty("hue"), 0)
        root.audioDelay = num(mpv.getProperty("audio-delay"), 0)
        root.subDelay = num(mpv.getProperty("sub-delay"), 0)
        root.subPos = num(mpv.getProperty("sub-pos"), 100)
        root.subScale = num(mpv.getProperty("sub-scale"), 1)
        const tracks = mpv.getProperty(MpvProperties.TrackList)
        const videos = []
        if (Array.isArray(tracks)) {
            for (const t of tracks) {
                if (t.type === "video") {
                    const size = (t["demux-w"] && t["demux-h"]) ? ` ${t["demux-w"]}×${t["demux-h"]}` : ""
                    const codec = t.codec ? ` (${t.codec})` : ""
                    videos.push({ id: t.id, text: (t.title ? t.title : KI18n.i18nc("@item video track", "Track %1", t.id)) + size + codec })
                }
            }
        }
        root.videoTracks = videos

        const devices = mpv.getProperty("audio-device-list")
        root.audioDevices = Array.isArray(devices)
                ? devices.map(d => ({ name: d.name, text: d.description ? d.description : d.name }))
                : [{ name: "auto", text: KI18n.i18nc("@item audio device", "Autoselect") }]

        // ids after the lists, so the combos can find them
        root.videoTrackId = num(mpv.getProperty("vid"), 1)
        root.audioDevice = String(mpv.getProperty("audio-device") ?? "auto")

        const filters = mpv.getProperty("vf")
        root.flippedVideo = Array.isArray(filters) && filters.some(f => f.name === "vflip")
        root.mirroredVideo = Array.isArray(filters) && filters.some(f => f.name === "hflip")
    }

    onStateChanged: {
        if (root.state === "visible") {
            root.refresh()
        }
    }

    Connections {
        target: root.m_mpv
        // fired after file-loaded, once track-list / video-params describe the new file
        function onAudioTracksModelChanged() {
            if (root.state === "visible") {
                Qt.callLater(root.refresh)
            }
        }
        function onVideoReconfig() {
            if (root.state === "visible") {
                Qt.callLater(root.refresh)
            }
        }
    }

    onResize: function(delta) {
        // anchored right: dragging left grows the pane
        root.customWidth = root.limitWidth(root.customWidth - delta)
    }
    onSaveWidth: {
        GeneralSettings.quickSettingsWidth = root.customWidth
        GeneralSettings.save()
    }

    // ---- actions
    function setAspect(value: real) : void {
        const preset = root.aspectPresets.find(p => Math.abs(p.value - value) < 1e-6)
        root.m_mpv.setProperty("video-aspect-override", preset ? preset.send : "-1")
        root.aspectOverride = value
    }

    // centred crop to a display aspect ratio, in source pixels (anamorphic-safe)
    function cropToAspect(aspect: real) : void {
        if (aspect <= 0) {
            root.m_mpv.resetCrop()
            return
        }
        const p = root.m_mpv.getProperty("video-params")
        if (!p || !p.w || !p.h || !p.dw || !p.dh) {
            return
        }
        const displayAspect = p.dw / p.dh
        let w = p.w, h = p.h
        if (aspect < displayAspect) {
            w = Math.round(p.w * aspect / displayAspect)   // narrower: cut the sides
        } else {
            h = Math.round(p.h * displayAspect / aspect)   // wider: cut top and bottom
        }
        w -= w % 2; h -= h % 2
        const x = Math.floor((p.w - w) / 2); const y = Math.floor((p.h - h) / 2)
        root.m_mpv.applyCrop(Qt.rect(x - (x % 2), y - (y % 2), w, h))
    }

    function currentCropAspect() : real {
        const mpv = root.m_mpv
        if (!mpv.hasCrop()) {
            return 0
        }
        const p = mpv.getProperty("video-params")
        if (!p || !p.w || !p.h || !p.dw || !p.dh) {
            return 0
        }
        return (mpv.cropRect.width * p.dw / p.w) / (mpv.cropRect.height * p.dh / p.h)
    }

    function setRotation(degrees: int) : void {
        root.m_mpv.setProperty("video-rotate", String(degrees))
        root.videoRotation = degrees
    }

    function toggleFilter(name: string) : void {
        root.m_mpv.command(["vf", "toggle", name])
    }

    function setAdjustment(property: string, value: real) : void {
        root.m_mpv.setProperty(property, String(Math.round(value)))
    }

    function applyEqualizer() : void {
        const current = root.m_mpv.getProperty("af")
        if (Array.isArray(current) && current.some(f => f.label === "ffeq")) {
            root.m_mpv.command(["af", "remove", "@ffeq"])
        }
        if (root.eqGains.every(g => g === 0)) {
            return
        }
        const entries = root.eqBands.map((f, i) => `entry(${f},${root.eqGains[i]})`).join(";")
        root.m_mpv.command(["af", "add", `@ffeq:lavfi=[firequalizer=gain_entry='${entries}']`])
    }

    function setEqGain(index: int, value: real) : void {
        const gains = root.eqGains.slice()
        gains[index] = Math.round(value * 10) / 10
        root.eqGains = gains
        root.eqPreset = KI18n.i18nc("@item equalizer preset", "Custom")
        root.applyEqualizer()
    }

    function setEqPreset(name: string) : void {
        if (!(name in root.eqPresets)) {
            return
        }
        root.eqGains = root.eqPresets[name].slice()
        root.eqPreset = name
        root.applyEqualizer()
    }

    // ---- reusable pieces
    component SectionHeading: Kirigami.Heading {
        level: 5
        Layout.fillWidth: true
        Layout.topMargin: Kirigami.Units.largeSpacing
    }

    component ValueSlider: RowLayout {
        id: valueSlider

        required property string label
        property real from: -100
        property real to: 100
        property real stepSize: 1
        property real value: 0
        property real resetValue: 0
        property int decimals: 0
        property string suffix: ""

        signal moved(real value)

        Layout.fillWidth: true
        spacing: Kirigami.Units.smallSpacing

        Label {
            text: valueSlider.label
            elide: Text.ElideRight
            Layout.preferredWidth: Kirigami.Units.gridUnit * 5
        }
        Slider {
            from: valueSlider.from
            to: valueSlider.to
            stepSize: valueSlider.stepSize
            value: valueSlider.value
            wheelEnabled: false
            Layout.fillWidth: true
            onMoved: valueSlider.moved(value)
        }
        Label {
            text: valueSlider.value.toFixed(valueSlider.decimals) + valueSlider.suffix
            horizontalAlignment: Text.AlignRight
            Layout.preferredWidth: Kirigami.Units.gridUnit * 3
        }
        ToolButton {
            icon.name: "edit-reset"
            enabled: Math.abs(valueSlider.value - valueSlider.resetValue) > 1e-6
            opacity: enabled ? 1 : 0.3
            onClicked: valueSlider.moved(valueSlider.resetValue)
            ToolTip.text: KI18n.i18nc("@info:tooltip", "Reset")
            ToolTip.visible: hovered
        }
    }

    component PresetRow: Flow {
        id: presetRow

        required property var options    // [{ text, value }]
        property var current
        property real tolerance: 0

        signal chosen(var value)

        Layout.fillWidth: true
        spacing: Kirigami.Units.smallSpacing

        function isCurrent(value: var) : bool {
            if (typeof value === "number" && typeof presetRow.current === "number") {
                return Math.abs(value - presetRow.current) <= presetRow.tolerance
            }
            return value === presetRow.current
        }

        Repeater {
            model: presetRow.options
            delegate: Button {
                required property var modelData
                text: modelData.text
                highlighted: presetRow.isCurrent(modelData.value)
                onClicked: presetRow.chosen(modelData.value)
            }
        }
    }

    component TrackCombo: RowLayout {
        id: trackCombo

        required property TracksModel tracksModel
        required property int currentTrackId
        property bool allowNone: false

        signal trackChosen(int trackId)

        Layout.fillWidth: true

        ComboBox {
            id: combo
            model: trackCombo.tracksModel
            textRole: "displayText"
            valueRole: "trackId"
            enabled: count > 0
            displayText: count === 0
                         ? KI18n.i18nc("@info", "No tracks")
                         : (currentIndex < 0 ? KI18n.i18nc("@item track", "None") : currentText)
            Layout.fillWidth: true
            onActivated: function(index) { trackCombo.trackChosen(currentValue) }

            function sync() {
                currentIndex = indexOfValue(trackCombo.currentTrackId)
            }
            Component.onCompleted: sync()
            onCountChanged: sync()
        }
        Connections {
            target: trackCombo
            function onCurrentTrackIdChanged() { combo.sync() }
        }
        ToolButton {
            visible: trackCombo.allowNone
            icon.name: "edit-clear"
            enabled: trackCombo.currentTrackId > 0
            ToolTip.text: KI18n.i18nc("@info:tooltip", "Turn off")
            ToolTip.visible: hovered
            onClicked: trackCombo.trackChosen(-1)
        }
    }

    pageContent: [
        ColumnLayout {
            anchors.fill: parent
            spacing: 0

            RowLayout {
                Layout.fillWidth: true
                spacing: 0

                TabBar {
                    id: tabs
                    Layout.fillWidth: true
                    TabButton { text: KI18n.i18nc("@title:tab", "Video"); icon.name: "video-x-generic" }
                    TabButton { text: KI18n.i18nc("@title:tab", "Audio"); icon.name: "audio-x-generic" }
                    TabButton { text: KI18n.i18nc("@title:tab", "Subtitles"); icon.name: "media-view-subtitles-symbolic" }
                }
                ToolButton {
                    icon.name: "window-close"
                    Layout.rightMargin: Kirigami.Units.smallSpacing
                    ToolTip.text: KI18n.i18nc("@info:tooltip", "Close")
                    ToolTip.visible: hovered
                    onClicked: root.state = "hidden"
                }
            }

            StackLayout {
                currentIndex: tabs.currentIndex
                Layout.fillWidth: true
                Layout.fillHeight: true

                // ================= VIDEO =================
                ScrollView {
                    contentWidth: availableWidth
                    leftPadding: Kirigami.Units.largeSpacing * 2
                    rightPadding: Kirigami.Units.largeSpacing * 2
                    bottomPadding: Kirigami.Units.largeSpacing
                    ColumnLayout {
                        width: parent.width
                        spacing: Kirigami.Units.smallSpacing

                        SectionHeading { text: KI18n.i18nc("@title", "Video Track") }
                        ComboBox {
                            Layout.fillWidth: true
                            id: videoTrackCombo
                            model: root.videoTracks
                            textRole: "text"
                            valueRole: "id"
                            enabled: count > 0
                            displayText: count === 0 ? KI18n.i18nc("@info", "No video") : currentText
                            function sync() { currentIndex = indexOfValue(root.videoTrackId) }
                            onModelChanged: sync()
                            Connections { target: root; function onVideoTrackIdChanged() { videoTrackCombo.sync() } }
                            onActivated: {
                                root.m_mpv.setProperty("vid", String(currentValue))   // track ids must not arrive as doubles
                                root.videoTrackId = currentValue
                            }
                        }

                        SectionHeading { text: KI18n.i18nc("@title", "Aspect Ratio") }
                        PresetRow {
                            options: root.aspectPresets
                            current: root.aspectOverride
                            tolerance: 0.02
                            onChosen: function(value) { root.setAspect(value) }
                        }

                        SectionHeading { text: KI18n.i18nc("@title", "Crop") }
                        Label {
                            Layout.fillWidth: true
                            wrapMode: Text.WordWrap
                            opacity: 0.7
                            text: KI18n.i18nc("@info", "Trims the picture itself; in chromeless mode the window follows.")
                        }
                        PresetRow {
                            options: root.cropPresets
                            current: root.currentCropAspect()
                            tolerance: 0.02
                            onChosen: function(value) { root.cropToAspect(value) }
                        }
                        Button {
                            action: HarunaApp.actions.cropToContentAction
                            text: KI18n.i18nc("@action:button", "Custom…")
                        }

                        SectionHeading { text: KI18n.i18nc("@title", "Rotation") }
                        PresetRow {
                            options: [ { text: "0°", value: 0 }, { text: "90°", value: 90 }, { text: "180°", value: 180 }, { text: "270°", value: 270 } ]
                            current: root.videoRotation
                            onChosen: function(value) { root.setRotation(value) }
                        }

                        RowLayout {
                            Layout.topMargin: Kirigami.Units.largeSpacing
                            spacing: Kirigami.Units.largeSpacing
                            CheckBox {
                                text: KI18n.i18nc("@option:check", "Flip")
                                checked: root.flippedVideo
                                onToggled: { root.flippedVideo = checked; root.toggleFilter("vflip") }
                            }
                            CheckBox {
                                text: KI18n.i18nc("@option:check", "Mirror")
                                checked: root.mirroredVideo
                                onToggled: { root.mirroredVideo = checked; root.toggleFilter("hflip") }
                            }
                            CheckBox {
                                text: KI18n.i18nc("@option:check", "Deinterlace")
                                checked: root.deinterlace
                                onToggled: {
                                    root.deinterlace = checked
                                    root.m_mpv.setProperty(MpvProperties.Deinterlace, checked)
                                }
                            }
                        }

                        SectionHeading { text: KI18n.i18nc("@title", "Speed") }
                        RowLayout {
                            Layout.fillWidth: true
                            Slider {
                                id: speedSlider
                                // log2 scale: 0.25× … 16×
                                from: -2; to: 4; stepSize: 0.05
                                value: Math.log2(root.m_mpv.playbackSpeed)
                                wheelEnabled: false
                                Layout.fillWidth: true
                                onMoved: root.m_mpv.setPlaybackSpeed(Math.round(Math.pow(2, value) * 100) / 100)
                            }
                            Label {
                                text: root.m_mpv.playbackSpeed.toFixed(2) + "×"
                                Layout.preferredWidth: Kirigami.Units.gridUnit * 3
                                horizontalAlignment: Text.AlignRight
                            }
                            ToolButton {
                                icon.name: "edit-reset"
                                enabled: root.m_mpv.playbackSpeed !== 1
                                opacity: enabled ? 1 : 0.3
                                onClicked: root.m_mpv.setPlaybackSpeed(1)
                            }
                        }

                        SectionHeading { text: KI18n.i18nc("@title", "Picture") }
                        ValueSlider { label: KI18n.i18nc("@label:slider", "Brightness"); value: root.brightness
                            onMoved: function(v) { root.setAdjustment(MpvProperties.Brightness, v); root.brightness = Math.round(v) } }
                        ValueSlider { label: KI18n.i18nc("@label:slider", "Contrast"); value: root.contrast
                            onMoved: function(v) { root.setAdjustment(MpvProperties.Contrast, v); root.contrast = Math.round(v) } }
                        ValueSlider { label: KI18n.i18nc("@label:slider", "Saturation"); value: root.saturation
                            onMoved: function(v) { root.setAdjustment(MpvProperties.Saturation, v); root.saturation = Math.round(v) } }
                        ValueSlider { label: KI18n.i18nc("@label:slider", "Gamma"); value: root.gamma
                            onMoved: function(v) { root.setAdjustment(MpvProperties.Gamma, v); root.gamma = Math.round(v) } }
                        ValueSlider { label: KI18n.i18nc("@label:slider", "Hue"); value: root.hue
                            onMoved: function(v) { root.setAdjustment("hue", v); root.hue = Math.round(v) } }

                        Item { Layout.preferredHeight: Kirigami.Units.largeSpacing }
                    }
                }

                // ================= AUDIO =================
                ScrollView {
                    contentWidth: availableWidth
                    leftPadding: Kirigami.Units.largeSpacing * 2
                    rightPadding: Kirigami.Units.largeSpacing * 2
                    bottomPadding: Kirigami.Units.largeSpacing
                    ColumnLayout {
                        width: parent.width
                        spacing: Kirigami.Units.smallSpacing

                        SectionHeading { text: KI18n.i18nc("@title", "Audio Track") }
                        TrackCombo {
                            tracksModel: root.m_mpv.audioTracksModel
                            currentTrackId: root.m_mpv.audioId
                            onTrackChosen: function(trackId) { root.m_mpv.audioId = trackId }
                        }

                        SectionHeading { text: KI18n.i18nc("@title", "Volume") }
                        RowLayout {
                            Layout.fillWidth: true
                            ToolButton {
                                action: HarunaApp.actions.muteAction
                                display: AbstractButton.IconOnly
                                icon.name: root.m_mpv.mute ? "player-volume-muted" : "player-volume"
                            }
                            Slider {
                                from: 0; to: root.m_mpv.volumeMax; stepSize: 1
                                value: root.m_mpv.volume
                                wheelEnabled: false
                                Layout.fillWidth: true
                                onMoved: root.m_mpv.volume = Math.round(value)
                            }
                            Label {
                                text: root.m_mpv.volume + "%"
                                Layout.preferredWidth: Kirigami.Units.gridUnit * 3
                                horizontalAlignment: Text.AlignRight
                            }
                        }

                        SectionHeading { text: KI18n.i18nc("@title", "Audio Delay") }
                        ValueSlider {
                            label: KI18n.i18nc("@label:slider", "Delay")
                            from: -10; to: 10; stepSize: 0.1; decimals: 1; suffix: " s"
                            value: root.audioDelay
                            onMoved: function(v) {
                                root.m_mpv.setProperty("audio-delay", v)
                                root.audioDelay = v
                            }
                        }

                        SectionHeading { text: KI18n.i18nc("@title", "Equalizer") }
                        RowLayout {
                            Layout.fillWidth: true
                            ComboBox {
                                Layout.fillWidth: true
                                model: Object.keys(root.eqPresets)
                                displayText: root.eqPreset
                                onActivated: function(index) { root.setEqPreset(model[index]) }
                            }
                            ToolButton {
                                icon.name: "edit-reset"
                                enabled: root.eqPreset !== "Flat"
                                opacity: enabled ? 1 : 0.3
                                onClicked: root.setEqPreset("Flat")
                            }
                        }
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 0
                            Repeater {
                                model: root.eqBands.length
                                delegate: ColumnLayout {
                                    id: band
                                    required property int index
                                    Layout.fillWidth: true
                                    spacing: 0
                                    Label {
                                        text: root.eqGains[band.index].toFixed(0)
                                        font.pointSize: Kirigami.Theme.smallFont.pointSize
                                        Layout.alignment: Qt.AlignHCenter
                                    }
                                    Slider {
                                        orientation: Qt.Vertical
                                        from: -20; to: 20; stepSize: 0.5
                                        value: root.eqGains[band.index]
                                        wheelEnabled: false
                                        Layout.preferredHeight: Kirigami.Units.gridUnit * 8
                                        Layout.alignment: Qt.AlignHCenter
                                        onMoved: root.setEqGain(band.index, value)
                                    }
                                    Label {
                                        text: root.eqBands[band.index] >= 1000
                                              ? (root.eqBands[band.index] / 1000) + "k"
                                              : root.eqBands[band.index]
                                        font.pointSize: Kirigami.Theme.smallFont.pointSize
                                        Layout.alignment: Qt.AlignHCenter
                                    }
                                }
                            }
                        }

                        SectionHeading { text: KI18n.i18nc("@title", "Audio Device") }
                        ComboBox {
                            Layout.fillWidth: true
                            id: audioDeviceCombo
                            model: root.audioDevices
                            textRole: "text"
                            valueRole: "name"
                            function sync() { currentIndex = indexOfValue(root.audioDevice) }
                            onModelChanged: sync()
                            Connections { target: root; function onAudioDeviceChanged() { audioDeviceCombo.sync() } }
                            onActivated: {
                                root.m_mpv.setProperty("audio-device", currentValue)
                                root.audioDevice = currentValue
                            }
                        }

                        Item { Layout.preferredHeight: Kirigami.Units.largeSpacing }
                    }
                }

                // ================= SUBTITLES =================
                ScrollView {
                    contentWidth: availableWidth
                    leftPadding: Kirigami.Units.largeSpacing * 2
                    rightPadding: Kirigami.Units.largeSpacing * 2
                    bottomPadding: Kirigami.Units.largeSpacing
                    ColumnLayout {
                        width: parent.width
                        spacing: Kirigami.Units.smallSpacing

                        SectionHeading { text: KI18n.i18nc("@title", "Subtitle Track") }
                        TrackCombo {
                            tracksModel: root.m_mpv.subtitleTracksModel
                            currentTrackId: root.m_mpv.subtitleId
                            allowNone: true
                            onTrackChosen: function(trackId) { root.m_mpv.subtitleId = trackId }
                        }
                        SectionHeading { text: KI18n.i18nc("@title", "Secondary Subtitle") }
                        TrackCombo {
                            tracksModel: root.m_mpv.subtitleTracksModel
                            currentTrackId: root.m_mpv.secondarySubtitleId
                            allowNone: true
                            onTrackChosen: function(trackId) {
                                if (trackId > 0) {
                                    root.m_mpv.secondarySubtitleId = trackId
                                } else {
                                    root.m_mpv.setProperty("secondary-sid", "no")
                                }
                            }
                        }
                        Button {
                            action: HarunaApp.actions.addExternalSubtitleAction
                            text: KI18n.i18nc("@action:button", "Load External Subtitle…")
                            icon.name: "document-open"
                        }

                        SectionHeading { text: KI18n.i18nc("@title", "Timing and Placement") }
                        ValueSlider {
                            label: KI18n.i18nc("@label:slider", "Delay")
                            from: -10; to: 10; stepSize: 0.1; decimals: 1; suffix: " s"
                            value: root.subDelay
                            onMoved: function(v) { root.m_mpv.setProperty("sub-delay", v); root.subDelay = v }
                        }
                        ValueSlider {
                            label: KI18n.i18nc("@label:slider", "Position")
                            from: 0; to: 150; stepSize: 1; resetValue: 100
                            value: root.subPos
                            onMoved: function(v) { root.m_mpv.setProperty("sub-pos", String(Math.round(v))); root.subPos = Math.round(v) }
                        }
                        ValueSlider {
                            label: KI18n.i18nc("@label:slider", "Scale")
                            from: 0.3; to: 3; stepSize: 0.05; decimals: 2; resetValue: 1; suffix: "×"
                            value: root.subScale
                            onMoved: function(v) { root.m_mpv.setProperty("sub-scale", v); root.subScale = v }
                        }

                        SectionHeading { text: KI18n.i18nc("@title", "Style") }
                        GridLayout {
                            columns: 2
                            Layout.fillWidth: true
                            columnSpacing: Kirigami.Units.largeSpacing

                            Label { text: KI18n.i18nc("@label", "Font") }
                            ComboBox {
                                id: fontCombo
                                Layout.fillWidth: true
                                model: SystemUtils.getFonts()
                                currentIndex: find(SubtitlesSettings.fontFamily)
                                onActivated: {
                                    SubtitlesSettings.fontFamily = currentText
                                    SubtitlesSettings.save()
                                }
                            }

                            Label { text: KI18n.i18nc("@label", "Size") }
                            SpinBox {
                                from: 10; to: 200
                                value: SubtitlesSettings.fontSize
                                onValueModified: {
                                    SubtitlesSettings.fontSize = value
                                    SubtitlesSettings.save()
                                }
                            }

                            Label { text: KI18n.i18nc("@label", "Weight") }
                            RowLayout {
                                CheckBox {
                                    text: KI18n.i18nc("@option:check", "Bold")
                                    checked: SubtitlesSettings.isBold
                                    onToggled: { SubtitlesSettings.isBold = checked; SubtitlesSettings.save() }
                                }
                                CheckBox {
                                    text: KI18n.i18nc("@option:check", "Italic")
                                    checked: SubtitlesSettings.isItalic
                                    onToggled: { SubtitlesSettings.isItalic = checked; SubtitlesSettings.save() }
                                }
                            }

                            Label { text: KI18n.i18nc("@label", "Text color") }
                            ColorPickerButton {
                                color: SubtitlesSettings.fontColor
                                onColorChosen: function(color) { SubtitlesSettings.fontColor = color; SubtitlesSettings.save() }
                            }

                            Label { text: KI18n.i18nc("@label", "Border color") }
                            ColorPickerButton {
                                color: SubtitlesSettings.borderColor
                                onColorChosen: function(color) { SubtitlesSettings.borderColor = color; SubtitlesSettings.save() }
                            }

                            Label { text: KI18n.i18nc("@label", "Border width") }
                            SpinBox {
                                from: 0; to: 20
                                value: SubtitlesSettings.borderSize
                                onValueModified: { SubtitlesSettings.borderSize = value; SubtitlesSettings.save() }
                            }

                            Label { text: KI18n.i18nc("@label", "Shadow color") }
                            ColorPickerButton {
                                color: SubtitlesSettings.shadowColor
                                onColorChosen: function(color) { SubtitlesSettings.shadowColor = color; SubtitlesSettings.save() }
                            }

                            Label { text: KI18n.i18nc("@label", "Shadow offset") }
                            SpinBox {
                                from: 0; to: 20
                                value: SubtitlesSettings.shadowOffset
                                onValueModified: { SubtitlesSettings.shadowOffset = value; SubtitlesSettings.save() }
                            }
                        }

                        Item { Layout.preferredHeight: Kirigami.Units.largeSpacing }
                    }
                }
            }
        }
    ]
}
