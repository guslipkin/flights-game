package me.guslipkin.flights.data

import android.content.Context

/**
 * Provides cached access to the parsed `Network` instances (for 0, 1, and 2 max connections)
 * and `CoastlineData` from `assets/flights.tsv` and `assets/coastlines.bin`.
 */
class FlightsRepository(
    private val flightsTsvProvider: () -> String,
    private val coastlinesBinProvider: () -> ByteArray
) {
    private val rawFlightsTsv: String by lazy { flightsTsvProvider() }
    private val networks = arrayOfNulls<Network>(MAX_CONNECTIONS + 1)

    val coastlines: CoastlineData by lazy {
        CoastlineData.parse(coastlinesBinProvider())
    }

    @Synchronized
    fun network(maxConnections: Int): Network {
        val limit = maxConnections.coerceIn(0, MAX_CONNECTIONS)
        val existing = networks[limit]
        if (existing != null) return existing
        val parsed = Network.parse(rawFlightsTsv, limit)
        networks[limit] = parsed
        return parsed
    }

    companion object {
        @Volatile
        private var instance: FlightsRepository? = null

        fun fromContext(context: Context): FlightsRepository {
            val appContext = context.applicationContext
            return instance ?: synchronized(this) {
                instance ?: FlightsRepository(
                    flightsTsvProvider = {
                        appContext.assets.open("flights.tsv").bufferedReader(Charsets.UTF_8).use {
                            it.readText()
                        }
                    },
                    coastlinesBinProvider = {
                        appContext.assets.open("coastlines.bin").use {
                            it.readBytes()
                        }
                    }
                ).also { instance = it }
            }
        }
    }
}
