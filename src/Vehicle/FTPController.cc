#include "FTPController.h"

#include "QGCArchiveModel.h"
#include "QGCCompression.h"
#include "QGCCompressionJob.h"
#include "FTPManager.h"
#include "MultiVehicleManager.h"
#include "QGCFileHelper.h"
#include "Vehicle.h"
#include "VehicleLinkManager.h"
#include "StoragePathPolicy.h"

#include <QtCore/QDir>
#include <QtCore/QFileInfo>

#include <cmath>
#include <limits>

QGC_LOGGING_CATEGORY(FTPControllerLog, "Vehicle.FTPController")

FTPController::FTPController(QObject *parent)
    : QObject(parent)
    , _vehicle(MultiVehicleManager::instance()->activeVehicle())
    , _ftpManager(_vehicle ? _vehicle->ftpManager() : nullptr)
    , _archiveModel(new QGCArchiveModel(this))
{
    if(!_ftpManager)return;
    connect(_ftpManager, &FTPManager::downloadComplete, this, &FTPController::_handleDownloadComplete);
    connect(_ftpManager, &FTPManager::uploadComplete, this, &FTPController::_handleUploadComplete);
    connect(_ftpManager, &FTPManager::listDirectoryComplete, this, &FTPController::_handleDirectoryComplete);
    connect(_ftpManager, &FTPManager::commandProgress, this, &FTPController::_handleCommandProgress);
    connect(_ftpManager, &FTPManager::deleteComplete, this, &FTPController::_handleDeleteComplete);
    connect(_vehicle,&QObject::destroyed,this,[this](){_ftpManager=nullptr;_setBusy(false);_clearOperation();_resetDirectoryState();_setErrorString(tr("目标飞控已断开，旧页面不能操作新连接。"));});
    connect(MultiVehicleManager::instance(),&MultiVehicleManager::activeVehicleChanged,this,[this](Vehicle* vehicle){if(vehicle!=_vehicle&&_busy)cancelActiveOperation();});
    const auto stopUnsafeWrite = [this]() {
        if (_vehicle && (_vehicle->armed() || _vehicle->flying()) &&
            (_operation == Operation::Upload || _operation == Operation::Delete || _operation == Operation::Metadata)) {
            cancelActiveOperation();
            _setErrorString(tr("飞行器已解锁或起飞，停止存储卡修改。已写入的数据不会自动回滚，请落地后核对文件。"));
        }
    };
    connect(_vehicle, &Vehicle::armedChanged, this, stopUnsafeWrite);
    connect(_vehicle, &Vehicle::flyingChanged, this, stopUnsafeWrite);
}
FTPController::~FTPController(){if(_ftpManager){disconnect(_ftpManager,nullptr,this,nullptr);if(_busy)cancelActiveOperation();}}
Vehicle* FTPController::targetVehicle()const{return _vehicle.data();}
bool FTPController::_ready(bool writing){
    if(!_vehicle||!_ftpManager||_vehicle!=MultiVehicleManager::instance()->activeVehicle()||_vehicle->vehicleLinkManager()->communicationLost()) {_setErrorString(tr("目标飞控不可用或主调试已切换，请重新打开存储卡页面。"));return false;}
    if(writing&&(_vehicle->armed()||_vehicle->flying())){_setErrorString(tr("飞行器已解锁或在飞行，禁止修改存储卡。"));return false;}
    return true;
}

bool FTPController::_writablePath(const QString& uri)
{
    // The card UI only writes ordinary, absolute paths. Reject URI aliases and
    // traversal rather than relying on the remote firmware to protect @SYS.
    if (!StoragePathPolicy::writable(uri)) {
        _setErrorString(tr("写入路径无效；虚拟系统目录只读，且禁止 URI 别名和跨目录路径。"));
        return false;
    }
    return true;
}

bool FTPController::listDirectory(const QString &uri, int componentId)
{
    if(!_ready(false))return false;
    if (_operation != Operation::None) {
        _setErrorString(tr("Another FTP operation is in progress"));
        return false;
    }

    const QString previousPath = _currentPath;

    _resetDirectoryState();
    _currentPath = uri;
    emit currentPathChanged();
    _setErrorString(QString());

    _setBusy(true);
    _setOperation(Operation::List);
    _progress = 0.0F;
    emit progressChanged();

    const uint8_t compId = _componentIdForRequest(componentId);
    if (!_ftpManager->listDirectory(compId, uri)) {
        qCWarning(FTPControllerLog) << "Failed to start list operation for" << uri;
        _setErrorString(tr("Failed to list %1").arg(uri));
        _currentPath = previousPath;
        emit currentPathChanged();
        _setBusy(false);
        _clearOperation();
        return false;
    }

    return true;
}

bool FTPController::downloadFile(const QString &uri, const QString &localDir, const QString &fileName, int componentId)
{
    if(!_ready(false))return false;
    if (_operation != Operation::None) {
        const QString error = tr("Another FTP operation is in progress");
        _setErrorString(error);
        emit downloadComplete(QString(), error);
        return false;
    }

    if (!QGCFileHelper::ensureDirectoryExists(localDir)) {
        const QString error = tr("Could not create directory %1").arg(localDir);
        _setErrorString(error);
        emit downloadComplete(QString(), error);
        return false;
    }

    const QString absoluteLocalDir = QDir(localDir).absolutePath();

    _lastDownloadFile.clear();
    emit lastDownloadFileChanged();
    _setErrorString(QString());

    _setBusy(true);
    _setOperation(Operation::Download);
    _progress = 0.0F;
    emit progressChanged();

    const uint8_t compId = _componentIdForRequest(componentId);
    if (!_ftpManager->download(compId, uri, absoluteLocalDir, fileName)) {
        qCWarning(FTPControllerLog) << "Failed to start download" << uri << absoluteLocalDir;
        const QString error = tr("Failed to download %1").arg(uri);
        _setErrorString(error);
        _setBusy(false);
        _clearOperation();
        emit downloadComplete(QString(), error);
        return false;
    }

    return true;
}

bool FTPController::uploadFile(const QString &localFile, const QString &uri, int componentId)
{
    if(!_ready(true))return false;
    if(!_writablePath(uri))return false;
    if (_operation != Operation::None) {
        const QString error = tr("Another FTP operation is in progress");
        _setErrorString(error);
        emit uploadComplete(QString(), error);
        return false;
    }

    QFileInfo sourceInfo(localFile);
    if (!sourceInfo.exists() || !sourceInfo.isFile()) {
        const QString error = tr("File %1 does not exist").arg(localFile);
        _setErrorString(error);
        emit uploadComplete(QString(), error);
        return false;
    }

    _lastUploadTarget.clear();
    emit lastUploadTargetChanged();
    _setErrorString(QString());

    _setBusy(true);
    _setOperation(Operation::Upload);
    _progress = 0.0F;
    emit progressChanged();

    const uint8_t compId = _componentIdForRequest(componentId);
    if (!_ftpManager->upload(compId, uri, sourceInfo.absoluteFilePath())) {
        qCWarning(FTPControllerLog) << "Failed to start upload" << sourceInfo.absoluteFilePath() << uri;
        const QString error = tr("Failed to upload %1").arg(sourceInfo.fileName());
        _setErrorString(error);
        _setBusy(false);
        _clearOperation();
        emit uploadComplete(QString(), error);
        return false;
    }

    return true;
}

bool FTPController::deleteFile(const QString &uri, int componentId)
{
    if(!_ready(true))return false;
    if(!_writablePath(uri))return false;
    if (_operation != Operation::None) {
        const QString error = tr("Another FTP operation is in progress");
        _setErrorString(error);
        emit deleteComplete(QString(), error);
        return false;
    }

    _setErrorString(QString());
    _setBusy(true);
    _setOperation(Operation::Delete);

    const uint8_t compId = _componentIdForRequest(componentId);
    if (!_ftpManager->deleteFile(compId, uri)) {
        qCWarning(FTPControllerLog) << "Failed to start delete" << uri;
        const QString error = tr("Failed to delete %1").arg(uri);
        _setErrorString(error);
        _setBusy(false);
        _clearOperation();
        emit deleteComplete(QString(), error);
        return false;
    }

    return true;
}

void FTPController::cancelActiveOperation()
{
    if(!_ftpManager){_clearOperation();_setBusy(false);return;}
    switch (_operation) {
    case Operation::Download:
        _ftpManager->cancelDownload();
        break;
    case Operation::Upload:
        _ftpManager->cancelUpload();
        break;
    case Operation::List:
        _ftpManager->cancelListDirectory();
        break;
    case Operation::Delete:
    case Operation::Metadata:
        _ftpManager->cancelDelete();
        break;
    case Operation::None:
        break;
    }
}

void FTPController::_handleDownloadComplete(const QString &filePath, const QString &error)
{
    if (_operation != Operation::Download) {
        return;
    }

    _setBusy(false);

    if (error.isEmpty()) {
        if (!filePath.isEmpty()) {
            _lastDownloadFile = filePath;
            _lastDownloadIsArchive = QGCCompression::isArchiveFile(filePath);
            emit lastDownloadFileChanged();
        }
        _setErrorString(QString());
    } else {
        _setErrorString(error);
        _lastDownloadFile.clear();
        _lastDownloadIsArchive = false;
        emit lastDownloadFileChanged();
    }

    _clearOperation();
    emit downloadComplete(filePath,error);
}

void FTPController::_handleUploadComplete(const QString &remotePath, const QString &error)
{
    if (_operation != Operation::Upload) {
        return;
    }

    _setBusy(false);

    if (error.isEmpty()) {
        _lastUploadTarget = remotePath;
        emit lastUploadTargetChanged();
        _setErrorString(QString());
    } else {
        _setErrorString(error);
        _lastUploadTarget.clear();
        emit lastUploadTargetChanged();
    }

    _clearOperation();
    emit uploadComplete(remotePath,error);
}

void FTPController::_handleDirectoryComplete(const QStringList &entries, const QString &error)
{
    if (_operation != Operation::List) {
        return;
    }

    _setBusy(false);

    if (error.isEmpty()) {
        if (_directoryEntries != entries) {
            _directoryEntries = entries;
            emit directoryEntriesChanged();
        }
        _setErrorString(QString());
    } else {
        _setErrorString(error);
        _resetDirectoryState();
    }

    _clearOperation();
}

void FTPController::_handleDeleteComplete(const QString &remotePath, const QString &error)
{
    Q_UNUSED(remotePath)

    if (_operation != Operation::Delete && _operation!=Operation::Metadata) {
        return;
    }

    _setBusy(false);
    const bool metadata=_operation==Operation::Metadata;

    if (error.isEmpty()) {
        _setErrorString(QString());
    } else {
        _setErrorString(error);
    }

    _clearOperation();
    if(metadata)emit metadataComplete(remotePath,error);else emit deleteComplete(remotePath,error);
}

bool FTPController::createDirectory(const QString& uri){
    if(!_writablePath(uri))return false;
    if(!_ready(true)||_busy||_ftpManager->busy())return false;
    _setErrorString({});_setOperation(Operation::Metadata);_setBusy(true);
    if(!_ftpManager->createDirectory(MAV_COMP_ID_AUTOPILOT1,uri)){_clearOperation();_setBusy(false);_setErrorString(tr("无法开始新建文件夹。"));return false;}return true;
}
bool FTPController::renameEntry(const QString& from,const QString& to){
    if(!_writablePath(from)||!_writablePath(to))return false;
    if(!_ready(true)||_busy||_ftpManager->busy())return false;
    _setErrorString({});_setOperation(Operation::Metadata);_setBusy(true);
    if(!_ftpManager->renameEntry(MAV_COMP_ID_AUTOPILOT1,from,to)){_clearOperation();_setBusy(false);_setErrorString(tr("无法开始重命名。"));return false;}return true;
}

void FTPController::_handleCommandProgress(float value)
{
    if (_operation == Operation::Download || _operation == Operation::Upload) {
        if (std::fabs(_progress - value) > std::numeric_limits<float>::epsilon()) {
            _progress = value;
            emit progressChanged();
        }
    }
}

void FTPController::_setBusy(bool busy)
{
    if (_busy == busy) {
        return;
    }

    _busy = busy;
    emit busyChanged();
}

void FTPController::_setOperation(Operation operation)
{
    if (_operation == operation) {
        return;
    }

    _operation = operation;
    emit activeOperationChanged();
}

void FTPController::_clearOperation()
{
    _setOperation(Operation::None);
    if (std::fabs(_progress) > std::numeric_limits<float>::epsilon()) {
        _progress = 0.0F;
        emit progressChanged();
    }
}

void FTPController::_setErrorString(const QString &error)
{
    if (_errorString == error) {
        return;
    }

    _errorString = error;
    emit errorStringChanged();
}

void FTPController::_resetDirectoryState()
{
    if (!_directoryEntries.isEmpty()) {
        _directoryEntries.clear();
        emit directoryEntriesChanged();
    }
}

uint8_t FTPController::_componentIdForRequest(int componentId) const
{
    if (componentId <= 0 || componentId > std::numeric_limits<uint8_t>::max()) {
        return MAV_COMP_ID_AUTOPILOT1;
    }

    return static_cast<uint8_t>(componentId);
}

bool FTPController::browseArchive(const QString &archivePath)
{
    if (archivePath.isEmpty()) {
        _setErrorString(tr("No archive path specified"));
        return false;
    }

    if (!QFile::exists(archivePath)) {
        _setErrorString(tr("Archive file not found: %1").arg(archivePath));
        return false;
    }

    if (!QGCCompression::isArchiveFile(archivePath)) {
        _setErrorString(tr("Not a supported archive format: %1").arg(archivePath));
        return false;
    }

    _archiveModel->setArchivePath(archivePath);
    _setErrorString(QString());
    return true;
}

bool FTPController::extractArchive(const QString &archivePath, const QString &outputDir)
{
    if (_extracting) {
        _setErrorString(tr("Extraction already in progress"));
        return false;
    }

    if (archivePath.isEmpty()) {
        _setErrorString(tr("No archive path specified"));
        return false;
    }

    if (!QFile::exists(archivePath)) {
        _setErrorString(tr("Archive file not found: %1").arg(archivePath));
        return false;
    }

    QString targetDir = outputDir;
    if (targetDir.isEmpty()) {
        targetDir = QFileInfo(archivePath).absolutePath();
    }

    if (!QGCFileHelper::ensureDirectoryExists(targetDir)) {
        _setErrorString(tr("Could not create output directory: %1").arg(targetDir));
        return false;
    }

    _extractionOutputDir = targetDir;

    if (_extractionJob == nullptr) {
        _extractionJob = new QGCCompressionJob(this);
        connect(_extractionJob, &QGCCompressionJob::progressChanged,
                this, &FTPController::_handleExtractionProgress);
        connect(_extractionJob, &QGCCompressionJob::finished,
                this, &FTPController::_handleExtractionFinished);
    }

    _extracting = true;
    _extractionProgress = 0.0F;
    emit extractingChanged();
    emit extractionProgressChanged();

    _extractionJob->extractArchive(archivePath, targetDir);
    return true;
}

void FTPController::cancelExtraction()
{
    if (_extractionJob != nullptr && _extracting) {
        _extractionJob->cancel();
    }
}

void FTPController::_handleExtractionProgress(qreal progress)
{
    const auto newProgress = static_cast<float>(progress);
    if (std::fabs(_extractionProgress - newProgress) > std::numeric_limits<float>::epsilon()) {
        _extractionProgress = newProgress;
        emit extractionProgressChanged();
    }
}

void FTPController::_handleExtractionFinished(bool success)
{
    _extracting = false;
    emit extractingChanged();

    if (success) {
        _setErrorString(QString());
        emit extractionComplete(_extractionOutputDir, QString());
    } else {
        const QString error = _extractionJob != nullptr ? _extractionJob->errorString() : tr("Extraction failed");
        _setErrorString(error);
        emit extractionComplete(QString(), error);
    }

    _extractionProgress = 0.0F;
    emit extractionProgressChanged();
}
