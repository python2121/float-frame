/*
 * SPDX-FileCopyrightText: 2026 George Florea Bănuș <georgefb899@gmail.com>
 *
 * SPDX-License-Identifier: GPL-3.0-or-later
 */

#ifndef COMMANDLINEOPTIONS_H
#define COMMANDLINEOPTIONS_H

#include <QCommandLineParser>
#include <QObject>
#include <QUrl>
#include <qqmlintegration.h>

class QJSEngine;
class QQmlEngine;

class CommandLineOptions : public QObject
{
    Q_OBJECT
    QML_ELEMENT
    QML_SINGLETON

public:
    static CommandLineOptions &instance();
    static CommandLineOptions *create(QQmlEngine *, QJSEngine *);

    Q_PROPERTY(QList<QUrl> startupUrls READ startupUrls WRITE setStartupUrls NOTIFY startupUrlsChanged FINAL)
    // --chromeless: start with the frameless, chrome-free window (Float Frame)
    Q_PROPERTY(bool chromeless READ chromeless CONSTANT FINAL)
    bool chromeless() const;
    Q_SIGNAL void startupUrlsChanged();
    QList<QUrl> startupUrls() const;
    void setStartupUrls(const QList<QUrl> &newStartupUrls);

    std::shared_ptr<QCommandLineParser> parser() const;

private:
    explicit CommandLineOptions(QObject *parent = nullptr);
    QList<QUrl> m_startupUrls;
    bool m_chromeless{false};
    std::shared_ptr<QCommandLineParser> m_parser;
};

#endif // COMMANDLINEOPTIONS_H
