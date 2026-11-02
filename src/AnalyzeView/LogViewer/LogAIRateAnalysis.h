#pragma once

#include <QtCore/QPointF>
#include <QtCore/QVariantMap>
#include <QtCore/QVector>
#include <algorithm>
#include <array>
#include <cmath>
#include <complex>
#include <numbers>
#include "LogAIResponsePlots.h"

// Local measurements only. No parameter writes or fixed-gain recommendations.
namespace LogAIRateAnalysis {
struct Pair { double time; double target; double actual; };

inline QVariantMap analyze(const QVector<Pair> &pairs, double excitationFloor)
{
    QVariantMap result{{"scope", "最长连续目标/实际匹配段；解锁/在空中状态未核实时只能作响应参考"},
        {"evidence_strength", "不足"}, {"std_amplitude_ratio", QVariant()}, {"lag_ms", QVariant()},
        {"lag_correlation", QVariant()}, {"overshoot_percent", QVariant()}, {"dominant_error_hz", QVariant()},
        {"spectrum", QVariantList()}, {"baseline", "缺少可用的目标/实际连续曲线；请提供对应日志字段。"}};
    if (pairs.size() < 32) return result;
    QVector<double> intervals;
    for (int i = 1; i < pairs.size(); ++i) {
        const double dt = pairs[i].time - pairs[i - 1].time;
        if (dt > 0 && dt <= 0.5) intervals.append(dt);
    }
    if (intervals.isEmpty()) return result;
    std::nth_element(intervals.begin(), intervals.begin() + intervals.size() / 2, intervals.end());
    const double dt = intervals[intervals.size() / 2];
    // Never interpolate across gaps or a state-gated flight boundary.
    int start = 0, bestStart = 0, bestEnd = 0;
    for (int i = 1; i <= pairs.size(); ++i) {
        if (i == pairs.size() || pairs[i].time - pairs[i - 1].time > std::max(0.1, dt * 3)
            || pairs[i].time <= pairs[i - 1].time) {
            if (pairs[i - 1].time - pairs[start].time > pairs[bestEnd].time - pairs[bestStart].time) {
                bestStart = start; bestEnd = i - 1;
            }
            start = i;
        }
    }
    const double duration = pairs[bestEnd].time - pairs[bestStart].time;
    if (duration < 1 || bestEnd - bestStart < 31) return result;
    // Bound work using a contiguous portion, never decimate without antialiasing.
    const int count = static_cast<int>(std::min(65536.0, duration / dt + 1));
    QVector<double> target(count), actual(count), error(count);
    int cursor = bestStart;
    double sumT = 0, sumA = 0, sumE2 = 0;
    for (int i = 0; i < count; ++i) {
        const double t = pairs[bestStart].time + i * dt;
        while (cursor < bestEnd - 1 && pairs[cursor + 1].time < t) ++cursor;
        const auto &a = pairs[cursor], &b = pairs[std::min(cursor + 1, bestEnd)];
        const double fraction = b.time > a.time ? std::clamp((t - a.time) / (b.time - a.time), 0.0, 1.0) : 0;
        target[i] = a.target + fraction * (b.target - a.target);
        actual[i] = a.actual + fraction * (b.actual - a.actual);
        error[i] = target[i] - actual[i];
        sumT += target[i]; sumA += actual[i]; sumE2 += error[i] * error[i];
    }
    const double meanT = sumT / count, meanA = sumA / count;
    double varT = 0, varA = 0;
    for (int i = 0; i < count; ++i) {
        varT += std::pow(target[i] - meanT, 2); varA += std::pow(actual[i] - meanA, 2);
    }
    result["start_seconds"] = pairs[bestStart].time;
    result["end_seconds"] = pairs[bestStart].time + (count - 1) * dt;
    result["uniform_samples"] = count;
    result["sample_rate_hz"] = 1 / dt;
    result["sampling_limit"] = dt > 0.05
        ? QStringLiteral("低采样率时间域参考：滞后分辨率受采样间隔限制，不能诊断高频噪声或确定D/陷波频率。")
        : QStringLiteral("时间域参考；误差PSD不是原始陀螺频谱，不能据此确定电机陷波。 ");
    result["target_std"] = std::sqrt(varT / count);
    result["actual_std"] = std::sqrt(varA / count);
    result["rmse"] = std::sqrt(sumE2 / count);
    result["method"] = "匹配样本线性重采样；标准差幅值比与合格比例是不同指标；互相关搜索-100~500ms；无稳定阶跃则超调未知；误差Welch PSD：Hann窗、50%重叠、去均值、单位(角速率)^2/Hz。不是电机转速或陀螺共振频谱。";
    if (std::sqrt(varT / count) < excitationFloor) {
        result["baseline"] = "目标激励过小，保持当前PID；需要有代表性的目标变化，不能由平静或未飞行曲线强制加增益。";
        return result;
    }
    const double ratio = std::sqrt(varA / varT);
    result["std_amplitude_ratio"] = ratio;
    result["response_plots"] = LogAIResponsePlots::build(target, actual, dt, pairs[bestStart].time, excitationFloor);
    result["evidence_strength"] = "基线参考（非校准概率）";
    double bestCorrelation = -2;
    int bestLag = 0;
    const int maxLag = std::min(count / 4, static_cast<int>(0.5 / dt));
    const int minLag = -std::min(count / 4, static_cast<int>(0.1 / dt));
    for (int lag = minLag; lag <= maxLag; ++lag) {
        const int begin = std::max(0, -lag), end = std::min(count, count - lag);
        double tSum = 0, aSum = 0, t2 = 0, a2 = 0, cross = 0;
        for (int i = begin; i < end; ++i) {
            const double t = target[i], a = actual[i + lag];
            tSum += t; aSum += a; t2 += t*t; a2 += a*a; cross += t*a;
        }
        const double n = end - begin;
        const double denominator = std::sqrt(std::max(0.0, (t2-tSum*tSum/n)*(a2-aSum*aSum/n)));
        const double correlation = denominator > 1e-12 ? (cross-tSum*aSum/n)/denominator : -2;
        if (correlation > bestCorrelation) { bestCorrelation = correlation; bestLag = lag; }
    }
    if (bestCorrelation >= 0.5 && bestLag != minLag && bestLag != maxLag) {
        result["lag_ms"] = bestLag * dt * 1000;
        result["lag_correlation"] = bestCorrelation;
    }
    // Only explicit, stable target steps support an overshoot estimate.
    const int pre = std::max(3, static_cast<int>(0.08 / dt));
    const int post = std::max(4, static_cast<int>(0.3 / dt));
    QVector<double> overshoots;
    for (int i = pre; i + post < count; ++i) {
        const double delta = target[i] - target[i - 1];
        if (std::abs(delta) < excitationFloor * 2) continue;
        bool stable = true;
        for (int j = i - pre; j < i; ++j) if (std::abs(target[j]-target[i-1]) > std::abs(delta)*0.15) stable = false;
        double peak = 0;
        for (int j = i; j < i + post; ++j) {
            if (std::abs(target[j]-target[i]) > std::abs(delta)*0.15) stable = false;
            peak = std::max(peak, (actual[j]-target[i]) * (delta > 0 ? 1 : -1));
        }
        if (stable) { overshoots.append(100*peak/std::abs(delta)); i += post - 1; }
    }
    result["stable_step_count"] = overshoots.size();
    if (!overshoots.isEmpty()) {
        std::sort(overshoots.begin(), overshoots.end());
        result["overshoot_percent"] = overshoots[overshoots.size()/2];
    }
    constexpr int window = 256;
    if (count >= window && dt <= 0.05) {
        std::array<double, window/2+1> power{};
        int windows = 0;
        for (int offset = 0; offset + window <= count; offset += window/2) {
            std::array<std::complex<double>, window> data;
            double mean = 0, energy = 0;
            for (int i = 0; i < window; ++i) mean += error[offset+i] / window;
            for (int i = 0; i < window; ++i) {
                const double w = 0.5 - 0.5*std::cos(2*std::numbers::pi*i/(window-1));
                data[i] = {(error[offset+i]-mean)*w, 0}; energy += w*w;
            }
            for (int i = 1, j = 0; i < window; ++i) {
                int bit = window >> 1;
                for (; j & bit; bit >>= 1) j ^= bit;
                j ^= bit;
                if (i < j) std::swap(data[i], data[j]);
            }
            for (int length = 2; length <= window; length <<= 1) {
                const auto rotation = std::polar(1.0, -2*std::numbers::pi/length);
                for (int i = 0; i < window; i += length) {
                    std::complex<double> w(1,0);
                    for (int j = 0; j < length/2; ++j) {
                        const auto a = data[i+j], b = data[i+j+length/2]*w;
                        data[i+j] = a+b; data[i+j+length/2] = a-b; w *= rotation;
                    }
                }
            }
            for (int i = 0; i <= window/2; ++i) power[i] += std::norm(data[i])*dt/energy*((i==0 || i==window/2)?1:2);
            ++windows;
        }
        QVariantList spectrum;
        int peak = 1;
        for (int i = 1; i <= window/2; ++i) {
            if (power[i] > power[peak]) peak = i;
            spectrum.append(QVariantMap{{"hz", i/(window*dt)}, {"psd", power[i]/windows}});
        }
        result["spectrum"] = spectrum;
        result["spectrum_windows"] = windows;
        result["frequency_resolution_hz"] = 1/(window*dt);
        result["nyquist_hz"] = 0.5/dt;
        if (power[peak] > 1e-12) result["dominant_error_hz"] = peak/(window*dt);
    }
    QString baseline;
    if (!result["overshoot_percent"].isNull() && result["overshoot_percent"].toDouble() > 10) {
        baseline = "稳定目标阶跃出现超调：优先复核并小步降低P、检查PD平衡。未核实滤波/噪声时不建议增加D。";
    } else if (ratio < 0.7) {
        baseline = "实际幅值不足：检查PD平衡，P偏低、D/滤波延迟过强、输出饱和均可能造成；优先核对饱和并评估小步增P。FF为零不构成直接加FF的依据。";
    } else if (ratio > 1.2) {
        baseline = "实际幅值偏大：核对目标/实际峰值、扰动及PD平衡；若过冲/自振持续，评估小步减P；不能仅用幅值比断言P过大。";
    } else {
        baseline = "幅值接近目标：保持现值并核对相位、阶跃与振荡。不要为凑建议强制改PID。";
    }
    if (!result["lag_ms"].isNull() && result["lag_ms"].toDouble() > 50)
        baseline += " 互相关提示响应延迟；先区分滤波延迟与PD平衡，再讨论前馈。";
    baseline += " 未提供PID分解/振动/滤波时仍可做以上基线判断，频率本身不能独立判定P或D故障。";
    result["baseline"] = baseline;
    return result;
}
}
