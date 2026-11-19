package me.guslipkin.flights.data

import java.nio.ByteBuffer
import java.nio.ByteOrder
import kotlin.math.acos
import kotlin.math.asin
import kotlin.math.atan2
import kotlin.math.ceil
import kotlin.math.cos
import kotlin.math.floor
import kotlin.math.max
import kotlin.math.min
import kotlin.math.roundToLong
import kotlin.math.sin

/**
 * A geographic bounding box `(lonMin, lonMax, latMin, latMax)` in degrees.
 * Notice `lonMin` and `lonMax` may extend past ±180° when a view crosses the antimeridian.
 */
data class MapBounds(
    val lonMin: Double,
    val lonMax: Double,
    val latMin: Double,
    val latMax: Double
) {
    val lonSpan: Double get() = lonMax - lonMin
    val latSpan: Double get() = latMax - latMin
    val centerLon: Double get() = (lonMin + lonMax) / 2.0
    val centerLat: Double get() = (latMin + latMax) / 2.0
}

/** `(lon, lat)` coordinate in degrees for canvas geometry. */
data class LonLat(val lon: Double, val lat: Double)

/** `(lat, lon)` coordinate in degrees as stored on airports. */
data class LatLon(val lat: Double, val lon: Double)

/** Clipped line segment `((ax, ay), (bx, by))` in `(lon, lat)` degrees. */
data class ClippedSegment(
    val ax: Double,
    val ay: Double,
    val bx: Double,
    val by: Double
)

/**
 * One coastline polyline from `coastlines.bin`, with its precomputed bounding box
 * so polylines outside the current map view can be skipped in O(1).
 */
class Coastline(
    val xs: IntArray,
    val ys: IntArray,
    val perDegree: Double,
    val bbox: MapBounds
) {
    val size: Int get() = xs.size

    fun lonAt(index: Int): Double = xs[index].toDouble() / perDegree
    fun latAt(index: Int): Double = ys[index].toDouble() / perDegree

    fun points(): List<LonLat> = List(xs.size) { i ->
        LonLat(lonAt(i), latAt(i))
    }
}

/**
 * Natural Earth coastlines at three scales (1:110m, 1:50m, 1:10m), plus map geometry helpers
 * ported from `jotto-cli/src/flights/coast.rs` and `jotto-cli/src/flights/tui.rs`.
 */
class CoastlineData(val scales: List<List<Coastline>>) {

    /**
     * Picks the coastline scale for `latSpan` degrees of latitude and `terminalRows` rows
     * (exact match to `coast::for_view` in `jotto-cli`).
     */
    fun forTerminalView(latSpan: Double, rows: Int): List<Coastline> {
        val perDot = latSpan / (max(1, rows).toDouble() * 4.0)
        val i = when {
            perDot > COARSE_ABOVE -> 0
            perDot > MIDDLE_ABOVE -> 1
            else -> 2
        }
        return scales[min(i, scales.lastIndex)]
    }

    /**
     * Picks the coastline scale for a high-DPI mobile Canvas showing `latSpan` degrees.
     */
    fun forCanvasView(latSpan: Double): List<Coastline> {
        val i = when {
            latSpan > 75.0 -> 0
            latSpan > 14.0 -> 1
            else -> 2
        }
        return scales[min(i, scales.lastIndex)]
    }

    companion object {
        private const val COARSE_ABOVE: Double = 0.3
        private const val MIDDLE_ABOVE: Double = 0.05

        const val MAP_PADDING: Double = 0.2
        const val MIN_LAT_SPAN: Double = 4.0
        const val MIN_VIEW_LAT: Double = 0.5
        const val MAX_VIEW_LAT: Double = 200.0
        private const val CURVE_STEP: Double = 1.0

        /** Parses `coastlines.bin` (`CST1` format). */
        fun parse(bytes: ByteArray): CoastlineData {
            require(
                bytes.size >= 5 &&
                    bytes[0] == 'C'.code.toByte() &&
                    bytes[1] == 'S'.code.toByte() &&
                    bytes[2] == 'T'.code.toByte() &&
                    bytes[3] == '1'.code.toByte()
            ) {
                "coastlines.bin has the wrong magic number"
            }

            val buf = ByteBuffer.wrap(bytes).order(ByteOrder.LITTLE_ENDIAN)
            buf.position(4)
            val scaleCount = buf.get().toInt() and 0xFF
            val scales = ArrayList<List<Coastline>>(scaleCount)

            for (s in 0 until scaleCount) {
                val perDegree = (buf.int.toLong() and 0xFFFF_FFFFL).toDouble()
                val lineCount = (buf.int.toLong() and 0xFFFF_FFFFL).toInt()
                val lines = ArrayList<Coastline>(lineCount)

                for (l in 0 until lineCount) {
                    val n = (buf.int.toLong() and 0xFFFF_FFFFL).toInt()
                    var x = buf.int
                    var y = buf.int
                    val xs = IntArray(n)
                    val ys = IntArray(n)
                    xs[0] = x
                    ys[0] = y
                    var xMin = x
                    var xMax = x
                    var yMin = y
                    var yMax = y

                    for (p in 1 until n) {
                        x += buf.short.toInt()
                        y += buf.short.toInt()
                        xs[p] = x
                        ys[p] = y
                        if (x < xMin) xMin = x
                        if (x > xMax) xMax = x
                        if (y < yMin) yMin = y
                        if (y > yMax) yMax = y
                    }

                    val bbox = MapBounds(
                        lonMin = xMin.toDouble() / perDegree,
                        lonMax = xMax.toDouble() / perDegree,
                        latMin = yMin.toDouble() / perDegree,
                        latMax = yMax.toDouble() / perDegree
                    )
                    lines.add(Coastline(xs, ys, perDegree, bbox))
                }
                scales.add(lines)
            }

            return CoastlineData(scales)
        }

        /**
         * Moves a longitude by whole 360° turns to within 180° of `centre`, so views crossing
         * ±180° (e.g. centred on the Pacific) wrap seamlessly.
         */
        fun wrapLon(lon: Double, centre: Double): Double {
            return lon - ((lon - centre) / 360.0).roundToLong().toDouble() * 360.0
        }

        /**
         * Whole 360° turns to shift the world by so every copy visible in `bounds` is drawn.
         */
        fun turns(bounds: MapBounds): List<Double> {
            val first = ceil((bounds.lonMin - 360.0) / 360.0).toInt()
            val last = floor((bounds.lonMax + 360.0) / 360.0).toInt()
            if (first > last) return emptyList()
            val result = ArrayList<Double>(last - first + 1)
            for (k in first..last) {
                result.add(k.toDouble() * 360.0)
            }
            return result
        }

        /**
         * Clips the segment `(ax, ay) -> (bx, by)` to `bounds` using Liang-Barsky clipping.
         */
        fun clip(
            ax: Double,
            ay: Double,
            bx: Double,
            by: Double,
            bounds: MapBounds
        ): ClippedSegment? {
            val dx = bx - ax
            val dy = by - ay
            var t0 = 0.0
            var t1 = 1.0

            val p0 = -dx
            val q0 = ax - bounds.lonMin
            if (p0 == 0.0) {
                if (q0 < 0.0) return null
            } else {
                val t = q0 / p0
                if (p0 < 0.0) t0 = max(t0, t) else t1 = min(t1, t)
            }

            val p1 = dx
            val q1 = bounds.lonMax - ax
            if (p1 == 0.0) {
                if (q1 < 0.0) return null
            } else {
                val t = q1 / p1
                if (p1 < 0.0) t0 = max(t0, t) else t1 = min(t1, t)
            }

            val p2 = -dy
            val q2 = ay - bounds.latMin
            if (p2 == 0.0) {
                if (q2 < 0.0) return null
            } else {
                val t = q2 / p2
                if (p2 < 0.0) t0 = max(t0, t) else t1 = min(t1, t)
            }

            val p3 = dy
            val q3 = bounds.latMax - ay
            if (p3 == 0.0) {
                if (q3 < 0.0) return null
            } else {
                val t = q3 / p3
                if (p3 < 0.0) t0 = max(t0, t) else t1 = min(t1, t)
            }

            return if (t0 <= t1) {
                ClippedSegment(
                    ax = ax + t0 * dx,
                    ay = ay + t0 * dy,
                    bx = ax + t1 * dx,
                    by = ay + t1 * dy
                )
            } else {
                null
            }
        }

        /**
         * Points `(lon, lat)` a flight leg from `a` to `b` is drawn through:
         * straight (2 points) or spherical great-circle interpolation at 1° steps,
         * always taking the short way across the antimeridian.
         */
        fun legPoints(a: LonLat, b: LonLat, curved: Boolean): List<LonLat> {
            val straight = listOf(a, LonLat(wrapLon(b.lon, a.lon), b.lat))
            if (!curved) return straight

            fun unit(pt: LonLat): DoubleArray {
                val lon = Math.toRadians(pt.lon)
                val lat = Math.toRadians(pt.lat)
                return doubleArrayOf(
                    cos(lat) * cos(lon),
                    cos(lat) * sin(lon),
                    sin(lat)
                )
            }

            val p = unit(a)
            val q = unit(b)
            val dot = (p[0] * q[0] + p[1] * q[1] + p[2] * q[2]).coerceIn(-1.0, 1.0)
            val angle = acos(dot)

            if (angle < 1e-9 || Math.PI - angle < 1e-9) {
                return straight
            }

            val steps = ceil(Math.toDegrees(angle) / CURVE_STEP).toInt()
            val sinAngle = sin(angle)
            val points = ArrayList<LonLat>(steps + 1)
            points.add(a)

            for (k in 1..steps) {
                val t = k.toDouble() / steps.toDouble()
                val wa = sin((1.0 - t) * angle) / sinAngle
                val wb = sin(t * angle) / sinAngle
                val rx = wa * p[0] + wb * q[0]
                val ry = wa * p[1] + wb * q[1]
                val rz = (wa * p[2] + wb * q[2]).coerceIn(-1.0, 1.0)
                val lat = Math.toDegrees(asin(rz))
                val prevLon = points.last().lon
                val lon = wrapLon(Math.toDegrees(atan2(ry, rx)), prevLon)
                points.add(LonLat(lon, lat))
            }
            return points
        }

        /**
         * Computes map bounds `(lonMin, lonMax, latMin, latMax)` fitting `points` with padding,
         * choosing the narrowest longitude arc (even across ±180°) and widening to match
         * `aspectRatio` (screen width / screen height) scaled by `cos(midLat)`.
         */
        fun mapBounds(points: List<LatLon>, aspectRatio: Double): MapBounds {
            if (points.isEmpty()) {
                return MapBounds(-180.0, 180.0, -70.0, 70.0)
            }
            var latMin = Double.POSITIVE_INFINITY
            var latMax = Double.NEGATIVE_INFINITY
            val lons = DoubleArray(points.size)
            for (i in points.indices) {
                val p = points[i]
                if (p.lat < latMin) latMin = p.lat
                if (p.lat > latMax) latMax = p.lat
                lons[i] = p.lon
            }
            lons.sort()

            var bestGap = lons.first() + 360.0 - lons.last()
            var bestStart = lons.first()
            for (i in 0 until lons.size - 1) {
                val gap = lons[i + 1] - lons[i]
                if (gap > bestGap) {
                    bestGap = gap
                    bestStart = lons[i + 1]
                }
            }
            val lonMin = bestStart
            val lonMax = bestStart + 360.0 - bestGap

            val midLat = (latMin + latMax) / 2.0
            val midLon = (lonMin + lonMax) / 2.0
            val latScale = max(0.2, cos(Math.toRadians(midLat)))
            var latSpan = max(MIN_LAT_SPAN, (latMax - latMin) * (1.0 + 2.0 * MAP_PADDING))
            var lonSpan = (lonMax - lonMin) * (1.0 + 2.0 * MAP_PADDING)

            val want = max(0.1, aspectRatio)
            if (lonSpan * latScale / latSpan < want) {
                lonSpan = want * latSpan / latScale
            } else {
                latSpan = lonSpan * latScale / want
            }

            return MapBounds(
                lonMin = midLon - lonSpan / 2.0,
                lonMax = midLon + lonSpan / 2.0,
                latMin = midLat - latSpan / 2.0,
                latMax = midLat + latSpan / 2.0
            )
        }
    }
}
