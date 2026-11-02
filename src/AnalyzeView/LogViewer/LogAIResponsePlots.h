#pragma once
#include <QtCore/QVariantMap>
#include <QtCore/QVector>
#include <algorithm>
#include <cmath>
#include <complex>
#include <numbers>

namespace LogAIResponsePlots {
inline void transform(QVector<std::complex<double>> &values, bool inverse = false)
{
    const int n = values.size();
    for (int i = 1, j = 0; i < n; ++i) {
        int bit = n >> 1;
        for (; j & bit; bit >>= 1) j ^= bit;
        j ^= bit;
        if (i < j) std::swap(values[i], values[j]);
    }
    for (int length = 2; length <= n; length <<= 1) {
        const auto rotation = std::polar(1.0, (inverse ? 2 : -2)*std::numbers::pi/length);
        for (int i = 0; i < n; i += length) {
            std::complex<double> w(1,0);
            for (int j = 0; j < length/2; ++j) {
                const auto a = values[i+j], b = values[i+j+length/2]*w;
                values[i+j] = a+b; values[i+j+length/2] = a-b; w *= rotation;
            }
        }
    }
    if (inverse) for (auto &value : values) value /= n;
}
inline QVariantMap build(const QVector<double> &target, const QVector<double> &actual, double dt, double start, double floor)
{
    QVariantMap result{{"method", "512点Hann窗、50%重叠；功率谱密度dB相对1原单位²/Hz。阶跃采用窗口频域Y*conj(X)/(abs(X)^2+正则项)逆FFT并积分，参考ArduPilot PIDReview思路，正则参数不同；不是观测到的真实阶跃，也不是最终整定。"},
        {"step_status", "激励/连续样本不足，不能估计阶跃"}, {"step_mean", QVariantList()},
        {"step_curves", QVariantList()}, {"spectrogram", QVariantList()}, {"frequency_bins", QVariantList()}};
    constexpr int window = 512;
    if (target.size() < window || dt <= 0 || dt > 0.05) return result;
    const int totalWindows = (target.size()-window)/(window/2)+1;
    const int imageStride = std::max(1, (totalWindows+95)/96);
    const int stepLength = std::min(window/2, static_cast<int>(0.5/dt)+1);
    QVector<double> stepSum(stepLength, 0);
    QVector<double> powerX(window/2+1, 0), powerY(window/2+1, 0);
    QVector<std::complex<double>> cross(window/2+1, {0,0});
    QVariantList frames, curves, frequencies, bands;
    int steps = 0;
    double lowDb = INFINITY, highDb = -INFINITY;
    for (int offset = 0, frameIndex = 0; offset+window <= target.size(); offset += window/2, ++frameIndex) {
        QVector<std::complex<double>> x(window), y(window), error(window);
        double energy = 0, maximum = 0;
        double meanX = 0, meanY = 0;
        for (int i = 0; i < window; ++i) { meanX += target[offset+i]/window; meanY += actual[offset+i]/window; }
        for (int i = 0; i < window; ++i) {
            const double w = 0.5-0.5*std::cos(2*std::numbers::pi*i/(window-1));
            x[i] = {target[offset+i]*w,0}; y[i] = {actual[offset+i]*w,0};
            error[i] = {(target[offset+i]-actual[offset+i]-meanX+meanY)*w,0};
            energy += w*w; maximum = std::max(maximum, std::abs(target[offset+i]));
        }
        transform(x); transform(y); transform(error);
        QVariantList aDb, tDb, eDb;
        double framePeak = 0, peakHz = 0, lowBand = 0, midBand = 0, highBand = 0;
        for (int bin = 1; bin <= window/2; ++bin) {
            const double correction = (bin==window/2?1:2)*dt/energy;
            const double psd = std::norm(y[bin])*correction;
            const double hz = bin/(window*dt);
            powerX[bin] += std::norm(x[bin]); powerY[bin] += std::norm(y[bin]); cross[bin] += y[bin]*std::conj(x[bin]);
            if (psd > framePeak) { framePeak = psd; peakHz = hz; }
            if (hz < 10) lowBand += psd/(window*dt); else if (hz < 30) midBand += psd/(window*dt); else highBand += psd/(window*dt);
            if (frameIndex % imageStride == 0) {
                const double db = 10*std::log10(std::max(1e-15,psd));
                aDb.append(db);
                tDb.append(10*std::log10(std::max(1e-15,std::norm(x[bin])*correction)));
                eDb.append(10*std::log10(std::max(1e-15,std::norm(error[bin])*correction)));
                lowDb = std::min(lowDb,db); highDb = std::max(highDb,db);
            }
        }
        const double time = start + (offset+window/2)*dt;
        if (!aDb.isEmpty()) {
            frames.append(QVariantMap{{"time", time}, {"actual_db", aDb}, {"target_db", tDb}, {"error_db", eDb}});
            bands.append(QVariantMap{{"time",time}, {"actual_peak_hz",peakHz}, {"low_power",lowBand}, {"mid_power",midBand}, {"high_power",highBand}});
        }
        // Estimate a local linear response only where real target excitation is present.
        if (maximum < floor*4) continue;
        double largest = 0;
        for (const auto &value : x) largest = std::max(largest,std::norm(value));
        if (largest < 1e-12) continue;
        QVector<std::complex<double>> transfer(window);
        for (int i = 0; i < window; ++i) {
            const int bin = std::min(i,window-i);
            const double frequency = bin/(window*dt);
            // Frequency-dependent regularisation damps unsupported/noisy high bins.
            const double regularisation = largest * 0.0001 * (1+std::pow(frequency/25,4));
            transfer[i] = y[i]*std::conj(x[i])/(std::norm(x[i])+regularisation);
        }
        transform(transfer,true);
        QVector<double> response(stepLength);
        double integral = 0;
        bool finite = true;
        for (int i = 0; i < stepLength; ++i) {
            integral += transfer[i].real(); response[i] = integral;
            if (!std::isfinite(integral) || std::abs(integral)>10) finite = false;
        }
        if (!finite) continue;
        ++steps;
        for (int i = 0; i < stepLength; ++i) stepSum[i] += response[i];
        if (curves.size() < 24) {
            QVariantList curve;
            const int stride = std::max(1,stepLength/80);
            for (int i = 0; i < stepLength; i += stride) curve.append(QVariantMap{{"seconds",i*dt},{"response",response[i]}});
            curves.append(QVariant::fromValue(curve));
        }
    }
    for (int i = 1; i <= window/2; ++i) frequencies.append(i/(window*dt));
    result["spectrogram"] = frames; result["frequency_bins"] = frequencies; result["spectral_bands"] = bands;
    result["db_min"] = std::isfinite(lowDb) ? QVariant(lowDb) : QVariant();
    result["db_max"] = std::isfinite(highDb) ? QVariant(highDb) : QVariant();
    result["frame_count"] = totalWindows; result["display_frame_count"] = frames.size();
    result["frequency_resolution_hz"] = 1/(window*dt);
    result["nyquist_hz"] = 0.5/dt;
    double coherent = 0, weight = 0;
    for (int i = 1; i <= window/2; ++i) if (i/(window*dt) <= 30 && powerX[i]*powerY[i]>1e-12) {
        coherent += std::clamp(std::norm(cross[i])/(powerX[i]*powerY[i]),0.0,1.0)*powerX[i]; weight += powerX[i];
    }
    result["coherence_below_30hz"] = weight > 0 ? QVariant(coherent/weight) : QVariant();
    result["step_windows"] = steps;
    if (steps >= 3 && weight > 0 && coherent/weight >= 0.25) {
        QVariantList mean;
        const int stride = std::max(1,stepLength/80);
        for (int i = 0; i < stepLength; i += stride) mean.append(QVariantMap{{"seconds",i*dt},{"response",stepSum[i]/steps}});
        result["step_mean"] = mean; result["step_curves"] = curves;
        result["response_at_window_end"] = stepSum.last()/steps;
        result["step_status"] = "频域估计：灰线为窗口估计、青线为均值；虚线1是单位目标。0.5s截断不是最终稳态，不保证唯一定位PD故障。";
    } else result["step_status"] = "目标激励或输入/输出相干性不足；频谱可查看，阶跃估计未知";
    return result;
}
}
