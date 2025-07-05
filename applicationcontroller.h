#ifndef APPLICATIONCONTROLLER_H
#define APPLICATIONCONTROLLER_H

#include <QObject>
#include <QStandardPaths>
#include <QQmlEngine>
#include <QUrl>

class ApplicationController : public QObject
{
    Q_OBJECT
    QML_ELEMENT
    QML_SINGLETON

public:
    explicit ApplicationController(QObject *parent = nullptr);

public slots:
    QString getDocumentsPath();
    QString getHomePath();
    QString urlToLocalFile(const QUrl &url);
    QUrl localFileToUrl(const QString &filePath);

signals:
    void fileSelected(const QString &filePath);

private:
    QString m_lastDirectory;
};

#endif // APPLICATIONCONTROLLER_H
