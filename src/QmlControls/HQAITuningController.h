#pragma once

#include <QtCore/QPointer>
#include <QtCore/QTimer>
#include <QtCore/QVariantList>
#include <QtNetwork/QNetworkAccessManager>
#include <QtQmlIntegration/QtQmlIntegration>

#include "FactPanelController.h"

class QNetworkReply;
class QJsonObject;
class QJsonArray;

class HQAITuningController : public FactPanelController
{
    Q_OBJECT
    QML_ELEMENT
    Q_PROPERTY(bool busy READ busy NOTIFY stateChanged)
    Q_PROPERTY(bool writing READ writing NOTIFY stateChanged)
    Q_PROPERTY(QString status READ status NOTIFY stateChanged)
    Q_PROPERTY(QString summary READ summary NOTIFY stateChanged)
    Q_PROPERTY(QString questions READ questions NOTIFY stateChanged)
    Q_PROPERTY(QVariantList proposals READ proposals NOTIFY stateChanged)
    Q_PROPERTY(bool logOnly READ logOnly NOTIFY stateChanged)
    Q_PROPERTY(bool batchActive READ batchActive NOTIFY stateChanged)
    Q_PROPERTY(quint64 planRevision READ planRevision NOTIFY stateChanged)
    Q_PROPERTY(QString backupPath READ backupPath NOTIFY stateChanged)
    Q_PROPERTY(bool keyStorageAvailable READ keyStorageAvailable CONSTANT)
    Q_PROPERTY(QString credentialStatus READ credentialStatus NOTIFY credentialsChanged)
    Q_PROPERTY(QString diagnosis READ diagnosis NOTIFY stateChanged)
    Q_PROPERTY(QString analysisOutcome READ analysisOutcome NOTIFY stateChanged)
    Q_PROPERTY(QVariantList history READ history NOTIFY stateChanged)
    Q_PROPERTY(bool rollbackAvailable READ rollbackAvailable NOTIFY stateChanged)
    Q_PROPERTY(QVariantList localRecords READ localRecords NOTIFY localRecordsChanged)
    Q_PROPERTY(QString currentRecordId READ currentRecordId NOTIFY localRecordsChanged)
    Q_PROPERTY(QVariantMap submittedHardware READ submittedHardware NOTIFY stateChanged)
    Q_PROPERTY(QString submittedProblem READ submittedProblem NOTIFY stateChanged)

public:
    explicit HQAITuningController(QObject *parent = nullptr);
    ~HQAITuningController() override;
    bool busy() const { return !_reply.isNull(); }
    bool writing() const { return !_writingFact.isNull() || _writeTimeout.isActive(); }
    QString status() const { return _status; }
    QString summary() const { return _summary; }
    QString questions() const { return _questions; }
    QVariantList proposals() const { return _proposals; }
    bool logOnly() const { return _logOnly; }
    bool batchActive() const { return _batchActive; }
    quint64 planRevision() const { return _planRevision; }
    QString backupPath() const { return _backupPath; }
    bool keyStorageAvailable() const;
    QString credentialStatus() const { return _credentialStatus; }
    QString diagnosis() const { return _diagnosis; }
    QString analysisOutcome() const { return _analysisOutcome; }
    QVariantList history() const { return _history; }
    bool rollbackAvailable() const { return !_rollbackValues.isEmpty(); }
    Q_INVOKABLE QString rememberedApiKey() const;
    Q_INVOKABLE bool rememberApiKey(const QString &key);
    Q_INVOKABLE bool forgetApiKey();
    QVariantList localRecords() const;
    QString currentRecordId() const { return _recordId; }
    QVariantMap submittedHardware() const { return _submittedHardware; }
    QString submittedProblem() const { return _submittedProblem; }
    Q_INVOKABLE void suspendWritePlan();
    Q_INVOKABLE bool saveWorkspace(const QVariantMap &workspace, bool newRecord = false);
    Q_INVOKABLE QVariantMap restoreWorkspace(const QString &id = {});
    Q_INVOKABLE bool deleteLocalRecord(const QString &id);
    Q_INVOKABLE bool stageFastLogging();
    Q_INVOKABLE bool requestParameterRefresh(const QStringList &names);
    Q_INVOKABLE bool stageLogSuggestions(const QVariantMap &hardware);
    Q_INVOKABLE bool saveSnapshot();
    Q_INVOKABLE bool prepareRollback();
    Q_INVOKABLE QVariantList availableParameters() const;
    Q_INVOKABLE void analyze(const QString &apiKey, const QString &model, const QString &problem,
                            const QStringList &names, const QVariantMap &hardware, const QVariantMap &evidence);
    Q_INVOKABLE void cancel();
    Q_INVOKABLE void analyzeLog(const QString &apiKey, const QString &model, const QString &problem, const QVariantMap &evidence, bool tuning = true);
    Q_INVOKABLE bool applyOne(int index, quint64 revision);
    Q_INVOKABLE bool applyAll(quint64 revision, const QStringList &names = {});
    Q_INVOKABLE void invalidatePlan();

signals:
    void stateChanged();
    void credentialsChanged();
    void localRecordsChanged();

private:
#ifdef HQ_AI_CONTROLLER_TESTS
    friend class HQAITuningControllerTestAccess;
#endif
    bool _usableTarget() const;
    bool _sameTarget() const;
    QString _validationError(Fact *fact, double value) const;
    void _receive(QNetworkReply *reply);
    void _sendRequest(const QString &apiKey, const QString &model, const QJsonObject &context);
    QJsonObject _requestBody(const QString &model, const QJsonObject &context) const;
    void _finishWrite(const QString &status, bool acknowledged);
    void _setStatus(const QString &status);
    bool _writeBackup(const QList<int> &indices);
    void _bindActiveVehicle();
    bool _storeBackup(const QJsonArray &changes);
    void _addHistory(const QString &action, const QString &detail = {});
    void _acceptAnalysis(const QJsonObject &result);

    QNetworkAccessManager _network;
    QPointer<QNetworkReply> _reply;
    QPointer<Vehicle> _target;
    QString _targetUid;
    QVariantMap _snapshot;
    QVariantList _proposals;
    QString _status;
    QString _summary;
    QString _questions;
    QString _diagnosis;
    QString _analysisOutcome;
    QString _credentialStatus;
    QVariantList _history;
    QVariantMap _rollbackValues;
    QPointer<Vehicle> _rollbackTarget;
    QString _rollbackUid;
    bool _logOnly = false;
    bool _batchActive = false;
    QList<int> _batchIndices;
    quint64 _planRevision = 0;
    QString _backupPath;
    QPointer<Fact> _writingFact;
    QVariant _expectedRaw;
    int _writingIndex = -1;
    quint64 _writeGeneration = 0;
    QMetaObject::Connection _ackConnection;
    QMetaObject::Connection _vehicleDestroyedConnection;
    QTimer _writeTimeout;
    QString _recordId;
    QVariantMap _workspace;
    QVariantMap _submittedHardware;
    QString _submittedProblem;
    bool _incidentAnalysis = false;
    bool _restoredHistory = false;
};
