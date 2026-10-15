import Foundation

public enum Stats {
    public static func median(_ values: [Double]) -> Double? {
        quantile(values, 0.5)
    }

    /// Linear-interpolation quantile (the same as R's default and NumPy's).
    public static func quantile(_ values: [Double], _ q: Double) -> Double? {
        guard !values.isEmpty else { return nil }
        let sorted = values.sorted()
        let position = q * Double(sorted.count - 1)
        let lower = Int(position.rounded(.down))
        let upper = min(lower + 1, sorted.count - 1)
        return sorted[lower] + (position - Double(lower)) * (sorted[upper] - sorted[lower])
    }

    public static func interquartileRange(_ values: [Double]) -> Double? {
        guard let q1 = quantile(values, 0.25), let q3 = quantile(values, 0.75) else { return nil }
        return q3 - q1
    }

    /// `values` must not be empty, and every value must be above zero.
    public static func geometricMean(_ values: [Double]) -> Double {
        precondition(!values.isEmpty, "Geometric mean of nothing")
        return exp(values.map { log($0) }.reduce(0, +) / Double(values.count))
    }

    /// d′ = Z(hit rate) − Z(false-alarm rate), with the log-linear fix (add 0.5 to each count)
    /// so rates of 0% or 100% do not break it (arch.md §7.6).
    public static func dPrime(hits: Int, misses: Int, falseAlarms: Int, correctRejections: Int) -> Double {
        let hitRate = (Double(hits) + 0.5) / Double(hits + misses + 1)
        let falseAlarmRate = (Double(falseAlarms) + 0.5) / Double(falseAlarms + correctRejections + 1)
        return inverseNormalCDF(hitRate) - inverseNormalCDF(falseAlarmRate)
    }

    /// The z score with cumulative probability `p`, for 0 < p < 1.
    /// Acklam's rational approximation; relative error below 1.2e-9.
    public static func inverseNormalCDF(_ p: Double) -> Double {
        precondition(p > 0 && p < 1, "p must be strictly between 0 and 1")
        let a = [-3.969683028665376e+01, 2.209460984245205e+02, -2.759285104469687e+02,
                 1.383577518672690e+02, -3.066479806614716e+01, 2.506628277459239e+00]
        let b = [-5.447609879822406e+01, 1.615858368580409e+02, -1.556989798598866e+02,
                 6.680131188771972e+01, -1.328068155288572e+01]
        let c = [-7.784894002430293e-03, -3.223964580411365e-01, -2.400758277161838e+00,
                 -2.549732539343734e+00, 4.374664141464968e+00, 2.938163982698783e+00]
        let d = [7.784695709041462e-03, 3.224671290700398e-01, 2.445134137142996e+00,
                 3.754408661907416e+00]
        let pLow = 0.02425

        func tail(_ q: Double) -> Double {
            (((((c[0] * q + c[1]) * q + c[2]) * q + c[3]) * q + c[4]) * q + c[5])
                / ((((d[0] * q + d[1]) * q + d[2]) * q + d[3]) * q + 1)
        }

        if p < pLow {
            return tail(sqrt(-2 * log(p)))
        }
        if p > 1 - pLow {
            return -tail(sqrt(-2 * log(1 - p)))
        }
        let q = p - 0.5
        let r = q * q
        return (((((a[0] * r + a[1]) * r + a[2]) * r + a[3]) * r + a[4]) * r + a[5]) * q
            / (((((b[0] * r + b[1]) * r + b[2]) * r + b[3]) * r + b[4]) * r + 1)
    }
}
