package me.guslipkin.flights.data

import java.util.ArrayDeque
import java.util.PriorityQueue
import kotlin.math.asin
import kotlin.math.cos
import kotlin.math.min
import kotlin.math.sin
import kotlin.math.sqrt

const val MAX_CONNECTIONS: Int = 2
const val STANDARD_CONNECTIONS: Int = 1
private const val EARTH_RADIUS_NM: Double = 3_440.065
private const val PUZZLE_ATTEMPTS: Int = 10_000
private const val END_ATTEMPTS: Int = 8
private const val ONCE_SEARCH_LIMIT: Int = 200_000

/** The hops a puzzle's shortest route may take: at least `min`, at most `max` (`null`: no limit). */
data class HopRange(
    val min: Int = 0,
    val max: Int? = null
) {
    fun contains(hops: Int): Boolean = hops >= min && (max == null || hops <= max)
}

/** An itinerary for a hop: where it connects, in flying order, and its total length in nautical miles. */
data class Ticket(
    val via: List<Int>,
    val distance: Double
)

/** One move: a ticket from an airport to one whose code is one letter different. */
data class Hop(
    val to: Int,
    val via: List<Int>,
    val distance: Double,
    val spare: List<Ticket>
) {
    fun ticket(): Ticket = Ticket(via, distance)

    fun ticketAvoiding(used: (Int) -> Boolean): Ticket? {
        if (via.none(used)) {
            return ticket()
        }
        return spare.firstOrNull { t -> t.via.none(used) }
    }
}

/** A route found where each airport is used once (`Network.routesOnce`). */
data class OnceRoute(
    val distance: Double,
    val stops: List<Int>,
    val legs: List<Ticket>
)

/** Great-circle distance in nautical miles between two `(lat, lon)` points (haversine). */
fun greatCircleNm(a: LatLon, b: LatLon): Double {
    val lat1 = Math.toRadians(a.lat)
    val lon1 = Math.toRadians(a.lon)
    val lat2 = Math.toRadians(b.lat)
    val lon2 = Math.toRadians(b.lon)
    val sinLat = sin((lat2 - lat1) / 2.0)
    val sinLon = sin((lon2 - lon1) / 2.0)
    val h = sinLat * sinLat + cos(lat1) * cos(lat2) * sinLon * sinLon
    return 2.0 * EARTH_RADIUS_NM * asin(min(1.0, sqrt(h)))
}

/** Number of positions at which two 3-letter codes differ. */
fun lettersApart(a: String, b: String): Int {
    var diff = 0
    val len = min(a.length, b.length)
    for (i in 0 until len) {
        if (a[i] != b[i]) diff++
    }
    return diff
}

/**
 * The playable airport network for a given `maxConnections` (0, 1, or 2),
 * faithfully ported from `jotto-cli/src/flights/data.rs`.
 */
class Network private constructor(
    val maxConnections: Int,
    private val codes: List<String>,
    private val coords: List<LatLon>,
    private val places: List<Pair<String, String>>,
    private val adj: List<List<Hop>>,
    private val bridges: Set<Long>,
    private val puzzleCounts: List<Pair<Int, Int>>
) {
    val size: Int get() = codes.size

    fun isEmpty(): Boolean = codes.isEmpty()

    fun hopCount(): Int = adj.sumOf { it.size } / 2

    fun bridgeCount(): Int = bridges.size

    fun code(idx: Int): String = codes[idx]

    fun place(idx: Int): String {
        val (city, country) = places[idx]
        return when {
            city.isNotEmpty() && country.isNotEmpty() -> "$city, $country"
            city.isNotEmpty() -> city
            else -> country
        }
    }

    fun coords(idx: Int): LatLon = coords[idx]

    fun indexOf(code: String): Int? {
        val pos = codes.binarySearch(code)
        return if (pos >= 0) pos else null
    }

    fun hops(idx: Int): List<Hop> = adj[idx]

    fun hop(a: Int, b: Int): Hop? {
        val list = adj[a]
        var low = 0
        var high = list.size - 1
        while (low <= high) {
            val mid = (low + high) ushr 1
            val midVal = list[mid].to
            when {
                midVal < b -> low = mid + 1
                midVal > b -> high = mid - 1
                else -> return list[mid]
            }
        }
        return null
    }

    private data class QueueEntry(val dist: Double, val node: Int) : Comparable<QueueEntry> {
        override fun compareTo(other: QueueEntry): Int {
            val c = this.dist.compareTo(other.dist)
            return if (c != 0) c else this.node.compareTo(other.node)
        }
    }

    private inline fun dijkstra(
        source: Int,
        stop: Int?,
        improved: (from: Int, to: Int) -> Unit
    ): DoubleArray {
        val dist = DoubleArray(size) { Double.POSITIVE_INFINITY }
        val heap = PriorityQueue<QueueEntry>()
        dist[source] = 0.0
        heap.add(QueueEntry(0.0, source))
        while (heap.isNotEmpty()) {
            val entry = heap.poll() ?: break
            val d = entry.dist
            val node = entry.node
            if (stop != null && node == stop) {
                break
            }
            if (d > dist[node]) {
                continue
            }
            val neighbors = adj[node]
            for (i in neighbors.indices) {
                val hop = neighbors[i]
                val nd = d + hop.distance
                if (nd < dist[hop.to]) {
                    dist[hop.to] = nd
                    improved(node, hop.to)
                    heap.add(QueueEntry(nd, hop.to))
                }
            }
        }
        return dist
    }

    /** Shortest route from `start` to `end` by total distance in nautical miles. */
    fun shortest(start: Int, end: Int): Pair<Double, List<Int>>? {
        val prev = IntArray(size) { -1 }
        val dist = dijkstra(start, end) { from, to -> prev[to] = from }
        if (!dist[end].isFinite()) {
            return null
        }
        val path = ArrayList<Int>()
        var cur = end
        path.add(cur)
        while (cur != start) {
            cur = prev[cur]
            if (cur < 0) return null
            path.add(cur)
        }
        path.reverse()
        return dist[end] to path
    }

    private class PartialRoute(
        val at: Int,
        val from: Int,
        val ticket: Ticket?,
        val soFar: Double
    )

    /**
     * The `want` shortest routes from `start` to `end`, shortest first, when each airport may be
     * used only once in the whole trip (stops and connections included).
     */
    fun routesOnce(start: Int, end: Int, want: Int): List<OnceRoute> {
        val toEnd = dijkstra(end, null) { _, _ -> }
        if (!toEnd[start].isFinite()) {
            return emptyList()
        }
        val routes = ArrayList<PartialRoute>()
        routes.add(PartialRoute(start, -1, null, 0.0))

        val heap = PriorityQueue<QueueEntry>()
        heap.add(QueueEntry(toEnd[start], 0))
        val used = BooleanArray(size)
        val found = ArrayList<OnceRoute>(want)

        fun mark(rIdx: Int, on: Boolean) {
            var r = rIdx
            while (r != -1) {
                val node = routes[r]
                used[node.at] = on
                val via = node.ticket?.via
                if (via != null) {
                    for (i in via.indices) {
                        used[via[i]] = on
                    }
                }
                r = node.from
            }
        }

        while (heap.isNotEmpty()) {
            val entry = heap.poll() ?: break
            val r = entry.node
            val current = routes[r]
            val at = current.at
            val soFar = current.soFar

            if (at == end) {
                val stops = ArrayList<Int>()
                val legs = ArrayList<Ticket>()
                var i = r
                while (i != -1) {
                    val pr = routes[i]
                    stops.add(pr.at)
                    if (pr.ticket != null) {
                        legs.add(pr.ticket)
                    }
                    i = pr.from
                }
                stops.reverse()
                legs.reverse()
                found.add(OnceRoute(soFar, stops, legs))
                if (found.size == want) {
                    break
                }
                continue
            }

            if (routes.size > ONCE_SEARCH_LIMIT) {
                break
            }

            mark(r, true)
            val neighbors = adj[at]
            for (i in neighbors.indices) {
                val hop = neighbors[i]
                if (used[hop.to] || !toEnd[hop.to].isFinite()) {
                    continue
                }
                val ticket = hop.ticketAvoiding { idx -> used[idx] }
                if (ticket != null) {
                    val length = soFar + ticket.distance
                    routes.add(PartialRoute(hop.to, r, ticket, length))
                    heap.add(QueueEntry(length + toEnd[hop.to], routes.lastIndex))
                }
            }
            mark(r, false)
        }
        return found
    }

    fun hasTwoRoutes(start: Int, end: Int): Boolean {
        val res = shortest(start, end) ?: return false
        return crossesALoop(res.second)
    }

    private fun crossesALoop(path: List<Int>): Boolean {
        for (i in 0 until path.size - 1) {
            if (!isBridge(path[i], path[i + 1])) {
                return true
            }
        }
        return false
    }

    private fun isBridge(a: Int, b: Int): Boolean {
        return bridges.contains(edgeKey(a, b))
    }

    /** Every airport that makes a puzzle with `start` in `range`, in index order. */
    fun puzzleEnds(start: Int, range: HopRange): List<Int> {
        val n = size
        val hops = IntArray(n)
        val two = BooleanArray(n)
        val dist = dijkstra(start, null) { from, to ->
            hops[to] = hops[from] + 1
            two[to] = two[from] || !isBridge(from, to)
        }
        val startCode = code(start)
        val result = ArrayList<Int>()
        for (end in 0 until n) {
            if (dist[end].isFinite() &&
                two[end] &&
                lettersApart(startCode, code(end)) == 3 &&
                range.contains(hops[end])
            ) {
                result.add(end)
            }
        }
        return result
    }

    fun bestHops(start: Int, end: Int): Int? = shortest(start, end)?.second?.let { it.size - 1 }

    fun puzzleCount(range: HopRange): Int {
        var total = 0
        for ((hops, count) in puzzleCounts) {
            if (range.contains(hops)) {
                total += count
            }
        }
        return total
    }

    fun isValidPuzzle(start: Int, end: Int): Boolean {
        return lettersApart(code(start), code(end)) == 3 && hasTwoRoutes(start, end)
    }

    /**
     * Draws a random puzzle whose shortest route's hops are in `range`, using the exact same
     * algorithm and RNG call sequence as `Network::random_puzzle` in `jotto-cli`.
     */
    fun randomPuzzle(rng: Fastrand, range: HopRange): Pair<Int, Int>? {
        if (range.min > 3) {
            val starts = ArrayList<Int>()
            for (i in 0 until size) {
                if (adj[i].isNotEmpty()) starts.add(i)
            }
            rng.shuffle(starts)
            for (start in starts) {
                val ends = puzzleEnds(start, range)
                if (ends.isNotEmpty()) {
                    return start to ends[rng.usize(ends.size)]
                }
            }
            return null
        }

        val maxHops = range.max
        for (attempt in 0 until PUZZLE_ATTEMPTS) {
            val start = rng.usize(size)
            if (adj[start].isEmpty()) continue
            val end = randomEnd(rng, start, maxHops, END_ATTEMPTS)
            if (end != null) {
                return start to end
            }
        }

        val starts = ArrayList<Int>()
        for (i in 0 until size) {
            if (adj[i].isNotEmpty()) starts.add(i)
        }
        rng.shuffle(starts)
        for (start in starts) {
            val end = randomEnd(rng, start, maxHops, Int.MAX_VALUE)
            if (end != null) {
                return start to end
            }
        }
        return null
    }

    private fun randomEnd(
        rng: Fastrand,
        start: Int,
        maxHops: Int?,
        attempts: Int
    ): Int? {
        val startCode = code(start)
        val reachable = within(start, maxHops)
        val ends = ArrayList<Int>()
        for (i in reachable.indices) {
            val end = reachable[i]
            if (lettersApart(startCode, code(end)) == 3) {
                ends.add(end)
            }
        }
        rng.shuffle(ends)
        val limit = min(attempts, ends.size)
        for (i in 0 until limit) {
            val end = ends[i]
            val res = shortest(start, end)
            if (res != null) {
                val path = res.second
                if ((maxHops == null || path.size - 1 <= maxHops) && crossesALoop(path)) {
                    return end
                }
            }
        }
        return null
    }

    /**
     * The deterministic puzzle for a UTC day (days since 1970-01-01), identical to `jotto-cli`.
     */
    fun dailyPuzzle(utcDay: ULong, range: HopRange): Pair<Int, Int>? {
        val day = if (utcDay > Fastrand.DAILY_EPOCH_DAY) {
            utcDay - Fastrand.DAILY_EPOCH_DAY
        } else {
            0uL
        }
        val seed = Fastrand.DAILY_SEED xor (day * 0x9E37_79B9_7F4A_7C15uL)
        val rng = Fastrand(seed)
        return randomPuzzle(rng, range)
    }

    /** Airports reachable from `start` in at most `maxHops` hops, in index order. */
    private fun within(start: Int, maxHops: Int?): List<Int> {
        val depth = IntArray(size) { -1 }
        depth[start] = 0
        val queue = ArrayDeque<Int>()
        queue.add(start)
        while (queue.isNotEmpty()) {
            val node = queue.removeFirst()
            if (maxHops != null && depth[node] >= maxHops) {
                continue
            }
            val neighbors = adj[node]
            for (i in neighbors.indices) {
                val next = neighbors[i].to
                if (depth[next] == -1) {
                    depth[next] = depth[node] + 1
                    queue.addLast(next)
                }
            }
        }
        val result = ArrayList<Int>()
        for (i in 0 until size) {
            if (depth[i] != -1) {
                result.add(i)
            }
        }
        return result
    }

    companion object {
        private fun edgeKey(a: Int, b: Int): Long {
            val lo = minOf(a, b).toLong()
            val hi = maxOf(a, b).toLong() and 0xFFFF_FFFFL
            return (lo shl 32) or hi
        }

        private data class RawRoute(
            val a: String,
            val b: String,
            val best: String,
            val others: List<String>,
            val lineNum: Int
        )

        /**
         * Parses `flights.tsv` for a given `maxConnections` limit (0, 1, or 2).
         */
        fun parse(text: String, maxConnections: Int): Network {
            require(maxConnections in 0..MAX_CONNECTIONS) {
                "hops have at most $MAX_CONNECTIONS connections"
            }

            val codes = ArrayList<String>(4000)
            val coords = ArrayList<LatLon>(4000)
            val places = ArrayList<Pair<String, String>>(4000)
            val routes = ArrayList<RawRoute>(16000)
            val puzzleCounts = ArrayList<Pair<Int, Int>>()

            val lines = text.lineSequence()
            var lineIndex = 0
            for (rawLine in lines) {
                lineIndex++
                val line = rawLine.trimEnd()
                if (line.isEmpty() || line.startsWith('#')) continue
                val fields = line.split('\t')
                fun bad(): Nothing = throw IllegalArgumentException("line $lineIndex: can't read '$line'")

                when (fields[0]) {
                    "A" -> {
                        if (fields.size !in 4..6) bad()
                        val code = fields[1]
                        if (code.length != 3 || !code.all { it in 'A'..'Z' }) bad()
                        val lat = fields[2].toDoubleOrNull() ?: bad()
                        val lon = fields[3].toDoubleOrNull() ?: bad()
                        val city = fields.getOrNull(4)?.trim() ?: ""
                        val country = fields.getOrNull(5)?.trim() ?: ""
                        codes.add(code)
                        coords.add(LatLon(lat, lon))
                        places.add(city to country)
                    }
                    "H" -> {
                        val itCount = fields.size - 3
                        if (itCount !in (MAX_CONNECTIONS + 1)..(MAX_CONNECTIONS + 2)) bad()
                        val a = fields[1]
                        val b = fields[2]
                        val itineraries = fields.subList(3, fields.size)
                        val best = itineraries[maxConnections]
                        if (best != "x") {
                            val others = ArrayList<String>()
                            for (i in 0 until maxConnections) {
                                val it = itineraries[i]
                                if (it != "x" && it != best) others.add(it)
                            }
                            if (itineraries.size > MAX_CONNECTIONS + 1) {
                                for (it in itineraries[MAX_CONNECTIONS + 1].split(';')) {
                                    if (it != "x" && it != best) others.add(it)
                                }
                            }
                            routes.add(RawRoute(a, b, best, others, lineIndex))
                        }
                    }
                    "P" -> {
                        if (fields.size != 4) bad()
                        val limit = fields[1].toIntOrNull() ?: bad()
                        if (limit == maxConnections) {
                            val hops = fields[2].toIntOrNull() ?: bad()
                            val count = fields[3].toIntOrNull() ?: bad()
                            puzzleCounts.add(hops to count)
                        }
                    }
                    else -> bad()
                }
            }

            for (i in 0 until codes.size - 1) {
                require(codes[i] < codes[i + 1]) {
                    "airports must be listed once each, sorted by code"
                }
            }

            val adjMutable = List(codes.size) { ArrayList<Hop>() }

            fun indexOfCode(c: String): Int? {
                val pos = codes.binarySearch(c)
                return if (pos >= 0) pos else null
            }

            for (route in routes) {
                val x = indexOfCode(route.a)
                    ?: throw IllegalArgumentException("line ${route.lineNum}: hop through an unlisted airport")
                val y = indexOfCode(route.b)
                    ?: throw IllegalArgumentException("line ${route.lineNum}: hop through an unlisted airport")
                require(lettersApart(route.a, route.b) == 1) {
                    "line ${route.lineNum}: ${route.a} and ${route.b} aren't one letter apart"
                }

                fun readItinerary(it: String): List<Int> {
                    if (it == "-") return emptyList()
                    return it.split(',').map { c ->
                        indexOfCode(c)
                            ?: throw IllegalArgumentException("line ${route.lineNum}: hop through an unlisted airport")
                    }
                }

                fun lengthOf(via: List<Int>): Double {
                    if (via.isEmpty()) {
                        return greatCircleNm(coords[x], coords[y])
                    }
                    var total = greatCircleNm(coords[x], coords[via.first()])
                    for (i in 0 until via.size - 1) {
                        total += greatCircleNm(coords[via[i]], coords[via[i + 1]])
                    }
                    total += greatCircleNm(coords[via.last()], coords[y])
                    return total
                }

                val via = readItinerary(route.best)
                require(via.size <= maxConnections) {
                    "line ${route.lineNum}: too many connections"
                }
                val distance = lengthOf(via)

                val spare = ArrayList<Ticket>()
                for (it in route.others) {
                    val spVia = readItinerary(it)
                    if (spVia.size <= maxConnections) {
                        spare.add(Ticket(spVia, lengthOf(spVia)))
                    }
                }
                spare.sortWith { p, q -> p.distance.compareTo(q.distance) }

                val spareBack = spare.map { t ->
                    Ticket(t.via.asReversed(), t.distance)
                }

                adjMutable[y].add(
                    Hop(
                        to = x,
                        via = via.asReversed(),
                        distance = distance,
                        spare = spareBack
                    )
                )
                adjMutable[x].add(
                    Hop(
                        to = y,
                        via = via,
                        distance = distance,
                        spare = spare
                    )
                )
            }

            val adj = adjMutable.map { list ->
                list.sortBy { it.to }
                val deduped = ArrayList<Hop>(list.size)
                for (hop in list) {
                    if (deduped.isEmpty() || deduped.last().to != hop.to) {
                        deduped.add(hop)
                    }
                }
                deduped
            }

            val bridges = findBridges(codes.size, adj)
            return Network(
                maxConnections = maxConnections,
                codes = codes,
                coords = coords,
                places = places,
                adj = adj,
                bridges = bridges,
                puzzleCounts = puzzleCounts
            )
        }

        /**
         * Iterative Tarjan's low-link bridge-finding algorithm (`Network::find_bridges`).
         */
        private fun findBridges(n: Int, adj: List<List<Hop>>): Set<Long> {
            val disc = IntArray(n) { -1 }
            val low = IntArray(n)
            val out = HashSet<Long>()
            var timer = 0

            val stackNode = IntArray(n + 1)
            val stackParent = IntArray(n + 1)
            val stackPos = IntArray(n + 1)

            for (root in 0 until n) {
                if (disc[root] != -1) continue
                disc[root] = timer
                low[root] = timer
                timer++

                var top = 0
                stackNode[0] = root
                stackParent[0] = -1
                stackPos[0] = 0

                while (top >= 0) {
                    val node = stackNode[top]
                    val parent = stackParent[top]
                    val pos = stackPos[top]
                    val neighbors = adj[node]

                    if (pos < neighbors.size) {
                        stackPos[top] = pos + 1
                        val next = neighbors[pos].to
                        if (next == parent) continue
                        if (disc[next] == -1) {
                            disc[next] = timer
                            low[next] = timer
                            timer++
                            top++
                            stackNode[top] = next
                            stackParent[top] = node
                            stackPos[top] = 0
                        } else {
                            low[node] = min(low[node], disc[next])
                        }
                    } else {
                        top--
                        if (parent != -1) {
                            low[parent] = min(low[parent], low[node])
                            if (low[node] > disc[parent]) {
                                out.add(edgeKey(node, parent))
                            }
                        }
                    }
                }
            }
            return out
        }
    }
}
