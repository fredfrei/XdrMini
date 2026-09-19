#include <QGuiApplication>
#include <QCoreApplication>
#include <QQmlApplicationEngine>
#include <QQmlContext>
#include <QUrl>

#ifdef Q_OS_ANDROID
#include <QJniObject>
#endif

#include "XdrClient.h"
#include "ScanController.h"

#ifdef Q_OS_ANDROID
namespace {

void startAndroidForegroundService()
{
    const QJniObject context =
        QNativeInterface::QAndroidApplication::context();

    if (!context.isValid())
        return;

    QJniObject::callStaticMethod<void>(
        "org/fredfrei/xdrmini/XdrForegroundService",
        "start",
        "(Landroid/content/Context;)V",
        context.object<jobject>());
}

void stopAndroidForegroundService()
{
    const QJniObject context =
        QNativeInterface::QAndroidApplication::context();

    if (!context.isValid())
        return;

    QJniObject::callStaticMethod<void>(
        "org/fredfrei/xdrmini/XdrForegroundService",
        "stop",
        "(Landroid/content/Context;)V",
        context.object<jobject>());
}

} // namespace
#endif

int main(int argc, char *argv[])
{
    QGuiApplication app(argc, argv);
    QCoreApplication::setOrganizationName(QStringLiteral("FredRadio"));
    QCoreApplication::setApplicationName(QStringLiteral("XdrMini"));

#ifdef Q_OS_ANDROID
    // Der Foreground Service hält den Prozess und damit die TCP-Verbindung
    // auch beim Wechsel zu einer anderen Android-App aktiv.
    startAndroidForegroundService();

    QObject::connect(
        &app,
        &QCoreApplication::aboutToQuit,
        []() {
            stopAndroidForegroundService();
        });
#endif

    XdrClient client;
    ScanController scanController(&client);

    QQmlApplicationEngine engine;
    engine.rootContext()->setContextProperty(
        QStringLiteral("xdrClient"), &client);
    engine.rootContext()->setContextProperty(
        QStringLiteral("scanController"), &scanController);

#ifdef Q_OS_ANDROID
    engine.load(
        QUrl(QStringLiteral("qrc:/XdrMini/HandyView.qml")));
#else
    engine.load(
        QUrl(QStringLiteral("qrc:/XdrMini/Main.qml")));
#endif

    if (engine.rootObjects().isEmpty())
        return -1;

    return app.exec();
}
