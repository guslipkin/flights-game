package me.guslipkin.flights

import me.guslipkin.flights.data.CoastlineData
import me.guslipkin.flights.data.Fastrand
import me.guslipkin.flights.data.HopRange
import me.guslipkin.flights.data.LatLon
import me.guslipkin.flights.data.LonLat
import me.guslipkin.flights.data.MapBounds
import me.guslipkin.flights.data.Network
import me.guslipkin.flights.game.Difficulty
import me.guslipkin.flights.game.FlightsGame
import me.guslipkin.flights.game.FlyOutcome
import me.guslipkin.flights.game.Rules
import me.guslipkin.flights.game.Status
import me.guslipkin.flights.game.Units
import me.guslipkin.flights.game.fitPlace
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.BeforeClass
import org.junit.Test
import java.io.File
import kotlin.math.abs
import kotlin.math.roundToInt

class FlightsEngineTest {

    companion object {
        private lateinit var flightsTsvText: String
        private lateinit var coastlinesBytes: ByteArray
        private lateinit var net1: Network

        private fun resolveAssetFile(name: String): File {
            val candidates = listOf(
                File("src/main/assets/$name"),
                File("app/src/main/assets/$name")
            )
            return candidates.firstOrNull { it.exists() }
                ?: error("Could not locate asset file $name from working dir ${File(".").absolutePath}")
        }

        @BeforeClass
        @JvmStatic
        fun setUpClass() {
            flightsTsvText = resolveAssetFile("flights.tsv").readText(Charsets.UTF_8)
            coastlinesBytes = resolveAssetFile("coastlines.bin").readBytes()
            net1 = Network.parse(flightsTsvText, 1)
        }
    }

    @Test
    fun fastrandMatchesRustFastrand250() {
        val rng = Fastrand(7uL)
        assertEquals(14266376187910451857uL, rng.genU64())
        assertEquals("2024-01-01", Fastrand.formatUtcDate(19_723uL))
        assertEquals("2026-11-19", Fastrand.formatUtcDate(20_776uL))
    }

    @Test
    fun networkParsesAirportsAndBridgesCorrectly() {
        assertEquals(3868, net1.size)
        assertEquals(841, net1.bridgeCount())
        assertTrue(net1.puzzleCount(HopRange(min = 3, max = 4)) > 0)
        assertTrue(net1.puzzleCount(HopRange(min = 3, max = 6)) > net1.puzzleCount(HopRange(min = 3, max = 4)))
    }

    @Test
    fun dailyPuzzleMatchesJottoCliBitForBit() {
        val mediumRange = Rules.standard(Difficulty.Medium).hopRange()

        // Day 19723 (2024-01-01 UTC): OUD -> WYS (7,400 nm)
        val p1 = net1.dailyPuzzle(19_723uL, mediumRange)
        assertNotNull(p1)
        assertEquals("OUD", net1.code(p1!!.first))
        assertEquals("WYS", net1.code(p1.second))
        val s1 = net1.shortest(p1.first, p1.second)!!
        assertEquals(7400, s1.first.roundToInt())
        assertEquals(
            listOf("OUD", "BUD", "BOD", "BOS", "COS", "CYS", "WYS"),
            s1.second.map { net1.code(it) }
        )

        // Day 20000: SYX -> TLL (6,388 nm)
        val p2 = net1.dailyPuzzle(20_000uL, mediumRange)
        assertNotNull(p2)
        assertEquals("SYX", net1.code(p2!!.first))
        assertEquals("TLL", net1.code(p2.second))
        val s2 = net1.shortest(p2.first, p2.second)!!
        assertEquals(6388, s2.first.roundToInt())
        assertEquals(
            listOf("SYX", "SZX", "TZX", "TZL", "TLL"),
            s2.second.map { net1.code(it) }
        )

        // Day 20776 (2026-11-19 UTC): LEX -> CAY (6,635 nm)
        val p3 = net1.dailyPuzzle(20_776uL, mediumRange)
        assertNotNull(p3)
        assertEquals("LEX", net1.code(p3!!.first))
        assertEquals("CAY", net1.code(p3.second))
        val s3 = net1.shortest(p3.first, p3.second)!!
        assertEquals(6635, s3.first.roundToInt())
        assertEquals(
            listOf("LEX", "LAX", "LAP", "SAP", "CAP", "CAY"),
            s3.second.map { net1.code(it) }
        )
    }

    @Test
    fun coastlinesThreeScalesAndGeometryMatchJottoCli() {
        val coastlines = CoastlineData.parse(coastlinesBytes)
        assertEquals(3, coastlines.scales.size)
        val pointCounts = coastlines.scales.map { scale -> scale.sumOf { it.size } }
        assertTrue(pointCounts[0] < pointCounts[1] && pointCounts[1] < pointCounts[2])
        assertTrue(pointCounts[2] > 300_000)

        for (scale in coastlines.scales) {
            for (line in scale) {
                val b = line.bbox
                assertTrue(
                    b.lonMin >= -180.0001 && b.lonMax <= 180.0001 &&
                        b.latMin >= -90.0001 && b.latMax <= 90.0001
                )
            }
        }

        // Line clipping test (from coast.rs)
        val b = MapBounds(0.0, 10.0, 0.0, 10.0)
        val inside = CoastlineData.clip(1.0, 1.0, 9.0, 9.0, b)
        assertNotNull(inside)
        val clipped = CoastlineData.clip(-10.0, 5.0, 5.0, 5.0, b)!!
        assertEquals(0.0, clipped.ax, 1e-9)
        assertEquals(5.0, clipped.ay, 1e-9)
        assertEquals(5.0, clipped.bx, 1e-9)
        assertEquals(5.0, clipped.by, 1e-9)
        assertNull(CoastlineData.clip(-5.0, -5.0, -1.0, 20.0, b))

        // Great-circle curves test (from tui.rs)
        val straight = CoastlineData.legPoints(LonLat(-73.8, 40.6), LonLat(-0.5, 51.5), false)
        assertEquals(2, straight.size)

        val nycToLon = CoastlineData.legPoints(LonLat(-73.8, 40.6), LonLat(-0.5, 51.5), true)
        assertEquals(-73.8, nycToLon.first().lon, 1e-9)
        assertEquals(40.6, nycToLon.first().lat, 1e-9)
        assertEquals(-0.5, nycToLon.last().lon, 1e-9)
        assertEquals(51.5, nycToLon.last().lat, 1e-9)
        assertTrue(nycToLon.maxOf { it.lat } > 53.0)

        // Tokyo to Los Angeles across the Pacific without a jump
        val nrtToLax = CoastlineData.legPoints(LonLat(140.4, 35.8), LonLat(-118.4, 33.9), true)
        for (i in 0 until nrtToLax.size - 1) {
            assertTrue(abs(nrtToLax[i + 1].lon - nrtToLax[i].lon) < 5.0)
        }
        assertEquals(241.6, nrtToLax.last().lon, 1e-9)
        assertTrue(nrtToLax.any { it.lat > 45.0 })

        // Antimeridian bounds
        val pacBounds = CoastlineData.mapBounds(
            listOf(LatLon(0.0, -170.0), LatLon(0.0, 170.0)),
            aspectRatio = 2.0
        )
        assertTrue(pacBounds.lonMin < 170.0 && pacBounds.lonMax > 190.0 && pacBounds.lonSpan < 60.0)
    }

    @Test
    fun gameplayLongerRouteBacktrackingVictoryAndSaveRestore() {
        val sampleTsv = """
            A	AAA	0	0	Alpha	AA
            A	ABA	0	10	Bravo	BB
            A	ABB	0	20	Charlie	CC
            A	BAA	10	0	Delta	DD
            A	BBA	10	15	Echo	EE
            A	BBB	0	30	Foxtrot	FF
            H	AAA	ABA	-	-	-
            H	ABA	ABB	-	-	-
            H	ABB	BBB	-	-	-
            H	AAA	BAA	-	-	-
            H	BAA	BBA	-	-	-
            H	BBA	BBB	-	-	-
        """.trimIndent()
        val smallNet = Network.parse(sampleTsv, 1)
        val start = smallNet.indexOf("AAA")!!
        val end = smallNet.indexOf("BBB")!!

        val game = FlightsGame.withPuzzle(
            net = smallNet,
            start = start,
            end = end,
            difficulty = Difficulty.Medium
        )!!

        // Take the northern (longer) route: AAA -> BAA -> BBA -> BBB
        assertTrue(game.fly("BAA").getOrThrow() is FlyOutcome.Flew)
        assertTrue(game.fly("BBA").getOrThrow() is FlyOutcome.Flew)

        // Save mid-game and restore
        val savedJson = game.toSavedJson()
        val restored = FlightsGame.fromSavedJson(savedJson) { smallNet }.getOrThrow()!!
        assertEquals(listOf("AAA", "BAA", "BBA"), restored.route.map { smallNet.code(it) })

        val longer = game.fly("BBB").getOrThrow()
        assertTrue(longer is FlyOutcome.Longer)
        assertEquals(Status.Playing, game.status)
        assertEquals(1, game.longerArrivals)

        // Backtrack to AAA and fly the shortest equatorial route: AAA -> ABA -> ABB -> BBB
        assertEquals(smallNet.indexOf("BBB"), game.back())
        assertEquals(smallNet.indexOf("BBA"), game.back())
        assertEquals(smallNet.indexOf("BAA"), game.back())
        assertNull(game.back())

        assertTrue(game.fly("ABA").getOrThrow() is FlyOutcome.Flew)
        assertTrue(game.fly("ABB").getOrThrow() is FlyOutcome.Flew)
        val win = game.fly("BBB").getOrThrow()
        assertEquals(FlyOutcome.Won, win)
        assertEquals(Status.Won, game.status)
        assertTrue(game.shareSummary().contains("after 1 longer route"))
    }

    @Test
    fun fitPlaceTruncatesCityButKeepsCountryCode() {
        val longPlace = "Saint-Jacques-de-la-Lande, Ille-et-Vilaine, FR"
        assertEquals("Saint-Jac…, FR", fitPlace(longPlace, 14))
        assertEquals("Las Vegas, US", fitPlace("Las Vegas, US", 14))
        assertFalse(fitPlace("Las Vegas, US", 20).contains("…"))
    }
}
