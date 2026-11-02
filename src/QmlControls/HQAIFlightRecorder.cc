#include "HQAIFlightRecorder.h"
#include "HQAITuningController.h"
#include "HQAIKeyStore.h"
#include "MultiVehicleManager.h"
#include "Vehicle.h"
#include "VehicleLinkManager.h"
#include "ParameterManager.h"
#include "Fact.h"
#include "FirmwarePlugin.h"
#include "LogAIEvidence.h"
#include "LogParseResultPrivate.h"
#include <QtConcurrent/QtConcurrent>
#include <QtCore/QFutureWatcher>
#include <QtCore/QStandardPaths>
#include <QtCore/QJsonDocument>
#include <QtCore/QDateTime>
#include <QtCore/QDir>
#include <QtCore/QFileInfo>
#include <QtCore/QUuid>
#include <cmath>
#include <numbers>

HQAIFlightRecorder::HQAIFlightRecorder(QObject *parent) : QObject(parent)
{
    _cloud = new HQAITuningController(this);
    connect(MultiVehicleManager::instance(), &MultiVehicleManager::activeVehicleChanged, this, &HQAIFlightRecorder::_bind);
    connect(_cloud, &HQAITuningController::stateChanged, this, [this]() {
        if (_cloud->busy() || _cloud->summary().isEmpty()) return;
        _status = _cloud->status();
        emit stateChanged();
    });
    _status = tr("未启用；飞行中只记录，锁定后分析。");
    _bind();
}
QString HQAIFlightRecorder::aiSummary() const { return _cloud ? _cloud->summary() : QString(); }
void HQAIFlightRecorder::configure(bool enabled, bool automaticAi, const QVariantMap &hardware)
{
    if (_recording && _target && _target->armed()) { _status = tr("记录中，锁定后再修改采集配置。"); emit stateChanged(); return; }
    _enabled = enabled; _automaticAi = automaticAi; _hardware = hardware;
    _status = enabled ? tr("已启用：等待当前飞机解锁；只接收已有遥测，不请求额外频率或写入参数。") : tr("已关闭飞行采集。");
    emit stateChanged();
    if (_enabled && _vehicle && _vehicle->armed()) _start();
}
void HQAIFlightRecorder::_bind()
{
    if (_recording) _finish(false);
    for (const auto &connection : _connections) disconnect(connection);
    _connections.clear();
    _vehicle = MultiVehicleManager::instance()->activeVehicle();
    if (!_vehicle) return;
    _connections.append(connect(_vehicle, &Vehicle::armedChanged, this, [this](bool armed) {
        if (armed && _enabled) _start();
        else if (!armed && _recording) _finish(true);
    }));
    _connections.append(connect(_vehicle, &Vehicle::mavlinkMessageReceived, this, &HQAIFlightRecorder::_receive));
    _connections.append(connect(_vehicle->vehicleLinkManager(), &VehicleLinkManager::communicationLostChanged, this, [this](bool lost) { if (lost && _recording) _finish(false); }));
    _connections.append(connect(_vehicle, &QObject::destroyed, this, [this]() { if (_recording) _finish(false); }));
}
void HQAIFlightRecorder::_start()
{
    if (_recording || !_vehicle || !_vehicle->armed() || _vehicle->vehicleLinkManager()->communicationLost()) return;
    const QString directory = QStandardPaths::writableLocation(QStandardPaths::AppDataLocation)+"/ai-flight-records";
    if (!QDir().mkpath(directory)) { _status=tr("不能创建采集目录"); emit stateChanged(); return; }
    const QString base = directory+"/"+QDateTime::currentDateTimeUtc().toString("yyyyMMdd-HHmmss")+"-"+QUuid::createUuid().toString(QUuid::WithoutBraces);
    _journal.setFileName(base+".jsonl"); _reportPath = base+".report.json";
    if (!_journal.open(QIODevice::WriteOnly|QIODevice::NewOnly)) { _status=tr("不能保存飞行记录，未开始采集"); emit stateChanged(); return; }
    _target = _vehicle; _uid=_vehicle->vehicleUIDStr(); _capturedHardware=_hardware;
    _samples.clear(); _evidence.clear(); _count=0; _end=0; _clock.start(); _recording=true;
    _lastNotification=0; _cloud->cancel();
    _append("ARM.ArmState",0,1);
    _status=tr("正在记录真实遥测；不是板载高频日志。缺少目标消息将明确显示未知。");
    emit stateChanged();
}
void HQAIFlightRecorder::_append(const QString &name, double time, double value)
{
    if (!_recording || !std::isfinite(value)) return;
    _samples[name].append({time,value});
    const auto line=QJsonDocument::fromVariant(QVariantMap{{"field",name},{"seconds",time},{"value",value}}).toJson(QJsonDocument::Compact)+"\n";
    if (_journal.write(line)!=line.size()) { _finish(false); return; }
    ++_count;
}
void HQAIFlightRecorder::_receive(const mavlink_message_t &message)
{
    if (!_recording || !_target || _target!=_vehicle || _target->vehicleUIDStr()!=_uid || message.sysid!=_target->id()) return;
    const double time=_clock.elapsed()/1000.0; _end=time;
    if (message.msgid==MAVLINK_MSG_ID_PID_TUNING) {
        mavlink_pid_tuning_t data; mavlink_msg_pid_tuning_decode(&message,&data);
        const QString axis=data.axis==1?"R":data.axis==2?"P":data.axis==3?"Y":"";
        if (!axis.isEmpty()) { _append("LIVE_PID."+axis,time,data.achieved); _append("LIVE_PID."+axis+"Des",time,data.desired); }
    } else if (message.msgid==MAVLINK_MSG_ID_ATTITUDE) {
        mavlink_attitude_t data; mavlink_msg_attitude_decode(&message,&data);
        const double scale=180/std::numbers::pi;
        _append("LIVE_ATT.R",time,data.rollspeed*scale); _append("LIVE_ATT.P",time,data.pitchspeed*scale); _append("LIVE_ATT.Y",time,data.yawspeed*scale);
    } else if (message.msgid==MAVLINK_MSG_ID_ATTITUDE_TARGET) {
        mavlink_attitude_target_t data; mavlink_msg_attitude_target_decode(&message,&data);
        const double scale=180/std::numbers::pi;
        if (!(data.type_mask&1)) _append("LIVE_ATT.RDes",time,data.body_roll_rate*scale);
        if (!(data.type_mask&2)) _append("LIVE_ATT.PDes",time,data.body_pitch_rate*scale);
        if (!(data.type_mask&4)) _append("LIVE_ATT.YDes",time,data.body_yaw_rate*scale);
    } else if (message.msgid==MAVLINK_MSG_ID_SYS_STATUS) {
        mavlink_sys_status_t data; mavlink_msg_sys_status_decode(&message,&data);
        if (data.load<=1000) _append("PM.Load",time,data.load);
        if (data.voltage_battery!=UINT16_MAX) _append("BAT.Volt",time,data.voltage_battery/1000.0);
    } else if (message.msgid==MAVLINK_MSG_ID_EXTENDED_SYS_STATE) {
        mavlink_extended_sys_state_t data; mavlink_msg_extended_sys_state_decode(&message,&data);
        if (data.landed_state==MAV_LANDED_STATE_ON_GROUND || data.landed_state==MAV_LANDED_STATE_IN_AIR)
            _append("vehicle_land_detected.landed",time,data.landed_state==MAV_LANDED_STATE_ON_GROUND?1:0);
    }
    if (_count>=300000 || time>21600) _finish(false);
    if (_clock.elapsed()-_lastNotification>=1000) { _lastNotification=_clock.elapsed(); emit stateChanged(); }
}
void HQAIFlightRecorder::_finish(bool locked)
{
    if (!_recording) return;
    if (locked) {
        _end=_clock.elapsed()/1000.0;
        _samples["ARM.ArmState"].append({_end,0});
        const auto bytes=QJsonDocument::fromVariant(QVariantMap{{"field","ARM.ArmState"},{"seconds",_end},{"value",0}}).toJson(QJsonDocument::Compact)+"\n";
        if(_journal.write(bytes)!=bytes.size()) locked=false;
    }
    _recording=false; _journal.flush(); _journal.close(); _assessing=true;
    LogParseResult snapshot;
    snapshot.fieldSamples=_samples; snapshot.minTimestamp=0; snapshot.maxTimestamp=_end; snapshot.sampleCount=_count;
    snapshot.sourceType=LogParseResult::SourceType::APMDataFlash; // Converted telemetry uses explicit deg/s RATE fields.
    for (const QString axis:{"R","P","Y"}) {
        const QString prefix=_samples.contains("LIVE_PID."+axis+"Des")?"LIVE_PID.":"LIVE_ATT.";
        snapshot.fieldSamples["RATE."+axis]=_samples.value(prefix+axis); snapshot.fieldSamples["RATE."+axis+"Des"]=_samples.value(prefix+axis+"Des");
        _samples["RATE."+axis]=snapshot.fieldSamples["RATE."+axis]; _samples["RATE."+axis+"Des"]=snapshot.fieldSamples["RATE."+axis+"Des"];
    }
    if (_target) {
        snapshot.firmwareVersion=_target->firmwareTypeString()+" "+QString("%1.%2.%3").arg(_target->firmwareMajorVersion()).arg(_target->firmwareMinorVersion()).arg(_target->firmwarePatchVersion());
        for (const auto &name:_target->firmwarePlugin()->aiTuningParameterNames()) {
            Fact *const fact=_target->parameterManager()->getParameter(-1,name);
            if (fact) snapshot.parameters.append(QVariantMap{{"name",name},{"value",fact->rawValue()}});
        }
    }
    _status=locked?tr("已收到实际锁定，正在生成报告"):tr("切机/断链/存储或采集上限导致记录中止，生成不完整报告");
    const QString output=_reportPath;
    const QVariantMap hardware=_capturedHardware;
    auto *watcher=new QFutureWatcher<QVariantMap>(this);
    connect(watcher,&QFutureWatcher<QVariantMap>::finished,this,[this,watcher,locked,output,hardware]() {
        auto evidence=watcher->result(); watcher->deleteLater();
        evidence["format"]="Live MAVLink telemetry (deg/s conversion; not DataFlash/ULog)";
        evidence["user_reported_hardware"]=hardware; evidence["recording_interrupted"]=!locked;
        QFile file(output); const auto bytes=QJsonDocument::fromVariant(evidence).toJson(QJsonDocument::Compact);
        const bool saved=file.open(QIODevice::WriteOnly)&&file.write(bytes)==bytes.size()&&file.flush();
        if (_reportPath!=output) { emit stateChanged(); return; }
        _evidence=evidence; _assessing=false;
        _status=locked?tr("锁定后本地报告已生成；参数未修改。"):tr("不完整记录已保存；未触发自动AI或参数写入。");
        if (!saved) _status=tr("本地报告计算完成，但保存失败；遥测源记录仍需检查。");
        emit stateChanged(); emit reportReady();
        const QString key=locked&&_automaticAi?HQAIKeyStore::read("org.hquavcenter.hqgroundcontrol/DeepSeek"):QString();
        if (!key.isEmpty()) {
            _cloud->saveWorkspace({{"log_name",QFileInfo(output).fileName()},{"workspace","tuning"},{"log_path",""}},true);
            _cloud->analyzeLog(key,"deepseek-flash","请基于锁定后真实飞行遥测生成PID与滤波参考报告。此数据不是板载高频日志，缺少的频谱/目标不能补造。",_evidence,true);
        }
    });
    watcher->setFuture(QtConcurrent::run([snapshot]() {return LogAIEvidence::build(snapshot);}));
    emit stateChanged();
}
QVariantList HQAIFlightRecorder::fieldSamplesFiltered(const QString &name,double begin,double end,int pixels) const
{
    QVariantList result; const auto values=_samples.value(name); const int stride=std::max(1,static_cast<int>(values.size())/std::max(1,pixels*4));
    for (int i=0;i<values.size();i+=stride) if(values[i].x()>=begin&&values[i].x()<=end) result.append(QVariantMap{{"x",values[i].x()},{"y",values[i].y()}});
    return result;
}
QVariantMap HQAIFlightRecorder::fieldMinMax(const QString &name) const
{
    double low=INFINITY,high=-INFINITY;
    for(const auto &point:_samples.value(name)){low=std::min(low,point.y());high=std::max(high,point.y());}
    return std::isfinite(low)?QVariantMap{{"min",low},{"max",high}}:QVariantMap();
}
QVariantList HQAIFlightRecorder::localCaptures() const
{
    QVariantList result;
    const QDir dir(QStandardPaths::writableLocation(QStandardPaths::AppDataLocation)+"/ai-flight-records");
    for (const auto &file:dir.entryInfoList({"*.report.json"},QDir::Files,QDir::Time))
        result.append(QVariantMap{{"path",file.absoluteFilePath()},{"name",file.fileName()}});
    return result;
}
bool HQAIFlightRecorder::loadReport(const QString &path)
{
    if (_recording || _assessing) return false;
    const QString directory=QDir(QStandardPaths::writableLocation(QStandardPaths::AppDataLocation)+"/ai-flight-records").canonicalPath()+"/";
    const QString canonical=QFileInfo(path).canonicalFilePath();
    if (directory=="/" || !canonical.startsWith(directory,Qt::CaseInsensitive) || !canonical.endsWith(".report.json")) return false;
    QFile file(canonical);
    if (!file.open(QIODevice::ReadOnly) || file.size()>10000000) return false;
    const auto report=QJsonDocument::fromJson(file.readAll());
    if (!report.isObject()) return false;
    _evidence=report.object().toVariantMap(); _reportPath=canonical; _samples.clear(); _count=0;
    QFile journal(canonical.chopped(12)+".jsonl");
    if (journal.open(QIODevice::ReadOnly)) while (!journal.atEnd() && _count<300000) {
        const auto row=QJsonDocument::fromJson(journal.readLine()).object();
        const QString field=row.value("field").toString(); const double t=row.value("seconds").toDouble(),v=row.value("value").toDouble();
        if (field.isEmpty()||!std::isfinite(t)||!std::isfinite(v)) continue;
        _samples[field].append({t,v}); ++_count;
    }
    for(const QString axis:{"R","P","Y"}) {
        const QString prefix=_samples.contains("LIVE_PID."+axis+"Des")?"LIVE_PID.":"LIVE_ATT.";
        _samples["RATE."+axis]=_samples.value(prefix+axis); _samples["RATE."+axis+"Des"]=_samples.value(prefix+axis+"Des");
    }
    _end=_evidence.value("end_seconds").toDouble();
    _status=tr("已恢复本地飞行报告；只读回看，不恢复写入授权。"); emit stateChanged(); return true;
}
bool HQAIFlightRecorder::deleteCapture(const QString &path)
{
    if (_recording || _assessing) return false;
    const QString directory=QDir(QStandardPaths::writableLocation(QStandardPaths::AppDataLocation)+"/ai-flight-records").canonicalPath()+"/";
    const QString canonical=QFileInfo(path).canonicalFilePath();
    if(directory=="/"||!canonical.startsWith(directory,Qt::CaseInsensitive)||!canonical.endsWith(".report.json")) return false;
    const QString journal=QFileInfo(canonical.chopped(12)+".jsonl").canonicalFilePath();
    if(!journal.isEmpty()&&!journal.startsWith(directory,Qt::CaseInsensitive)) return false;
    const bool current=QFileInfo(_reportPath).canonicalFilePath()==canonical;
    if(!QFile::remove(canonical)) return false;
    const bool removed=journal.isEmpty()||QFile::remove(journal);
    if(current){_reportPath.clear();_evidence.clear();_samples.clear();_count=0;}
    _status=removed?tr("本地飞行报告与遥测记录已删除；飞控日志未修改。"):tr("报告已删除，遥测文件删除失败。");
    emit stateChanged(); return removed;
}
