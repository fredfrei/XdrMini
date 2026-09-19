#include <QGuiApplication>
#include <QQmlApplicationEngine>
#include <QQmlContext>
#include <QUrl>

#include "XdrClient.h"
#include "ScanController.h"

int main(int argc, char *argv[])
{
    QGuiApplication app(argc, argv);
    QCoreApplication::setOrganizationName(QStringLiteral("FredRadio"));
    QCoreApplication::setApplicationName(QStringLiteral("XdrMini"));

    XdrClient client;
    ScanController scanController(&client);

    QQmlApplicationEngine engine;
    engine.rootContext()->setContextProperty(
        QStringLiteral("xdrClient"), &client);
    engine.rootContext()->setContextProperty(
        QStringLiteral("scanController"), &scanController);

#ifdef Q_OS_ANDROID
    engine.load(QUrl(QStringLiteral("qrc:/XdrMini/HandyView.qml")));
#else
    engine.load(QUrl(QStringLiteral("qrc:/XdrMini/HandyView.qml")));
#endif

    if (engine.rootObjects().isEmpty())
        return -1;

    return app.exec();
}
