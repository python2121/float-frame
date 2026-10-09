/*
 * SPDX-FileCopyrightText: 2020 George Florea Bănuș <georgefb899@gmail.com>
 *
 * SPDX-License-Identifier: GPL-3.0-or-later
 */

pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Dialogs

import org.kde.ki18n
import org.kde.kirigami as Kirigami
import org.kde.config as KConfig

import org.kde.haruna
import org.kde.haruna.playlist
import org.kde.haruna.transcript
import org.kde.haruna.utilities
import org.kde.haruna.settings
import org.kde.haruna.youtube

ApplicationWindow {
    id: window

    property bool containsMouse: false

    // Float Frame: frameless window with no menu bar, toolbar or docked footer;
    // the video is dragged to move the window and its edges to resize it.
    // Either the saved setting or the --chromeless session override turns it on.
    readonly property bool chromeless: GeneralSettings.chromeless || HarunaApp.chromelessOverride
    onChromelessChanged: fitWindowTimer.restart()

    // Chromeless: a transparent band this wide around the visible window,
    // excluded from what the compositor treats as the window, so the resize
    // grab zones can start outside the frame like a decorated window's do.
    // Only while windowed — maximized and fullscreen the surface has to match
    // the screen exactly. `frameBand` is what actually got applied (the band
    // is Wayland-only); the visible content is inset by that much.
    readonly property int frameMargin: chromeless
                                       && visibility !== Window.Maximized
                                       && visibility !== Window.FullScreen ? 10 : 0
    property int frameBand: 0
    onFrameMarginChanged: applyFrameMargin()

    function applyFrameMargin() : void {
        if (SystemUtils.setWindowMargins(window, frameMargin)) {
            frameBand = frameMargin
        }
        applyOpaqueArea()
    }

    // Everything inside the band is opaque (the frame paints black behind the
    // video; framed mode has the theme background). Tell the compositor so:
    // the alpha buffer the band needs otherwise makes it blend the whole
    // surface and skip direct scanout of fullscreen video. Surface
    // coordinates, so it follows every resize.
    function applyOpaqueArea() : void {
        SystemUtils.setWindowOpaqueInset(window, frameBand)
    }
    // Chromeless: set while the compositor runs an interactive move or resize.
    // The pointer has left the window for the whole drag, so the overlays
    // can't track it; they stay up until this clears and only then start
    // their hide countdown. Cleared when the pointer comes back after the
    // button is released (or on the next press, should that be missed).
    property bool windowGrabActive: false

    function startWindowMove(grabber) : bool {
        const started = SystemUtils.startSystemMove(window, grabber)
        if (started) {
            windowGrabActive = true
        }
        return started
    }

    function startWindowResize(edges, grabber) : bool {
        const started = SystemUtils.startSystemResize(window, edges, grabber)
        if (started) {
            windowGrabActive = true
        }
        return started
    }

    Connections {
        target: HarunaApp
        function onQmlApplicationMouseEnter() {
            window.windowGrabActive = false
        }
    }

    onFrameBandChanged: applyOpaqueArea()
    onWidthChanged: applyOpaqueArea()
    onHeightChanged: applyOpaqueArea()

    property int previousVisibility: Window.Windowed
    property var acceptedSubtitleTypes: ["application/x-subrip", "text/x-ssa", "text/x-microdvd"]

    function initPlaylist() {
        if (!playlist.isReady || !mpv.isReady) {
            return
        }
        playlist.manager.initialize(CommandLineOptions.startupUrls)
        if (CommandLineOptions.startupUrls.length > 0) {
            Models.recentFilesModel.addRecentFile(CommandLineOptions.startupUrls[0], RecentFilesModel.OpenedFrom.ExternalApp)
        }
    }

    objectName: "HarunaMainWindow"

    visible: true
    title: mpv.mediaTitle || KI18n.i18nc("@title:window", "Float Frame")
    width: 1000
    height: 600
    minimumWidth: 400
    minimumHeight: 200
    flags: chromeless ? (Qt.Window | Qt.FramelessWindowHint) : Qt.Window
    // Transparent so the resize band is see-through; the frame item paints
    // its own black behind the video.
    color: chromeless ? "transparent" : Kirigami.Theme.backgroundColor

    onVisibilityChanged: function(visibility) {
        // the native window exists by now, and the band depends on the state
        applyFrameMargin()
        if (PlaybackSettings.pauseWhileMinimized) {
            if (visibility === Window.Minimized) {
                if (mpv.pause) {
                    mpv.preMinimizePlaybackState = MpvVideo.PlaybackState.Paused
                } else {
                    mpv.preMinimizePlaybackState = MpvVideo.PlaybackState.Playing
                }
                mpv.pause = true
            }
            if (previousVisibility === Window.Minimized
                    && visibility === Window.Windowed | Window.Maximized | Window.FullScreen) {
                if (mpv.preMinimizePlaybackState === MpvVideo.PlaybackState.Playing) {
                    mpv.pause = false
                }
            }
        }

        // used to restore window state, when exiting fullscreen,
        // to the one it had before going fullscreen
        if (visibility !== Window.FullScreen) {
            previousVisibility = visibility
        }
    }

    onClosing: {
        const settingsWindow = settingsLoader.item as Window
        const sortConfigWindow = playlist.advancedSortWindow.item as Kirigami.ApplicationWindow
        settingsWindow?.close()
        sortConfigWindow?.close()
    }

    header: Header {
        id: header

        m_mpv: mpv
        m_menuBarLoader: menuBarLoader
        m_settingsLoader: settingsLoader
    }

    menuBar: MenuBarLoader {
        id: menuBarLoader

        m_mpv: mpv
        m_settingsLoader: settingsLoader
    }

    Connections {
        target: GeneralSettings
        function onOsdFontSizeChanged() {
            osd.message("Test osd font size")
        }
        function onMaxRecentFilesChanged() {
            Models.recentFilesModel.getItems()
        }
        function onResizeWindowToVideoChanged() {
            window.resizeWindow()
        }
        function onColorSchemeChanged() {
            HarunaApp.activateColorScheme(GeneralSettings.colorScheme)
        }
    }
    Connections {
        target: AudioSettings
        function onPreferredTrackChanged() {
            mpv.audioId = AudioSettings.preferredTrack
        }
        function onPreferredLanguageChanged() {
            mpv.setProperty(MpvProperties.AudioLanguage, AudioSettings.preferredLanguage.replace(/\s+/g, ''))
        }
        function onReplayGainChanged() {
            mpv.setProperty(MpvProperties.ReplayGain, AudioSettings.replayGain)
        }
        function onReplayGainPreampChanged() {
            mpv.setProperty(MpvProperties.ReplayGainPreamp, AudioSettings.replayGainPreamp)
        }
        function onReplayGainPreventClipChanged() {
            mpv.setProperty(MpvProperties.ReplayGainClip, !AudioSettings.replayGainPreventClip)
        }
        function onReplayGainFallbackChanged() {
            mpv.setProperty(MpvProperties.ReplayGainFallback, AudioSettings.replayGainFallback)
        }
    }
    Connections {
        target: PlaybackSettings
        function onYtdlFormatChanged() {
            mpv.setProperty(MpvProperties.YtdlFormat, PlaybackSettings.ytdlFormat)
        }
        function onHWDecodingChanged() {
            mpv.setProperty(MpvProperties.HardwareDecoding, PlaybackSettings.hWDecoding)
        }
    }
    Connections {
        target: SubtitlesSettings
        function onAutoSelectSubtitlesChanged() {
            mpv.selectSubtitleTrack()
        }
        function onPreferredLanguageChanged() {
            mpv.setProperty(MpvProperties.SubtitleLanguage, SubtitlesSettings.preferredLanguage.replace(/\s+/g, ''))
        }
        function onPreferredTrackChanged() {
            mpv.subtitleId = SubtitlesSettings.preferredTrack
        }
        function onAllowOnBlackBordersChanged() {
            mpv.setProperty(MpvProperties.SubtitleUseMargins, SubtitlesSettings.allowOnBlackBorders ? "yes" : "no")
            mpv.setProperty(MpvProperties.SubtitleAssForceMargins, SubtitlesSettings.allowOnBlackBorders ? "yes" : "no")
        }
        function onFontFamilyChanged() {
            mpv.setProperty(MpvProperties.SubtitleFont, SubtitlesSettings.fontFamily)
        }
        function onFontSizeChanged() {
            mpv.setProperty(MpvProperties.SubtitleFontSize, SubtitlesSettings.fontSize)
        }
        function onIsBoldChanged() {
            mpv.setProperty(MpvProperties.SubtitleBold, SubtitlesSettings.isBold)
        }
        function onIsItalicChanged() {
            mpv.setProperty(MpvProperties.SubtitleItalic, SubtitlesSettings.isItalic)
        }
        function onFontColorChanged() {
            mpv.setProperty(MpvProperties.SubtitleColor, SubtitlesSettings.fontColor)
        }
        function onShadowColorChanged() {
            mpv.setProperty(MpvProperties.SubtitleShadowColor, SubtitlesSettings.shadowColor)
        }
        function onShadowOffsetChanged() {
            mpv.setProperty(MpvProperties.SubtitleShadowOffset, SubtitlesSettings.shadowOffset)
        }
        function onBorderColorChanged() {
            mpv.setProperty(MpvProperties.SubtitleBorderColor, SubtitlesSettings.borderColor)
        }
        function onBorderSizeChanged() {
            mpv.setProperty(MpvProperties.SubtitleBorderSize, SubtitlesSettings.borderSize)
        }
        function onBorderStyleChanged() {
            mpv.setProperty(MpvProperties.SubtitleBorderStyle, SubtitlesSettings.borderStyle)
        }
    }
    Connections {
        target: VideoSettings
        function onScreenshotTemplateChanged() {
            mpv.setProperty(MpvProperties.ScreenshotTemplate, VideoSettings.screenshotTemplate)
        }
        function onScreenshotFormatChanged() {
            mpv.setProperty(MpvProperties.ScreenshotFormat, VideoSettings.screenshotFormat)
        }
    }

    // Activated from Component.onCompleted, after the frame band is applied:
    // the saved size includes the band, so restoring it first would grow the
    // window by the band on every launch.
    Loader {
        id: windowStateSaverLoader

        active: false
        sourceComponent: KConfig.WindowStateSaver {
            configGroupName: "MainWindow"
        }
    }

    MprisItem {
        mpv: mpv
        window: window
        activePlaylist: playlist.manager.activePlaylist

        onRaise: { HarunaApp.raiseWindow() }
        onOpenUri: function(uri) {
            window.openFile(uri, RecentFilesModel.OpenedFrom.ExternalApp)
        }
    }

    // The visible window: the surface minus the transparent resize band
    // (frameBand) around it. Everything the user sees lives in here; the
    // resize handles after it cover the whole surface, band included.
    Item {
        id: frame

        anchors.fill: parent
        anchors.margins: window.frameBand

        // The window is transparent in chromeless mode (for the band); keep
        // the frame itself opaque black behind the video.
        Rectangle {
            anchors.fill: parent
            color: "black"
            visible: window.chromeless
        }

        MpvVideo {
            id: mpv

            playlistsManager: playlist.manager

            width: frame.width
            height: window.isFullScreen()
                    ? frame.height
                    : frame.height - (footer.isFloating ? 0 : footer.height)
            anchors.left: playlist.edge === Qt.LeftEdge
                          ? PlaylistSettings.overlayVideo ? frame.left : playlist.right
                          : transcript.right
            anchors.right: playlist.edge === Qt.RightEdge
                           ? PlaylistSettings.overlayVideo ? frame.right : playlist.left
                           : transcript.left
            anchors.top: frame.top

            onFilesDropped: function(urls: list<url>, mode: int) {
                playlist.manager.defaultPlaylist.addFilesAndFolders(urls, mode)
                if (mode === PlaylistModel.Behavior.Clear) {
                    Models.recentFilesModel.addRecentFile(playlist.manager.activeItemPath(), RecentFilesModel.OpenedFrom.Playlist)
                }
            }

            onVideoReconfig: {
                HarunaApp.trace("video-reconfig")
                window.resizeWindow()
                fitWindowTimer.restart()
            }

            onCropChanged: {
                if (mpv.hasCrop()) {
                    osd.message(KI18n.i18nc("@info:tooltip", "Cropped to %1 × %2", mpv.cropRect.width, mpv.cropRect.height))
                }
                fitWindowTimer.restart()
            }

            // osd-dimensions settles a moment after a reconfig
            Timer {
                id: fitWindowTimer
                interval: 150
                onTriggered: window.fitWindowToPicture(false)
            }

            onEofPlayNext: {
                Models.recentFilesModel.addRecentFile(playlist.manager.activeItemPath(), RecentFilesModel.OpenedFrom.Playlist)
            }

            onOsdMessage: function(text) {
                osd.message(text);
            }

            onIsReadyChanged: {
                HarunaApp.trace("mpv-ready")
                osd.active = true
                window.initPlaylist()
                if (window.chromeless && !GeneralSettings.chromelessHintShown) {
                    osd.message(window.chromelessHintText())
                    GeneralSettings.chromelessHintShown = true
                    GeneralSettings.save()
                }
            }

            Osd {
                id: osd

                maxWidth: mpv.width
            }

            SelectActionPopup {
                id: triggerActionPopup

                onActionSelected: function(actionName) {
                    HarunaApp.actions[actionName].trigger()
                }
            }
        }

        // extra space outside the playlist so that the playlist is not closed
        // when the mouse leaves it by mistake (dragging items, resizing the playlist)
        Item {
            // when window width is very small, there is only 50 pixels not covered by the playlist
            // in that case the extra space is reduced to 30 to allow the playlist to be closed with the mouse
            width: playlist.width >= frame.width - 70 ? 30 : 50
            height: playlist.height
            anchors.right: PlaylistSettings.position === "right" ? playlist.left : undefined
            anchors.left: PlaylistSettings.position === "left" ? playlist.right : undefined
            visible: playlist.visible
            HoverHandler {}
        }

        Transcript {
            id: transcript

            m_mpv: mpv
            height: mpv.height
            mainWindowWidth: frame.width
            fsScale: window.isFullScreen() && PlaylistSettings.bigFontFullscreen ? 1.36 : 1

            Connections {
                target: actions
                function onToggleTranscript() {
                    if (transcript.state === "visible") {
                        transcript.state = "hidden"
                    } else {
                        transcript.state = "visible"
                    }
                }
            }
        }

        // Float Frame: the playlist engine stays (folders, next file, MPRIS) but its
        // slide-in panel is gone; QuickSettings takes the right edge.
        Playlist {
            id: playlist

            property bool isReady: false

            m_mpv: mpv
            state: "hidden"
            visible: false
            height: mpv.height
            mainWindowWidth: frame.width
            fsScale: window.isFullScreen() && PlaylistSettings.bigFontFullscreen ? 1.36 : 1

            Component.onCompleted: {
                isReady = true
                window.initPlaylist()
            }

        }

        Footer {
            id: footer

            anchors.bottom: frame.bottom

            m_mpv: mpv
            playlistsManager: playlist.manager
            m_menuBarLoader: menuBarLoader
            m_header: header
            m_settingsLoader: settingsLoader
        }

        // chromeless: window title and minimize/maximize/close appear on mouse movement
        FloatingWindowControls {
            m_mpv: mpv
            width: frame.width
            anchors.top: frame.top
        }

        // Built off the startup path: the pane (three tabs, ~40 controls) is
        // created asynchronously once the window is up; opening it before that
        // finishes forces completion on the spot.
        Loader {
            id: quickSettingsLoader

            active: true
            asynchronous: true
            sourceComponent: QuickSettings {
                m_mpv: mpv
                height: mpv.height
                mainWindowWidth: frame.width
                fsScale: 1
            }
            onLoaded: HarunaApp.trace("quicksettings-loaded")

            function pane() : QuickSettings {
                if (status !== Loader.Ready) {
                    asynchronous = false   // completes the pending load synchronously
                }
                return item as QuickSettings
            }

            Connections {
                target: actions
                function onToggleQuickSettings() {
                    quickSettingsLoader.pane()?.toggle()
                }
            }
        }

        RowLayout {
            width: frame.width * 0.8 > Kirigami.Units.gridUnit * 50
                   ? Kirigami.Units.gridUnit * 50
                   : frame.width * 0.8
            anchors.centerIn: parent

            Kirigami.InlineMessage {
                id: messageBox

                Layout.fillWidth: true
                Layout.fillHeight: true
                type: Kirigami.MessageType.Error
                showCloseButton: true

                Connections {
                    target: MiscUtils
                    function onError(message) {
                        messageBox.visible = true
                        messageBox.text = message
                    }
                }
            }
        }
    }

    // Stacked above the frame so the zones win their edge pixels from the
    // panes and floating bars: the band outside the window plus a few pixels
    // inside it.
    WindowResizeHandles {
        targetWindow: window
        anchors.fill: parent
        outerSize: window.frameBand
        visible: window.chromeless && window.visibility === Window.Windowed && !mpv.cropOverlay.active
    }

    Actions {
        id: actions

        m_mpv: mpv
        playlistsManager: playlist.manager
        m_mpvContextMenuLoader: mpvContextMenuLoader
        m_osd: osd
        m_footer: footer
        m_settingsLoader: settingsLoader
        m_triggerActionPopup: triggerActionPopup
        m_openUrlPopup: openUrlPopup

        onOpenFileDialog: fileDialog.open()
        onOpenSubtitleDialog: subtitlesFileDialog.open()
    }

    MpvContextMenu {
        id: mpvContextMenuLoader

        m_mpv: mpv
    }

    SettingsWindow {
        id: settingsLoader

        m_mpv: mpv
    }

    StartupPopup {
        id: startupPopup

        m_mpv: mpv
    }

    Connections {
        target: HarunaApp
        function onQmlApplicationMouseLeave() {
            window.containsMouse = false
        }
        function onQmlApplicationMouseEnter() {
            window.containsMouse = true
        }
        function onOpenUrl(url) {
            if (GeneralSettings.appendVideoToSingleInstance) {
                let behavior = GeneralSettings.playNewFileInSingleInstance
                    ? PlaylistModel.AppendAndPlay
                    : PlaylistModel.Append

                playlist.manager.defaultPlaylist.addItem(url.toString(), behavior)
                return
            }

            window.openFile(url, RecentFilesModel.OpenedFrom.ExternalApp)
        }
        function onOpenRecentFile(url) {
            window.openFile(url, RecentFilesModel.OpenedFrom.Other)
        }
    }

    FileDialog {
        id: fileDialog

        title: KI18n.i18nc("@title:window", "Select File")
        currentFolder: GeneralSettings.fileDialogLastLocation
        fileMode: FileDialog.OpenFile

        onAccepted: {
            window.openFile(fileDialog.selectedFile, RecentFilesModel.OpenedFrom.OpenAction)
            mpv.focus = true

            GeneralSettings.fileDialogLastLocation = PathUtils.parentUrl(fileDialog.selectedFile)
            GeneralSettings.save()
        }
        onRejected: mpv.focus = true
        onVisibleChanged: {
            HarunaApp.actionsEnabled = !visible
        }
    }

    FileDialog {
        id: subtitlesFileDialog

        title: KI18n.i18nc("@title:window", "Select Subtitles File")
        currentFolder: PathUtils.parentUrl(mpv.currentUrl)
        fileMode: FileDialog.OpenFile
        nameFilters: ["Subtitles (*.srt *.ssa *.ass *.sub)"]

        onAccepted: {
            if (window.acceptedSubtitleTypes.includes(MiscUtils.mimeType(subtitlesFileDialog.selectedFile))) {
                mpv.addSubtitles(subtitlesFileDialog.selectedFile)
            }
        }
        onRejected: mpv.focus = true
        onVisibleChanged: {
            HarunaApp.actionsEnabled = !visible
        }
    }

    YouTube {
        id: youtube
    }

    InputPopup {
        id: openUrlPopup

        x: 10
        y: 10
        width: Math.min(window.width * 0.9, 600)
        lastText: GeneralSettings.lastUrl
        buttonText: KI18n.i18nc("@action:button", "Open")
        warningText: youtube.hasYoutubeDl()
                     ? ""
                     : KI18n.i18nc("@info", "Neither <a href=\"https://github.com/yt-dlp/yt-dlp\">yt-dlp</a> nor <a href=\"https://github.com/ytdl-org/youtube-dl\">youtube-dl</a> was found.")

        onSubmitted: function(url) {
            window.openFile(youtube.normalizeUrl(url), RecentFilesModel.OpenedFrom.OpenAction)

            GeneralSettings.lastUrl = url
            GeneralSettings.save()
        }
    }

    Component.onCompleted: {
        HarunaApp.trace("main-completed")
        applyFrameMargin()
        windowStateSaverLoader.active = GeneralSettings.rememberWindowGeometry
        HarunaApp.setupEventFilter(window)
        HarunaApp.activateColorScheme(GeneralSettings.colorScheme)

        const hasCommandLineFile = HarunaApp.url(0).toString() !== ""
        const hasLastPlayedFile = GeneralSettings.lastPlayedFile !== ""
        const hasFileToOpen = hasCommandLineFile || (PlaybackSettings.openLastPlayedFile && hasLastPlayedFile)
        if (GeneralSettings.fullscreenOnStartUp && hasFileToOpen) {
            toggleFullScreen()
        }
        if (!hasCommandLineFile) {
            // nothing asked for on the command line: offer Open and the recent files
            // (closes itself if the last played file gets restored)
            Qt.callLater(startupPopup.showIfIdle)
        }
    }

    function openFile(path: string, openedFrom: int) : void {
        mpv.stop()
        Models.recentFilesModel.addRecentFile(path, openedFrom)
        playlist.manager.defaultPlaylist.addItem(path, PlaylistModel.Clear)
    }

    // Size the window so the video area has exactly the displayed picture's
    // aspect (crop included): no black bars. Automatic in chromeless mode after
    // every reconfig/crop; on demand (T) in either mode. Keeps the video width,
    // adds the visible chrome (menu bar, toolbar, docked footer) to the height.
    function fitWindowToPicture(force: bool) : void {
        if (!force && !chromeless) {
            return
        }
        if (window.visibility !== Window.Windowed || !mpv.isVideo) {
            return
        }
        let aspect = mpv.pictureAspect()
        if (aspect <= 0) {
            const osd = mpv.getProperty("osd-dimensions")
            if (!osd || !osd.w || !osd.h) {
                return
            }
            const pictureWidth = osd.w - osd.ml - osd.mr
            const pictureHeight = osd.h - osd.mt - osd.mb
            if (pictureWidth <= 0 || pictureHeight <= 0) {
                return
            }
            aspect = pictureWidth / pictureHeight
        }
        const chromeHeight = (header.visible ? header.height : 0)
                           + (menuBar.visible ? menuBar.height : 0)
                           + (footer.isFloating ? 0 : footer.height)
                           + 2 * frameBand
        const sideWidth = window.width - mpv.width   // panels beside the video, and the band
        let videoWidth = mpv.width
        let videoHeight = Math.round(videoWidth / aspect)
        const maxHeight = Screen.desktopAvailableHeight - chromeHeight
        if (videoHeight > maxHeight) {
            videoHeight = maxHeight
            videoWidth = Math.round(videoHeight * aspect)
            window.width = videoWidth + sideWidth
        }
        window.height = Math.max(window.minimumHeight, videoHeight + chromeHeight)
    }

    function closeQuickSettings() : bool {
        const pane = quickSettingsLoader.item as QuickSettings
        if (pane && pane.state === "visible") {
            pane.state = "hidden"
            return true
        }
        return false
    }

    function chromelessHintText() : string {
        const shortcut = HarunaApp.actions.toggleChromelessAction.shortcut
        return KI18n.i18nc("@info:tooltip %1 is a keyboard shortcut",
                           "Chromeless window: drag to move, drag edges to resize, %1 for the window frame and menus", shortcut)
    }

    // Turning it on always persists the setting, like Haruna's other view
    // toggles; turning it off also clears the --chromeless session override.
    function toggleChromeless() : void {
        if (chromeless) {
            HarunaApp.chromelessOverride = false
            GeneralSettings.chromeless = false
        } else {
            GeneralSettings.chromeless = true
        }
        GeneralSettings.save()
    }

    function isFullScreen() : bool {
        return window.visibility === Window.FullScreen
    }

    function isMaximized() : bool {
        return window.visibility === Window.Maximized
    }

    function toggleFullScreen() : void {
        if (!isFullScreen()) {
            window.showFullScreen()
        } else {
            exitFullscreen()
        }
    }

    function exitFullscreen() : void {
        if (window.previousVisibility === Window.Maximized) {
            window.show()
            window.showMaximized()
        } else {
            window.showNormal()
        }
    }

    function resizeWindow() : void {
        if (SystemUtils.isPlatformWayland() || !GeneralSettings.resizeWindowToVideo || isFullScreen()) {
            return
        }

        window.width = mpv.videoWidth
        window.height = mpv.videoHeight
                + (footer.isFloating ? 0 : footer.height)
                + (header.visible ? header.height : 0)
                + (menuBar.visible ? menuBar.height : 0)
    }
}
