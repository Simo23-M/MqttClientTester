#include "applicationcontroller.h"
#include <QFileInfo>
#include <QFile>
#include <QDebug>

ApplicationController::ApplicationController(QObject *parent)
    : QObject(parent)
    , m_lastDirectory(QStandardPaths::writableLocation(QStandardPaths::DocumentsLocation))
{
}

QString ApplicationController::getDocumentsPath()
{
    return QStandardPaths::writableLocation(QStandardPaths::DocumentsLocation);
}

QString ApplicationController::getHomePath()
{
    return QStandardPaths::writableLocation(QStandardPaths::HomeLocation);
}

QString ApplicationController::urlToLocalFile(const QUrl &url)
{
    return url.toLocalFile();
}

QUrl ApplicationController::localFileToUrl(const QString &filePath)
{
    return QUrl::fromLocalFile(filePath);
}

bool ApplicationController::saveTextToFile(const QString &filePath, const QString &content)
{
    QFile file(filePath);
    if (!file.open(QIODevice::WriteOnly | QIODevice::Text)) {
        return false;
    }
    file.write(content.toUtf8());
    file.close();
    return true;
}
