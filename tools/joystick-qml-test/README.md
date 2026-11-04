# Virtual joystick pointer regression

Run Qt 6.10 qmltestrunner with `-input tools/joystick-qml-test -import tools/joystick-qml-test/imports`, `QT_QPA_PLATFORM=offscreen`, `QML_DISABLE_DISK_CACHE=1`.

The production pad and VirtualJoystick QML are exercised with Qt mouse/touch events. Fixtures replace vehicle I/O; no flight-controller commands are sent. Cases cover both simultaneous fingers, reversed mapping, dimensions, preserved non-centering throttle, hiding, disconnect/reconnect and 120 repeated interruption/resize cycles. This does not replace Android device testing.
