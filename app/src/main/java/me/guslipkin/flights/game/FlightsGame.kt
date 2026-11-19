package me.guslipkin.flights.game

import me.guslipkin.flights.data.Fastrand
import me.guslipkin.flights.data.Hop
import me.guslipkin.flights.data.HopRange
import me.guslipkin.flights.data.MAX_CONNECTIONS
import me.guslipkin.flights.data.Network
import me.guslipkin.flights.data.OnceRoute
import me.guslipkin.flights.data.STANDARD_CONNECTIONS
import me.guslipkin.flights.data.Ticket
import me.guslipkin.flights.data.lettersApart
import org.json.JSONArray
import org.json.JSONObject
import java.text.NumberFormat
import java.util.Locale
import kotlin.math.min
import kotlin.math.roundToInt

const val MIN_HOPS: Int = 3
const val MAX_HOPS: Int = 20
private const val ONCE_DEAL_ATTEMPTS: Int = 200
private const val TIE_NM: Double = 1e-6
const val SAVE_VERSION: Int = 1
const val PLACE_WIDTH: Int = 20

const val YOU_LEFT: String = "↑ you left here"
const val WENT_HERE: String = "↑ went here"
const val NEXT_HOP: String = "↑ next hop"

fun grouped(n: Int): String = NumberFormat.getIntegerInstance(Locale.US).format(n)

fun pluralS(n: Int): String = if (n == 1) "" else "s"

/** Reads a 3-letter airport code typed in any case ("lax" -> "LAX"). */
fun parseCode(text: String): String? {
    val clean = text.trim().uppercase(Locale.US)
    return if (clean.length == 3 && clean.all { it in 'A'..'Z' }) clean else null
}

/**
 * Shortens a place string `"City, CC"` to `width` characters, truncating only the city
 * with `"…"` while keeping `", CC"` intact (identical to `fit_place` in `jotto-cli`).
 */
fun fitPlace(text: String, width: Int): String {
    if (text.length <= width) return text
    val lastComma = text.lastIndexOf(", ")
    val (city, country) = if (lastComma >= 0 && text.length - (lastComma + 2) <= 3) {
        text.substring(0, lastComma) to text.substring(lastComma)
    } else {
        text to ""
    }
    val room = (width - (country.length + 1)).coerceAtLeast(1)
    val cut = city.take(room).trimEnd()
    return "$cut…$country"
}

fun shortPlace(text: String): String = fitPlace(text, PLACE_WIDTH)

/**
 * How long a puzzle may be and how much the player is shown.
 */
enum class Difficulty(val label: String, val description: String) {
    Easy("Easy", "up to 4 hops; map, distances and connections"),
    Medium("Medium", "up to 6 hops; map and connections"),
    Hard("Hard", "up to 8 hops; connections only"),
    Pilot("Pilot", "any length; codes only"),
    Custom("Custom", "your own settings");

    fun next(): Difficulty {
        val all = entries
        return all[(ordinal + 1) % all.size]
    }

    fun rules(custom: Rules = Rules()): Rules {
        return if (this == Custom) custom else Rules.standard(this)
    }

    fun puzzleCount(networkProvider: (Int) -> Network): Int {
        return rules().puzzleCount(networkProvider)
    }

    companion object {
        val STANDARD: List<Difficulty> = listOf(Easy, Medium, Hard, Pilot)
        val DAILY_DIFFICULTY: Difficulty = Medium

        fun fromName(raw: String): Difficulty? {
            return when (raw.trim().lowercase(Locale.US)) {
                "easy", "e" -> Easy
                "medium", "med", "m" -> Medium
                "hard", "h" -> Hard
                "pilot", "p" -> Pilot
                "custom", "c" -> Custom
                else -> null
            }
        }
    }
}

/**
 * What a game shows while it's played.
 */
data class View(
    val map: Boolean,
    val distances: Boolean,
    val connections: Boolean,
    val amountOver: Boolean
) {
    fun level(): Difficulty? = Difficulty.STANDARD.firstOrNull { of(it) == this }

    fun label(): String = level()?.label ?: "Mixed"

    fun parts(): String {
        val list = buildList {
            if (map) add("map")
            if (distances) add("distances")
            if (connections) add("connections")
            if (amountOver) add("how far over")
        }
        return when (list.size) {
            0 -> "codes only"
            1 -> list[0]
            else -> list.dropLast(1).joinToString(", ") + " and " + list.last()
        }
    }

    companion object {
        fun of(level: Difficulty): View = View(
            map = level == Difficulty.Easy || level == Difficulty.Medium || level == Difficulty.Custom,
            distances = level == Difficulty.Easy,
            connections = level != Difficulty.Pilot,
            amountOver = level == Difficulty.Easy || level == Difficulty.Medium || level == Difficulty.Custom
        )
    }
}

/**
 * What a game deals and shows: a standard level's fixed rules, or a custom game's.
 */
data class Rules(
    val view: View = View.of(Difficulty.Medium),
    val minHops: Int = MIN_HOPS,
    val maxHops: Int? = 6,
    val maxConnections: Int = STANDARD_CONNECTIONS,
    val showPlaces: Boolean = true,
    val fixedRoute: Boolean = false,
    val start: String? = null,
    val end: String? = null,
    val reuseConnections: Boolean = true
) {
    fun hopRange(): HopRange {
        return if (fixedRoute) {
            HopRange()
        } else {
            HopRange(min = minHops, max = maxHops)
        }
    }

    fun connections(): Int = if (fixedRoute) STANDARD_CONNECTIONS else maxConnections

    fun oncePerAirport(): Boolean = !reuseConnections && connections() > 0

    fun showsMap(): Boolean = view.map
    fun showsDistances(): Boolean = view.distances
    fun showsAmountOver(): Boolean = view.amountOver
    fun showsConnections(): Boolean = view.connections

    fun countIsExact(): Boolean {
        return !oncePerAirport() || (fixedRoute && start != null && end != null)
    }

    private fun playable(net: Network, startIdx: Int, endIdx: Int): Boolean {
        if (!oncePerAirport()) {
            return net.isValidPuzzle(startIdx, endIdx)
        }
        return lettersApart(net.code(startIdx), net.code(endIdx)) == 3 &&
            net.routesOnce(startIdx, endIdx, 2).size == 2
    }

    private fun deals(net: Network, startIdx: Int, endIdx: Int): Boolean {
        if (lettersApart(net.code(startIdx), net.code(endIdx)) != 3) return false
        val routes = net.routesOnce(startIdx, endIdx, 2)
        return routes.size == 2 && hopRange().contains(routes[0].stops.size - 1)
    }

    private fun fixed(net: Network): Result<Pair<Int?, Int?>> {
        if (!fixedRoute) return Result.success(null to null)

        fun find(code: String?): Result<Int?> {
            if (code == null) return Result.success(null)
            val idx = net.indexOf(code)?.takeIf { net.hops(it).isNotEmpty() }
                ?: return Result.failure(
                    IllegalArgumentException(
                        "$code has no hops with ${connections()} connection${pluralS(connections())}"
                    )
                )
            return Result.success(idx)
        }

        val startIdx = find(start).getOrElse { return Result.failure(it) }
        val endIdx = find(end).getOrElse { return Result.failure(it) }

        if (startIdx != null && endIdx != null) {
            val ca = net.code(startIdx)
            val cb = net.code(endIdx)
            if (lettersApart(ca, cb) != 3) {
                return Result.failure(IllegalArgumentException("$ca and $cb must differ in every letter"))
            }
            if (!playable(net, startIdx, endIdx)) {
                val routes = if (oncePerAirport()) {
                    net.routesOnce(startIdx, endIdx, 1).size
                } else {
                    if (net.shortest(startIdx, endIdx) != null) 1 else 0
                }
                val once = if (oncePerAirport()) " using each airport once" else ""
                val msg = if (routes == 0) {
                    "there's no way from $ca to $cb$once"
                } else {
                    "only one route joins $ca and $cb$once"
                }
                return Result.failure(IllegalArgumentException(msg))
            }
        }
        return Result.success(startIdx to endIdx)
    }

    fun check(networkProvider: (Int) -> Network): Result<Int> {
        val net = networkProvider(connections())
        val (s, e) = fixed(net).getOrElse { return Result.failure(it) }
        val count = when {
            s == null && e == null -> net.puzzleCount(hopRange())
            s != null && e == null -> net.puzzleEnds(s, hopRange()).size
            s == null && e != null -> net.puzzleEnds(e, hopRange()).size
            else -> 1
        }
        if (count == 0) {
            return Result.failure(IllegalArgumentException("no puzzles fit these settings"))
        }
        return Result.success(count)
    }

    fun puzzleCount(networkProvider: (Int) -> Network): Int = check(networkProvider).getOrDefault(0)

    fun problem(networkProvider: (Int) -> Network): String? = check(networkProvider).exceptionOrNull()?.message

    fun deal(net: Network, rng: Fastrand): Result<Pair<Int, Int>> {
        fun noneErr(fallback: Throwable?): Result<Pair<Int, Int>> {
            val msg = fallback?.message ?: "no puzzles fit these settings"
            return Result.failure(IllegalArgumentException(msg))
        }

        if (oncePerAirport()) {
            val dealt = dealOnce(net, rng)
            return if (dealt != null) {
                Result.success(dealt)
            } else {
                val fixedCheck = fixed(net)
                noneErr(fixedCheck.exceptionOrNull())
            }
        }

        val (s, e) = fixed(net).getOrElse { return Result.failure(it) }
        return when {
            s == null && e == null -> {
                val pair = net.randomPuzzle(rng, hopRange())
                if (pair != null) Result.success(pair) else noneErr(null)
            }
            s != null && e == null -> {
                val ends = net.puzzleEnds(s, hopRange())
                if (ends.isNotEmpty()) Result.success(s to ends[rng.usize(ends.size)]) else noneErr(null)
            }
            s == null && e != null -> {
                val starts = net.puzzleEnds(e, hopRange())
                if (starts.isNotEmpty()) Result.success(starts[rng.usize(starts.size)] to e) else noneErr(null)
            }
            else -> Result.success(s!! to e!!)
        }
    }

    private fun dealOnce(net: Network, rng: Fastrand): Pair<Int, Int>? {
        val (s, e) = fixed(net).getOrNull() ?: return null
        return when {
            s != null && e != null -> s to e
            s == null && e == null -> {
                for (attempt in 0 until ONCE_DEAL_ATTEMPTS) {
                    val (a, b) = net.randomPuzzle(rng, hopRange()) ?: return null
                    if (deals(net, a, b)) return a to b
                }
                null
            }
            else -> {
                val fixedAirport = s ?: e!!
                val ends = net.puzzleEnds(fixedAirport, hopRange()).toMutableList()
                rng.shuffle(ends)
                val limit = min(ONCE_DEAL_ATTEMPTS, ends.size)
                for (i in 0 until limit) {
                    val b = ends[i]
                    val pair = if (start != null) fixedAirport to b else b to fixedAirport
                    if (deals(net, pair.first, pair.second)) {
                        return pair
                    }
                }
                null
            }
        }
    }

    fun hopsText(): String {
        val range = hopRange()
        val min = range.min.coerceAtLeast(MIN_HOPS)
        val max = range.max
        return when {
            max != null && max == min -> "$max hops"
            max != null && min == MIN_HOPS -> "up to $max hops"
            max != null -> "$min to $max hops"
            min == MIN_HOPS -> "any number of hops"
            else -> "at least $min hops"
        }
    }

    private fun viewText(): String {
        val lvl = view.level()
        return if (lvl != null) "${lvl.label} view" else "shows ${view.parts()}"
    }

    fun summary(): String {
        if (fixedRoute) {
            val s = start ?: "random"
            val e = end ?: "random"
            val once = if (oncePerAirport()) ", each airport once" else ""
            val places = if (showPlaces) "" else ", no places"
            return "${viewText()}, route $s → $e$once$places"
        }
        val c = connections()
        val once = if (oncePerAirport()) ", each airport once" else ""
        val places = if (showPlaces) "" else ", no places"
        return "${viewText()}, ${hopsText()}, up to $c connection${pluralS(c)}$once$places"
    }

    fun toJson(): JSONObject {
        return JSONObject().apply {
            put(
                "view",
                JSONObject().apply {
                    put("map", view.map)
                    put("distances", view.distances)
                    put("connections", view.connections)
                    put("amount_over", view.amountOver)
                }
            )
            if (minHops != MIN_HOPS) put("min_hops", minHops)
            if (maxHops != null) put("max_hops", maxHops) else put("max_hops", JSONObject.NULL)
            put("max_connections", maxConnections)
            put("show_places", showPlaces)
            if (fixedRoute) put("fixed_route", true)
            if (start != null) put("start", start)
            if (end != null) put("end", end)
            if (!reuseConnections) put("reuse_connections", false)
        }
    }

    companion object {
        fun standard(level: Difficulty): Rules = Rules(
            view = View.of(level),
            minHops = MIN_HOPS,
            maxHops = when (level) {
                Difficulty.Easy -> 4
                Difficulty.Medium -> 6
                Difficulty.Hard -> 8
                Difficulty.Pilot, Difficulty.Custom -> null
            },
            maxConnections = STANDARD_CONNECTIONS,
            showPlaces = true,
            fixedRoute = false,
            start = null,
            end = null,
            reuseConnections = true
        )

        fun fromJson(obj: JSONObject): Rules? {
            val viewVal = obj.opt("view")
            val view = when (viewVal) {
                is String -> Difficulty.fromName(viewVal)
                    ?.takeIf { it != Difficulty.Custom }
                    ?.let { View.of(it) }
                is JSONObject -> View(
                    map = viewVal.optBoolean("map", true),
                    distances = viewVal.optBoolean("distances", false),
                    connections = viewVal.optBoolean("connections", true),
                    amountOver = viewVal.optBoolean("amount_over", true)
                )
                else -> null
            } ?: return null

            val minHops = obj.optInt("min_hops", MIN_HOPS)
            val maxHops = if (obj.isNull("max_hops")) null else obj.optInt("max_hops", 6)
            val inBounds = { n: Int -> n in MIN_HOPS..MAX_HOPS }
            val hopsOk = inBounds(minHops) && (maxHops == null || (inBounds(maxHops) && minHops <= maxHops))
            val maxConn = obj.optInt("max_connections", STANDARD_CONNECTIONS)
            if (!hopsOk || maxConn !in 0..MAX_CONNECTIONS) return null

            val rawStart = obj.optString("start", "").ifEmpty { null }
            val rawEnd = obj.optString("end", "").ifEmpty { null }
            val start = if (rawStart == null) null else parseCode(rawStart) ?: return null
            val end = if (rawEnd == null) null else parseCode(rawEnd) ?: return null

            return Rules(
                view = view,
                minHops = minHops,
                maxHops = maxHops,
                maxConnections = maxConn,
                showPlaces = obj.optBoolean("show_places", true),
                fixedRoute = obj.optBoolean("fixed_route", false),
                start = start,
                end = end,
                reuseConnections = obj.optBoolean("reuse_connections", true)
            )
        }
    }
}

/** Distance units (`nm`, `mi`, `km`). */
enum class Units(val label: String, val fullName: String) {
    Nm("nm", "Nautical miles"),
    Mi("mi", "Statute miles"),
    Km("km", "Kilometres");

    fun next(): Units {
        val all = entries
        return all[(ordinal + 1) % all.size]
    }

    fun convert(nm: Double): Double = when (this) {
        Nm -> nm
        Mi -> nm * 1.150_779
        Km -> nm * 1.852
    }

    fun format(nm: Double): String {
        val rounded = convert(nm).roundToInt()
        return "${grouped(rounded)} $label"
    }

    companion object {
        fun fromName(raw: String): Units? = when (raw.trim().lowercase(Locale.US)) {
            "nm", "nmi" -> Nm
            "mi", "miles" -> Mi
            "km", "kilometers", "kilometres" -> Km
            else -> null
        }
    }
}

/** Current lifecycle status of a game. */
enum class Status {
    Playing,
    Won,
    GivenUp
}

/** What a flight led to. */
sealed interface FlyOutcome {
    data class Flew(val distance: Double) : FlyOutcome
    data class Longer(val over: Double) : FlyOutcome
    data object Won : FlyOutcome
}

/** An airport the player can fly to next. */
data class FlightOption(
    val airport: Int,
    val code: String,
    val distance: Double,
    val via: List<String>,
    val connections: List<Int>,
    val changed: Int
)

/**
 * State machine for a `Flights` game session, ported from `jotto-cli/src/flights/game.rs`.
 */
class FlightsGame private constructor(
    var net: Network,
    val origin: Int,
    val destination: Int,
    private val mutableRoute: MutableList<Int>,
    private val mutableLegs: MutableList<Ticket>,
    val bestDistance: Double,
    val bestRoute: List<Int>,
    val bestLegs: List<Ticket>,
    var difficulty: Difficulty,
    var rules: Rules,
    var custom: Rules,
    var units: Units,
    var curves: Boolean,
    var dailyDate: String?,
    var longerArrivals: Int,
    var status: Status
) {
    val route: List<Int> get() = mutableRoute
    val legs: List<Ticket> get() = mutableLegs

    val startCode: String get() = net.code(origin)
    val endCode: String get() = net.code(destination)
    val current: Int get() = mutableRoute.last()
    val currentCode: String get() = net.code(current)
    val hops: Int get() = mutableRoute.size - 1

    fun totalDistance(): Double = mutableLegs.sumOf { it.distance }

    fun distancesVisible(): Boolean = rules.showsDistances() || status != Status.Playing

    fun atDestination(): Boolean = current == destination

    /**
     * How many airports, from the start, the player's route shares with the shortest one.
     */
    fun divergence(): Int {
        val len = min(mutableRoute.size, bestRoute.size)
        var count = 0
        while (count < len && mutableRoute[count] == bestRoute[count]) {
            count++
        }
        return count
    }

    /**
     * Where the player's route left the shortest one, in words, for giving up.
     */
    fun divergenceText(): String {
        val split = divergence()
        return when {
            mutableRoute.size == 1 -> "You hadn't left the start."
            split == mutableRoute.size -> "Your route so far follows it."
            else -> {
                val afterCode = net.code(mutableRoute[split - 1])
                val flewCode = net.code(mutableRoute[split])
                val bestCode = net.code(bestRoute[split])
                "You left it after $afterCode: you flew to $flewCode, the shortest goes to $bestCode."
            }
        }
    }

    private fun used(airport: Int): Boolean {
        return mutableRoute.contains(airport) ||
            (rules.oncePerAirport() && mutableLegs.any { it.via.contains(airport) })
    }

    private fun ticketFor(hop: Hop): Ticket? {
        return if (rules.oncePerAirport()) {
            hop.ticketAvoiding { idx -> used(idx) }
        } else {
            hop.ticket()
        }
    }

    /**
     * Where the player can fly next: airports one letter away with a ticket, not already on the
     * route, the destination first and the rest alphabetical by code.
     */
    fun options(): List<FlightOption> {
        if (status != Status.Playing || atDestination()) {
            return emptyList()
        }
        val here = net.code(current)
        val rawOptions = ArrayList<FlightOption>()
        for (hop in net.hops(current)) {
            if (used(hop.to)) continue
            val ticket = ticketFor(hop) ?: continue
            val code = net.code(hop.to)
            val changed = (0..2).firstOrNull { here[it] != code[it] } ?: 0
            rawOptions.add(
                FlightOption(
                    airport = hop.to,
                    code = code,
                    distance = ticket.distance,
                    via = ticket.via.map { net.code(it) },
                    connections = ticket.via,
                    changed = changed
                )
            )
        }
        rawOptions.sortWith(compareBy { it.airport != destination })
        return rawOptions
    }

    /**
     * Flies to `rawCode`. Reaching the destination ends the game if the route is as short as
     * `bestDistance` (within `TIE_NM`), otherwise increments `longerArrivals` and notifies the player.
     */
    fun fly(rawCode: String): Result<FlyOutcome> {
        if (status != Status.Playing) {
            return Result.failure(IllegalStateException("The game is over. Start a New Game to play again."))
        }
        val code = rawCode.trim().uppercase(Locale.US)
        if (code.isEmpty()) {
            return Result.failure(IllegalArgumentException("Choose an airport code to fly to."))
        }
        if (code.length != 3 || !code.all { it in 'A'..'Z' }) {
            return Result.failure(IllegalArgumentException("'$code' isn't an airport code: codes are 3 letters."))
        }
        if (atDestination()) {
            return Result.failure(
                IllegalStateException(
                    "You're at the destination, but not by the shortest route. Go back to try another."
                )
            )
        }
        val from = net.code(current)
        val to = net.indexOf(code) ?: return Result.failure(
            IllegalArgumentException("$code isn't in the game: it has no flights to a code one letter away.")
        )
        if (mutableRoute.contains(to)) {
            return Result.failure(
                IllegalArgumentException("$code is already on your route. Go back to it instead of flying there.")
            )
        }
        if (used(to)) {
            return Result.failure(
                IllegalArgumentException(
                    "You've already connected through $code, and this game uses each airport once."
                )
            )
        }
        if (lettersApart(from, code) != 1) {
            return Result.failure(IllegalArgumentException("$code isn't one letter away from $from."))
        }
        val hop = net.hop(current, to) ?: return Result.failure(
            IllegalArgumentException(
                when (val mc = net.maxConnections) {
                    0 -> "There's no direct flight from $from to $code."
                    1 -> "There's no ticket from $from to $code, direct or with one connection."
                    else -> "There's no ticket from $from to $code with $mc connections or fewer."
                }
            )
        )
        val ticket = ticketFor(hop) ?: return Result.failure(
            IllegalArgumentException(
                "Every ticket from $from to $code connects through an airport you've already used."
            )
        )
        val distance = ticket.distance
        mutableRoute.add(to)
        mutableLegs.add(ticket)

        if (to != destination) {
            return Result.success(FlyOutcome.Flew(distance))
        }
        val over = totalDistance() - bestDistance
        return if (over <= TIE_NM) {
            status = Status.Won
            Result.success(FlyOutcome.Won)
        } else {
            longerArrivals++
            Result.success(FlyOutcome.Longer(over))
        }
    }

    /** Goes back to the previous airport, returning the airport index left, or `null` at start. */
    fun back(): Int? {
        if (status != Status.Playing || mutableRoute.size < 2) {
            return null
        }
        mutableLegs.removeAt(mutableLegs.lastIndex)
        return mutableRoute.removeAt(mutableRoute.lastIndex)
    }

    /** Ends the game and reveals `bestRoute`. */
    fun giveUp() {
        if (status == Status.Playing) {
            status = Status.GivenUp
        }
    }

    fun routeText(airports: List<Int>): String = airports.joinToString(" → ") { net.code(it) }

    /**
     * One-line share summary identical to `FlightsGame::share_summary` in `jotto-cli`.
     */
    fun shareSummary(): String {
        val h = hops
        val tries = when (longerArrivals) {
            0 -> "first try"
            1 -> "after 1 longer route"
            else -> "after $longerArrivals longer routes"
        }
        val daily = dailyDate?.let { " (daily $it)" } ?: ""
        return "Flights $startCode → $endCode$daily: shortest route in $h hop${pluralS(h)}, ${units.format(totalDistance())}, $tries"
    }

    /**
     * Rich shareable text for Android share sheet (works for both Won and GivenUp).
     */
    fun shareCardText(): String {
        return if (status == Status.Won) {
            val chain = List(mutableRoute.size) { idx ->
                when (idx) {
                    0 -> "🛫"
                    mutableRoute.lastIndex -> "🛬"
                    else -> "✈️"
                }
            }.joinToString("→")
            "${shareSummary()}\n$chain"
        } else {
            val daily = dailyDate?.let { " (daily $it)" } ?: ""
            val bestHops = bestRoute.size - 1
            "Flights $startCode → $endCode$daily: shortest route is $bestHops hop${pluralS(bestHops)} (${units.format(bestDistance)})"
        }
    }

    fun toSavedJson(hapticsEnabled: Boolean = true, soundEnabled: Boolean = true): JSONObject {
        return JSONObject().apply {
            put("version", SAVE_VERSION)
            put("units", units.label)
            put("curves", curves)
            put("haptics", hapticsEnabled)
            put("sound", soundEnabled)
            put("custom", custom.toJson())
            if (status == Status.Playing) {
                put(
                    "game",
                    JSONObject().apply {
                        put("difficulty", difficulty.label.lowercase(Locale.US))
                        if (difficulty == Difficulty.Custom) {
                            put("rules", rules.toJson())
                        }
                        put("start", startCode)
                        put("end", endCode)
                        if (dailyDate != null) {
                            put("daily_date", dailyDate)
                        }
                        val routeArr = JSONArray()
                        for (i in 1 until mutableRoute.size) {
                            routeArr.put(net.code(mutableRoute[i]))
                        }
                        put("route", routeArr)
                        put("longer_arrivals", longerArrivals)
                    }
                )
            }
        }
    }

    companion object {
        fun withPuzzle(
            net: Network,
            start: Int,
            end: Int,
            difficulty: Difficulty,
            custom: Rules = Rules(),
            units: Units = Units.Nm,
            curves: Boolean = true,
            dailyDate: String? = null
        ): FlightsGame? {
            val rules = difficulty.rules(custom)
            val best = if (rules.oncePerAirport()) {
                net.routesOnce(start, end, 1).firstOrNull() ?: return null
            } else {
                val (distance, stops) = net.shortest(start, end) ?: return null
                val legs = ArrayList<Ticket>(stops.size - 1)
                for (i in 0 until stops.size - 1) {
                    val hop = net.hop(stops[i], stops[i + 1]) ?: return null
                    legs.add(hop.ticket())
                }
                OnceRoute(distance, stops, legs)
            }
            return FlightsGame(
                net = net,
                origin = start,
                destination = end,
                mutableRoute = mutableListOf(start),
                mutableLegs = mutableListOf(),
                bestDistance = best.distance,
                bestRoute = best.stops,
                bestLegs = best.legs,
                difficulty = difficulty,
                rules = rules,
                custom = custom,
                units = units,
                curves = curves,
                dailyDate = dailyDate,
                longerArrivals = 0,
                status = Status.Playing
            )
        }

        fun random(
            difficulty: Difficulty,
            custom: Rules = Rules(),
            units: Units = Units.Nm,
            curves: Boolean = true,
            networkProvider: (Int) -> Network
        ): Result<FlightsGame> {
            val rules = difficulty.rules(custom)
            val net = networkProvider(rules.connections())
            val (start, end) = rules.deal(net, Fastrand()).getOrElse {
                return Result.failure(
                    IllegalArgumentException(
                        "Can't start a custom game: ${it.message?.replaceFirstChar { c -> c.uppercase() }}. Change it in the settings."
                    )
                )
            }
            val game = withPuzzle(net, start, end, difficulty, custom, units, curves, null)
                ?: return Result.failure(IllegalStateException("Puzzles are connected"))
            return Result.success(game)
        }

        fun newRoute(
            route: String,
            difficulty: Difficulty,
            custom: Rules = Rules(),
            units: Units = Units.Nm,
            curves: Boolean = true,
            networkProvider: (Int) -> Network
        ): Result<FlightsGame> {
            val letters = route.filter { it.isLetter() }.uppercase(Locale.US)
            if (letters.length != 6 || route.any { it.isDigit() }) {
                return Result.failure(
                    IllegalArgumentException("'$route' isn't a route: give two airport codes like LAX-LOS.")
                )
            }
            val a = letters.substring(0, 3)
            val b = letters.substring(3, 6)
            val net = networkProvider(difficulty.rules(custom).connections())
            val start = net.indexOf(a) ?: return Result.failure(
                IllegalArgumentException("$a isn't in the game: it has no flights to a code one letter away.")
            )
            val end = net.indexOf(b) ?: return Result.failure(
                IllegalArgumentException("$b isn't in the game: it has no flights to a code one letter away.")
            )
            if (start == end) {
                return Result.failure(
                    IllegalArgumentException("'$route' isn't a route: give two airport codes like LAX-LOS.")
                )
            }
            val game = withPuzzle(net, start, end, difficulty, custom, units, curves, null)
                ?: return Result.failure(IllegalArgumentException("There's no way to get from $a to $b."))
            return Result.success(game)
        }

        fun dailyIn(
            utcDay: ULong,
            custom: Rules = Rules(),
            units: Units = Units.Nm,
            curves: Boolean = true,
            networkProvider: (Int) -> Network
        ): FlightsGame {
            val rules = Difficulty.DAILY_DIFFICULTY.rules(custom)
            val net = networkProvider(rules.connections())
            val (start, end) = net.dailyPuzzle(utcDay, rules.hopRange())
                ?: error("the daily level has puzzles")
            return withPuzzle(
                net = net,
                start = start,
                end = end,
                difficulty = Difficulty.DAILY_DIFFICULTY,
                custom = custom,
                units = units,
                curves = curves,
                dailyDate = Fastrand.formatUtcDate(utcDay)
            ) ?: error("puzzles are connected")
        }

        fun newDaily(
            custom: Rules = Rules(),
            units: Units = Units.Nm,
            curves: Boolean = true,
            networkProvider: (Int) -> Network
        ): FlightsGame = dailyIn(Fastrand.currentUtcDays(), custom, units, curves, networkProvider)

        /**
         * Restores a saved unfinished game from JSON by replaying its flights, or returns `null`
         * if no unfinished game was stored.
         */
        fun fromSavedJson(
            saved: JSONObject,
            networkProvider: (Int) -> Network
        ): Result<FlightsGame?> {
            val play = saved.optJSONObject("game") ?: return Result.success(null)
            val difficulty = Difficulty.fromName(play.optString("difficulty", ""))
                ?: return Result.failure(IllegalArgumentException("unknown difficulty"))
            val units = Units.fromName(saved.optString("units", "nm")) ?: Units.Nm
            val curves = saved.optBoolean("curves", true)
            val custom = saved.optJSONObject("custom")?.let { Rules.fromJson(it) } ?: Rules()
            val gameRules = if (difficulty == Difficulty.Custom && play.has("rules")) {
                play.optJSONObject("rules")?.let { Rules.fromJson(it) }
                    ?: return Result.failure(IllegalArgumentException("its custom settings can't be read"))
            } else {
                custom
            }

            val net = networkProvider(difficulty.rules(gameRules).connections())
            val startCode = play.optString("start", "")
            val endCode = play.optString("end", "")
            val startIdx = net.indexOf(startCode)
                ?: return Result.failure(IllegalArgumentException("$startCode is no longer in the flight data"))
            val endIdx = net.indexOf(endCode)
                ?: return Result.failure(IllegalArgumentException("$endCode is no longer in the flight data"))
            val dailyDate = if (play.has("daily_date") && !play.isNull("daily_date")) {
                play.optString("daily_date")
            } else {
                null
            }

            val game = withPuzzle(
                net = net,
                start = startIdx,
                end = endIdx,
                difficulty = difficulty,
                custom = gameRules,
                units = units,
                curves = curves,
                dailyDate = dailyDate
            ) ?: return Result.failure(
                IllegalArgumentException("$startCode and $endCode are no longer connected")
            )

            val routeArr = play.optJSONArray("route") ?: JSONArray()
            for (i in 0 until routeArr.length()) {
                val code = routeArr.optString(i, "")
                game.fly(code).getOrElse { err ->
                    return Result.failure(err)
                }
            }
            if (game.status != Status.Playing) {
                return Result.failure(IllegalArgumentException("its flights already finish it"))
            }
            game.longerArrivals = play.optInt("longer_arrivals", 0)
            game.custom = custom
            return Result.success(game)
        }
    }
}
