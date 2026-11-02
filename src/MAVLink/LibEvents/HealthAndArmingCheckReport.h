#pragma once

#include <QtCore/QObject>
#include <QtCore/QString>

class EventHandler;
class QmlObjectListModel;

class HealthAndArmingCheckProblem : public QObject
{
    Q_OBJECT
    Q_PROPERTY(QString message      READ message        CONSTANT)
    Q_PROPERTY(QString description  READ description    CONSTANT)
    Q_PROPERTY(QString severity     READ severity       CONSTANT)
    Q_PROPERTY(QString translation  READ translation    CONSTANT)
    Q_PROPERTY(QString solution     READ solution       CONSTANT)
    Q_PROPERTY(QString explanation  READ explanation    CONSTANT)
    Q_PROPERTY(bool expanded        READ expanded       WRITE setExpanded NOTIFY expandedChanged)

public:
    HealthAndArmingCheckProblem(const QString& message, const QString& description, const QString& severity,
                               const QString& translation, const QString& solution, const QString& explanation,
                               QObject *parent = nullptr);

    const QString& message() const { return _message; }
    const QString& description() const { return _description; }
    const QString& severity() const { return _severity; }
    const QString& translation() const { return _translation; }
    const QString& solution() const { return _solution; }
    const QString& explanation() const { return _explanation; }

    bool expanded() const { return _expanded; }
    void setExpanded(bool expanded) { _expanded = expanded; emit expandedChanged(); }

signals:
    void expandedChanged();

private:
    const QString _message;
    const QString _description;
    const QString _severity;
    const QString _translation;
    const QString _solution;
    const QString _explanation;
    bool _expanded{false};
};

/*===========================================================================*/

class HealthAndArmingCheckReport : public QObject
{
    Q_OBJECT
    Q_MOC_INCLUDE("QmlObjectListModel.h")
    Q_PROPERTY(bool supported                              READ supported               NOTIFY updated)
    Q_PROPERTY(bool canArm                                 READ canArm                  NOTIFY updated)
    Q_PROPERTY(bool canTakeoff                             READ canTakeoff              NOTIFY updated)
    Q_PROPERTY(bool canStartMission                        READ canStartMission         NOTIFY updated)
    Q_PROPERTY(bool hasWarningsOrErrors                    READ hasWarningsOrErrors     NOTIFY updated)
    Q_PROPERTY(QString gpsState                            READ gpsState                NOTIFY updated)
    Q_PROPERTY(QmlObjectListModel* problemsForCurrentMode  READ problemsForCurrentMode  NOTIFY updated)

public:
    explicit HealthAndArmingCheckReport(QObject *parent = nullptr);
    ~HealthAndArmingCheckReport() override;

    bool supported() const { return _supported; }
    bool canArm() const { return _canArm; }
    bool canTakeoff() const { return _canTakeoff; }
    bool canStartMission() const { return _canStartMission; }
    bool hasWarningsOrErrors() const { return _hasWarningsOrErrors; }
    const QString& gpsState() const { return _gpsState; }
    QmlObjectListModel* problemsForCurrentMode() { return _problemsForCurrentMode; }

    void update(uint8_t compid, const EventHandler &eventHandler, int flightModeGroup);
    void setModeGroups(int takeoffModeGroup, int missionModeGroup);

signals:
    void updated();
    void newProblem(const QString &message, const QString &translation);

private:
    bool _supported{false};
    bool _canArm{true};
    bool _canTakeoff{true};
    bool _canStartMission{true};
    bool _hasWarningsOrErrors{false};
    QString _gpsState{};

    int _takeoffModeGroup{-1};
    int _missionModeGroup{-1};

    QmlObjectListModel* _problemsForCurrentMode = nullptr; ///< list of HealthAndArmingCheckProblem*
};
