#pragma once

// Updated from received GPS fixes, not a timer or the current HUD visibility.
class NavigationAnnouncementState
{
public:
    enum Event { None, Float, Fixed, FixedLost };
    Event update(int fix)
    {
        if (fix < 0 || fix > 8 || fix == _fix) return None;
        const int previous = _fix;
        _fix = fix;
        if (fix == 6) return Fixed;
        if (fix == 5) return Float;
        return previous == 6 && fix < 5 ? FixedLost : None;
    }
    void reset() { _fix = -1; }
private:
    int _fix = -1;
};
