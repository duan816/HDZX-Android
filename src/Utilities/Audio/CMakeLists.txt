qt_add_library(QGCAudio STATIC
    AudioOutput.cc
    AudioOutput.h
    RecordedAlertPlayer.cc
    RecordedAlertPlayer.h
)

target_link_libraries(QGCAudio
    PUBLIC
        Qt6::Core
        Qt6::TextToSpeech
        Qt6::Multimedia
    PRIVATE
        QGCLogging
)

target_include_directories(QGCAudio
    PUBLIC
        ${CMAKE_CURRENT_SOURCE_DIR}
    PRIVATE
        ${CMAKE_SOURCE_DIR}/src/FactSystem
        ${CMAKE_SOURCE_DIR}/src/Utilities
)

target_link_libraries(${CMAKE_PROJECT_NAME} PRIVATE QGCAudio)

# Bundle the approved voice clips directly into both Windows and Android executables.
# Use the main executable so the resource initializer cannot be discarded from a static library.
file(GLOB ALERT_VOICE_FILES CONFIGURE_DEPENDS "${CMAKE_CURRENT_SOURCE_DIR}/AlertVoices/*.wav")
list(APPEND ALERT_VOICE_FILES "${CMAKE_CURRENT_SOURCE_DIR}/AlertVoices/index.json")
list(APPEND ALERT_VOICE_FILES "${CMAKE_CURRENT_SOURCE_DIR}/AlertVoices/reviewed-index.json")
if(EXISTS "${CMAKE_CURRENT_SOURCE_DIR}/AlertVoices/english-index.json")
    list(APPEND ALERT_VOICE_FILES "${CMAKE_CURRENT_SOURCE_DIR}/AlertVoices/english-index.json")
endif()
qt_add_resources(${CMAKE_PROJECT_NAME} alert_voices
    PREFIX "/audio/alerts"
    BASE "${CMAKE_CURRENT_SOURCE_DIR}/AlertVoices"
    FILES ${ALERT_VOICE_FILES}
)

target_precompile_headers(QGCAudio PRIVATE
    <QtCore/QObject>
    <QtCore/QString>
    <QtTextToSpeech/QTextToSpeech>
)
