package me.guslipkin.flights.data

import java.time.Instant

/**
 * Exact 64-bit Kotlin port of Rust's `fastrand 2.5.0` (`Rng(u64)` using WyRand v4.2 and Lemire's
 * nearly divisionless `gen_mod_u64`), plus deterministic UTC daily helpers from `jotto-cli`.
 *
 * Ensures that `Network.dailyPuzzle` on Android deals the exact same daily puzzle as `flights --daily`
 * in `jotto-cli` on every UTC day.
 */
class Fastrand(seed: ULong = defaultSeed()) {
    var state: ULong = seed
        private set

    fun genU64(): ULong {
        val s = state + WY_CONST_0
        state = s
        val b = s xor WY_CONST_1
        val lo = s * b
        val hi = mulHighU64(s, b)
        return lo xor hi
    }

    fun genModU64(n: ULong): ULong {
        require(n > 0uL) { "Empty range in genModU64" }
        var r = genU64()
        var hi = mulHighU64(r, n)
        var lo = r * n
        if (lo < n) {
            val t = (0uL - n) % n
            while (lo < t) {
                r = genU64()
                hi = mulHighU64(r, n)
                lo = r * n
            }
        }
        return hi
    }

    /** Equivalent to `rng.usize(0..n)` on 64-bit targets. */
    fun usize(n: Int): Int {
        require(n > 0) { "Empty range: 0..$n" }
        return genModU64(n.toULong()).toInt()
    }

    /** Equivalent to `rng.shuffle(&mut slice)` in `fastrand 2.5.0`. */
    fun <T> shuffle(list: MutableList<T>) {
        for (i in 1 until list.size) {
            val j = genModU64((i + 1).toULong()).toInt()
            val tmp = list[i]
            list[i] = list[j]
            list[j] = tmp
        }
    }

    fun shuffleIntArray(array: IntArray) {
        for (i in 1 until array.size) {
            val j = genModU64((i + 1).toULong()).toInt()
            val tmp = array[i]
            array[i] = array[j]
            array[j] = tmp
        }
    }

    companion object {
        private const val WY_CONST_0: ULong = 0x2d35_8dcc_aa6c_78a5uL
        private const val WY_CONST_1: ULong = 0x8bb8_4b93_962e_acc9uL

        /** Fixed UTC epoch day (2024-01-01 UTC = 19,723 days since 1970-01-01). */
        const val DAILY_EPOCH_DAY: ULong = 19_723uL

        /** Fixed seed for `flights` daily puzzles (`"FLIGHTS!"`). */
        const val DAILY_SEED: ULong = 0x464C_4947_4854_5321uL

        /** Computes the upper 64 bits of the 128-bit unsigned product `a * b`. */
        fun mulHighU64(a: ULong, b: ULong): ULong {
            val aLo = a and 0xFFFF_FFFFuL
            val aHi = a shr 32
            val bLo = b and 0xFFFF_FFFFuL
            val bHi = b shr 32

            val p0 = aLo * bLo
            val p1 = aHi * bLo
            val p2 = aLo * bHi
            val p3 = aHi * bHi

            val middle = (p0 shr 32) + (p1 and 0xFFFF_FFFFuL) + (p2 and 0xFFFF_FFFFuL)
            return p3 + (p1 shr 32) + (p2 shr 32) + (middle shr 32)
        }

        private fun defaultSeed(): ULong {
            val nanos = System.nanoTime().toULong()
            val millis = System.currentTimeMillis().toULong()
            return nanos xor (millis * 0x9E37_79B9_7F4A_7C15uL)
        }

        /** Current UTC day number (days since 1970-01-01 00:00:00 UTC). */
        fun currentUtcDays(): ULong {
            val epochSeconds = Instant.now().epochSecond
            return if (epochSeconds <= 0L) 0uL else (epochSeconds / 86_400L).toULong()
        }

        /**
         * Converts days since 1970-01-01 UTC into `(year, month, day)` using
         * Howard Hinnant's civil calendar algorithm (identical to `dict::utc_ymd_from_days`).
         */
        fun utcYmdFromDays(daysSinceEpoch: ULong): Triple<Int, Int, Int> {
            val z = daysSinceEpoch.toLong() + 719_468L
            val era = (if (z >= 0L) z else z - 146_096L) / 146_097L
            val doe = (z - era * 146_097L).toUInt()
            val yoe = (doe - doe / 1_460u + doe / 36_524u - doe / 146_096u) / 365u
            val y = yoe.toLong() + era * 400L
            val doy = doe - (365u * yoe + yoe / 4u - yoe / 100u)
            val mp = (5u * doy + 2u) / 153u
            val d = doy - (153u * mp + 2u) / 5u + 1u
            val m = if (mp < 10u) mp + 3u else mp - 9u
            val year = if (m <= 2u) y + 1L else y
            return Triple(year.toInt(), m.toInt(), d.toInt())
        }

        /** Formats a UTC day number (days since 1970-01-01) as `"YYYY-MM-DD"`. */
        fun formatUtcDate(daysSinceEpoch: ULong): String {
            val (y, m, d) = utcYmdFromDays(daysSinceEpoch)
            return "%04d-%02d-%02d".format(y, m, d)
        }
    }
}
