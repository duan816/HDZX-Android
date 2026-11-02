#pragma once

#include <QtCore/qnumeric.h>
#include <cstdint>

namespace GPSHeading {
inline double fromRaw(uint16_t yaw)
{
    // MAVLink GPS_RAW_INT/GPS2_RAW: zero is absent, UINT16_MAX is invalid,
    // and 36000 denotes a valid north-facing heading (0 degrees).
    return yaw == 0 || yaw > 36000 ? qQNaN() : (yaw % 36000) / 100.0;
}
}
