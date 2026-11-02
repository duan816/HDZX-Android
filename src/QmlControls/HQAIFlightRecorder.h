#pragma once
#include <QtCore/QObject>
#include <QtCore/QPointer>
#include <QtCore/QFile>
#include <QtCore/QElapsedTimer>
#include <QtCore/QVariantMap>
#include <QtCore/QPointF>
#include <QtQmlIntegration/QtQmlIntegration>
#include "QGCMAVLink.h"
class Vehicle;
class HQAITuningController;

class HQAIFlightRecorder : public QObject {
    Q_OBJECT
    QML_ELEMENT
    QML_SINGLETON
    Q_PROPERTY(bool enabled READ enabled NOTIFY stateChanged)
    Q_PROPERTY(bool recording READ recording NOTIFY stateChanged)
    Q_PROPERTY(bool assessing READ assessing NOTIFY stateChanged)
    Q_PROPERTY(QString status READ status NOTIFY stateChanged)
    Q_PROPERTY(QVariantMap aiEvidence READ evidence NOTIFY stateChanged)
    Q_PROPERTY(bool parseComplete READ parseComplete NOTIFY stateChanged)
    Q_PROPERTY(int sampleCount READ sampleCount NOTIFY stateChanged)
    Q_PROPERTY(double minTimestamp READ minTimestamp NOTIFY stateChanged)
    Q_PROPERTY(double maxTimestamp READ maxTimestamp NOTIFY stateChanged)
    Q_PROPERTY(QStringList plottableFields READ fields NOTIFY stateChanged)
    Q_PROPERTY(QString reportPath READ reportPath NOTIFY stateChanged)
    Q_PROPERTY(QVariantList localCaptures READ localCaptures NOTIFY stateChanged)
    Q_PROPERTY(QString aiSummary READ aiSummary NOTIFY stateChanged)
public:
    explicit HQAIFlightRecorder(QObject *parent = nullptr);
    bool enabled() const { return _enabled; }
    bool recording() const { return _recording; }
    bool assessing() const { return _assessing; }
    bool parseComplete() const { return !_evidence.isEmpty(); }
    QString status() const { return _status; }
    QVariantMap evidence() const { return _evidence; }
    int sampleCount() const { return _count; }
    double minTimestamp() const { return 0; }
    double maxTimestamp() const { return _end; }
    QStringList fields() const { return _samples.keys(); }
    QString reportPath() const { return _reportPath; }
    QVariantList localCaptures() const;
    QString aiSummary() const;
    Q_INVOKABLE bool loadReport(const QString &path);
    Q_INVOKABLE bool deleteCapture(const QString &path);
    Q_INVOKABLE void configure(bool enabled, bool automaticAi, const QVariantMap &hardware);
    Q_INVOKABLE QVariantList fieldSamplesFiltered(const QString &name, double begin, double end, int pixels) const;
    Q_INVOKABLE QVariantMap fieldMinMax(const QString &name) const;
signals:
    void stateChanged();
    void reportReady();
private:
    void _bind();
    void _start();
    void _finish(bool locked);
    void _receive(const mavlink_message_t &message);
    void _append(const QString &name, double time, double value);
    QPointer<Vehicle> _vehicle;
    QPointer<Vehicle> _target;
    QString _uid;
    QString _status;
    bool _enabled = false, _recording = false, _automaticAi = false, _assessing = false;
    int _count = 0;
    qint64 _lastNotification = 0;
    double _end = 0;
    QElapsedTimer _clock;
    QFile _journal;
    QString _reportPath;
    QHash<QString,QVector<QPointF>> _samples;
    QVariantMap _evidence, _hardware, _capturedHardware;
    QList<QMetaObject::Connection> _connections;
    HQAITuningController *_cloud = nullptr;
};
