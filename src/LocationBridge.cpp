#include "LocationBridge.h"

#include <QCoreApplication>
#include <QGeoCoordinate>
#include <QGeoPositionInfo>
#include <QGeoPositionInfoSource>
#include <QPermissions>

LocationBridge::LocationBridge(QObject *parent)
    : QObject(parent),
      source_(QGeoPositionInfoSource::createDefaultSource(this))
{
    if (!source_) {
        setStatusText(QStringLiteral("Kein Standortdienst verfügbar"));
        return;
    }

    source_->setUpdateInterval(5000);

    connect(source_,
            &QGeoPositionInfoSource::positionUpdated,
            this,
            &LocationBridge::handlePosition);

    connect(source_,
            &QGeoPositionInfoSource::errorOccurred,
            this,
            [this](QGeoPositionInfoSource::Error error) {
                if (error == QGeoPositionInfoSource::AccessError)
                    setStatusText(QStringLiteral("Kein Zugriff auf den Standort"));
                else if (error == QGeoPositionInfoSource::ClosedError)
                    setStatusText(QStringLiteral("Standortdienst ist ausgeschaltet"));
                else
                    setStatusText(QStringLiteral("Standort momentan nicht verfügbar"));
            });
}

void LocationBridge::start()
{
    runningRequested_ = true;
    ensurePermissionAndStart();
}

void LocationBridge::stop()
{
    runningRequested_ = false;
    if (source_)
        source_->stopUpdates();
}

void LocationBridge::requestUpdate()
{
    runningRequested_ = true;
    ensurePermissionAndStart();
    if (source_)
        source_->requestUpdate(10000);
}

void LocationBridge::ensurePermissionAndStart()
{
    if (!source_) {
        setStatusText(QStringLiteral("Kein Standortdienst verfügbar"));
        return;
    }

    QLocationPermission permission;
    permission.setAccuracy(QLocationPermission::Precise);
    permission.setAvailability(QLocationPermission::WhenInUse);

    switch (qApp->checkPermission(permission)) {
    case Qt::PermissionStatus::Granted:
        beginUpdates();
        return;

    case Qt::PermissionStatus::Denied:
        setStatusText(QStringLiteral("Standortberechtigung wurde abgelehnt"));
        return;

    case Qt::PermissionStatus::Undetermined:
        setStatusText(QStringLiteral("Standortberechtigung wird angefordert"));
        qApp->requestPermission(
            permission,
            this,
            [this](const QPermission &result) {
                if (result.status() == Qt::PermissionStatus::Granted) {
                    if (runningRequested_)
                        beginUpdates();
                } else {
                    setStatusText(
                        QStringLiteral("Standortberechtigung wurde abgelehnt"));
                }
            });
        return;
    }
}

void LocationBridge::beginUpdates()
{
    if (!source_ || !runningRequested_)
        return;

    setStatusText(QStringLiteral("GPS-Standort wird ermittelt"));
    source_->startUpdates();
    source_->requestUpdate(10000);
}

void LocationBridge::handlePosition(const QGeoPositionInfo &info)
{
    if (!info.isValid() || !info.coordinate().isValid())
        return;

    latitude_ = info.coordinate().latitude();
    longitude_ = info.coordinate().longitude();

    horizontalAccuracy_ =
        info.hasAttribute(QGeoPositionInfo::HorizontalAccuracy)
            ? info.attribute(QGeoPositionInfo::HorizontalAccuracy)
            : -1.0;

    valid_ = true;
    setStatusText(QStringLiteral("Aktueller Standort vom Handy"));
    emit locationChanged();
}

void LocationBridge::setStatusText(const QString &text)
{
    if (statusText_ == text)
        return;

    statusText_ = text;
    emit statusTextChanged();
}
