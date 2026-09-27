#
# SPDX-FileCopyrightText: 2020 George Florea Bănuș <georgefb899@gmail.com>
#
# SPDX-License-Identifier: GPL-3.0-or-later
#

set(ICONS_FOLDER ${PROJECT_SOURCE_DIR}/data/icons)
set(ICON_FILES
    ${ICONS_FOLDER}/sc-apps-io.github.python2121.FloatFrame.svg
)

# used in src/CMakeLists.txt
set(DATA_ICONS ${ICON_FILES} PARENT_SCOPE)

ecm_install_icons(
    ICONS ${ICON_FILES}
    DESTINATION ${KDE_INSTALL_ICONDIR}
    THEME hicolor
)

install(FILES io.github.python2121.FloatFrame.desktop DESTINATION ${KDE_INSTALL_APPDIR})
install(FILES io.github.python2121.FloatFrame.metainfo.xml DESTINATION ${KDE_INSTALL_METAINFODIR})
