#include "applicationcontroller.h"
#include <QFileInfo>
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
