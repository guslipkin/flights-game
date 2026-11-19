package me.guslipkin.flights.ui

import android.app.Application
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import androidx.compose.ui.graphics.Color
import androidx.lifecycle.AndroidViewModel
import me.guslipkin.flights.data.CoastlineData
import me.guslipkin.flights.data.FlightsRepository
import me.guslipkin.flights.data.MapBounds
import me.guslipkin.flights.data.Network
import me.guslipkin.flights.data.Ticket
import me.guslipkin.flights.game.Difficulty
import me.guslipkin.flights.game.FlightOption
import me.guslipkin.flights.game.FlightsGame
import me.guslipkin.flights.game.FlyOutcome
import me.guslipkin.flights.game.Rules
import me.guslipkin.flights.game.Status
import me.guslipkin.flights.game.Units
import me.guslipkin.flights.ui.theme.FlightDeckColors
import me.guslipkin.flights.util.FeedbackManager
import org.json.JSONObject
import java.io.File
import kotlin.math.max

data class SelectedHopInfo(
    val from: Int,
    val ticket: Ticket,
    val to: Int,
    val isShortestRoute: Boolean,
    val hopNumber: Int
)

data class GameUiState(
    val startCode: String,
    val endCode: String,
    val currentCode: String,
    val currentAirport: Int,
    val originAirport: Int,
    val destinationAirport: Int,
    val startPlace: String,
    val endPlace: String,
    val currentPlace: String,
    val difficulty: Difficulty,
    val rules: Rules,
    val customRules: Rules,
    val units: Units,
    val curves: Boolean,
    val hapticsEnabled: Boolean,
    val soundEnabled: Boolean,
    val dailyDate: String?,
    val status: Status,
    val hops: Int,
    val totalDistanceNm: Double,
    val bestDistanceNm: Double,
    val distancesVisible: Boolean,
    val atDestination: Boolean,
    val route: List<Int>,
    val legs: List<Ticket>,
    val bestRoute: List<Int>,
    val bestLegs: List<Ticket>,
    val divergence: Int,
    val divergenceText: String,
    val options: List<FlightOption>,
    val selectedOptionIndex: Int?,
    val routeStep: Int?,
    val stepCount: Int,
    val selectedHop: SelectedHopInfo?,
    val userMapBounds: MapBounds?,
    val mapFullScreen: Boolean,
    val statusMessage: String,
    val statusColor: Color,
    val routeExpanded: Boolean,
    val showHelp: Boolean,
    val showSettings: Boolean,
    val showDifficultyDialog: Boolean,
    val shareSummary: String,
    val shareCardText: String
)

class FlightsViewModel(application: Application) : AndroidViewModel(application) {
    private val repository = FlightsRepository.fromContext(application)
    private val feedback = FeedbackManager(application)
    private val saveFile = File(application.filesDir, "saves.json")

    val coastlines: CoastlineData get() = repository.coastlines
    val networkProvider: (Int) -> Network = { maxConn -> repository.network(maxConn) }

    private var game: FlightsGame
    private var selectedOptionIndex: Int? = 0
    private var routeStep: Int? = null
    private var userMapBounds: MapBounds? = null
    private var lastFittedBounds: MapBounds = MapBounds(-180.0, 180.0, -70.0, 70.0)
    private var mapFullScreen: Boolean = false
    private var statusMessage: String = ""
    private var statusColor: Color = FlightDeckColors.TextSecondary
    private var routeExpanded: Boolean = false
    private var showHelp: Boolean = false
    private var showSettings: Boolean = false
    private var showDifficultyDialog: Boolean = false
    private var hapticsEnabled: Boolean = true
    private var soundEnabled: Boolean = true

    var uiState: GameUiState by mutableStateOf(buildPlaceholderState())
        private set

    init {
        val loaded = loadSavedGame()
        game = loaded.first
        statusMessage = loaded.second
        statusColor = loaded.third
        resetSelection()
        syncUiState()
    }

    val currentNetwork: Network get() = game.net

    private fun loadSavedGame(): Triple<FlightsGame, String, Color> {
        var savedUnits = Units.Nm
        var savedCurves = true
        var savedCustom = Rules()

        if (saveFile.exists()) {
            try {
                val root = JSONObject(saveFile.readText(Charsets.UTF_8))
                val flightsObj = root.optJSONObject("flights") ?: root
                savedUnits = Units.fromName(flightsObj.optString("units", "nm")) ?: Units.Nm
                savedCurves = flightsObj.optBoolean("curves", true)
                hapticsEnabled = flightsObj.optBoolean("haptics", true)
                soundEnabled = flightsObj.optBoolean("sound", true)
                savedCustom = flightsObj.optJSONObject("custom")?.let { Rules.fromJson(it) } ?: Rules()

                val restored = FlightsGame.fromSavedJson(flightsObj, networkProvider).getOrNull()
                if (restored != null) {
                    restored.units = savedUnits
                    restored.curves = savedCurves
                    restored.custom = savedCustom
                    val notice = if (restored.dailyDate != null) {
                        "Resumed saved Daily Challenge (${restored.dailyDate} UTC)."
                    } else {
                        "Resumed saved game (${restored.startCode} → ${restored.endCode})."
                    }
                    return Triple(restored, notice, FlightDeckColors.AccentSkyBlue)
                }
            } catch (_: Exception) {
            }
        }

        val fresh = FlightsGame.random(
            difficulty = Difficulty.Medium,
            custom = savedCustom,
            units = savedUnits,
            curves = savedCurves,
            networkProvider = networkProvider
        ).getOrElse {
            FlightsGame.random(
                difficulty = Difficulty.Medium,
                custom = Rules(),
                units = savedUnits,
                curves = savedCurves,
                networkProvider = networkProvider
            ).getOrThrow()
        }
        return Triple(fresh, welcomeMessage(fresh), FlightDeckColors.TextSecondary)
    }

    private fun saveCurrentState() {
        try {
            val flightsObj = game.toSavedJson(
                hapticsEnabled = hapticsEnabled,
                soundEnabled = soundEnabled
            )
            val root = JSONObject().apply {
                put("flights", flightsObj)
            }
            saveFile.writeText(root.toString(2), Charsets.UTF_8)
        } catch (_: Exception) {
        }
    }

    private fun welcomeMessage(g: FlightsGame): String {
        return "Fly from ${g.startCode} to ${g.endCode} by the shortest route, changing one letter per hop."
    }

    private fun resetSelection() {
        routeStep = null
        val opts = game.options()
        selectedOptionIndex = if (opts.isNotEmpty()) 0 else null
    }

    /**
     * Two-step touch interaction on an option row:
     * - First tap selects it and previews the hop on the map.
     * - Second tap on the already-selected row commits the flight.
     */
    fun onOptionTapped(index: Int) {
        if (game.status != Status.Playing) return
        val opts = game.options()
        if (index !in opts.indices) return

        if (selectedOptionIndex == index) {
            flyToCode(opts[index].code)
        } else {
            selectedOptionIndex = index
            feedback.onPreviewSelect(hapticsEnabled)
            syncUiState()
        }
    }

    /** Explicit `Fly →` button on the selected option row. */
    fun flyToSelected() {
        if (game.status != Status.Playing) return
        val opts = game.options()
        val idx = selectedOptionIndex ?: return
        val opt = opts.getOrNull(idx) ?: return
        flyToCode(opt.code)
    }

    /**
     * Tapping an airport node directly on the radar map:
     * - If it's an available option and not yet selected, selects it to preview the hop.
     * - If it's the currently selected option, flies there!
     */
    fun onMapAirportTapped(airportIdx: Int) {
        if (game.status != Status.Playing) return
        val opts = game.options()
        val matchIndex = opts.indexOfFirst { it.airport == airportIdx }
        if (matchIndex >= 0) {
            onOptionTapped(matchIndex)
        }
    }

    fun flyToCode(rawCode: String) {
        val code = rawCode.uppercase()
        val res = game.fly(code)
        res.fold(
            onSuccess = { outcome ->
                when (outcome) {
                    is FlyOutcome.Flew -> {
                        val details = buildList {
                            if (game.rules.showsDistances()) {
                                add(game.units.format(outcome.distance))
                            }
                            val via = arrivalVia()
                            if (via.isNotEmpty()) {
                                add(via.trimStart())
                            }
                        }
                        val suffix = if (details.isEmpty()) "" else " (${details.joinToString(" ")})"
                        statusMessage = "Flew to $code$suffix."
                        statusColor = FlightDeckColors.TextSecondary
                        feedback.onHop(hapticsEnabled, soundEnabled)
                    }
                    is FlyOutcome.Longer -> {
                        val how = if (game.rules.showsAmountOver()) {
                            "${game.units.format(outcome.over)} longer than the shortest route"
                        } else {
                            "not by the shortest route"
                        }
                        statusMessage = "You reached $code, but $how.\nTap Go Back to find a shorter way."
                        statusColor = FlightDeckColors.WarningOrange
                        feedback.onLongerRoute(hapticsEnabled, soundEnabled)
                    }
                    FlyOutcome.Won -> {
                        statusMessage = "You found the shortest route!\n${game.shareSummary()}"
                        statusColor = FlightDeckColors.PositiveGreen
                        routeExpanded = true
                        mapFullScreen = false
                        feedback.onVictory(hapticsEnabled, soundEnabled)
                    }
                }
            },
            onFailure = { err ->
                statusMessage = err.message ?: "Unable to fly to $code."
                statusColor = FlightDeckColors.WarningOrange
            }
        )
        resetSelection()
        saveCurrentState()
        syncUiState()
    }

    private fun arrivalVia(): String {
        val lastLeg = game.legs.lastOrNull() ?: return ""
        if (!game.rules.showsConnections() || lastLeg.via.isEmpty()) return ""
        val codes = lastLeg.via.joinToString(", ") { game.net.code(it) }
        return " via $codes"
    }

    fun goBack() {
        if (game.status != Status.Playing) return
        val net = game.net
        val left = game.back()
        if (left != null) {
            statusMessage = "Back at ${net.code(game.current)} (left ${net.code(left)})."
            statusColor = FlightDeckColors.TextSecondary
            val opts = game.options()
            val prevChoiceIdx = opts.indexOfFirst { it.airport == left }
            selectedOptionIndex = when {
                prevChoiceIdx >= 0 -> prevChoiceIdx
                opts.isNotEmpty() -> 0
                else -> null
            }
            feedback.onBacktrack(hapticsEnabled, soundEnabled)
            saveCurrentState()
        } else {
            statusMessage = "You're at the start; there's nowhere to go back to."
            statusColor = FlightDeckColors.WarningOrange
        }
        syncUiState()
    }

    fun startNewGame(newDifficulty: Difficulty? = null) {
        val targetDifficulty = newDifficulty ?: game.difficulty
        val nextGame = FlightsGame.random(
            difficulty = targetDifficulty,
            custom = game.custom,
            units = game.units,
            curves = game.curves,
            networkProvider = networkProvider
        )
        nextGame.fold(
            onSuccess = { g ->
                game = g
                val about = if (targetDifficulty == Difficulty.Custom) {
                    game.rules.summary()
                } else {
                    targetDifficulty.description
                }
                routeExpanded = false
                if (!game.rules.showsMap()) {
                    mapFullScreen = false
                }
                afterRestart("New game started!\nDifficulty: ${targetDifficulty.label} ($about).")
            },
            onFailure = { err ->
                statusMessage = err.message ?: "Can't start game with current settings."
                statusColor = FlightDeckColors.WarningOrange
                syncUiState()
            }
        )
    }

    fun startDailyGame() {
        game = FlightsGame.newDaily(
            custom = game.custom,
            units = game.units,
            curves = game.curves,
            networkProvider = networkProvider
        )
        routeExpanded = false
        val date = game.dailyDate ?: "today"
        afterRestart("Daily Challenge ($date UTC) started!\nDifficulty: ${game.difficulty.label}.")
    }

    fun selectDifficultyFromDialog(difficulty: Difficulty) {
        showDifficultyDialog = false
        startNewGame(difficulty)
    }

    fun openCustomFromDifficultyDialog() {
        showDifficultyDialog = false
        showSettings = true
        syncUiState()
    }

    fun cycleUnits() {
        val next = game.units.next()
        game.units = next
        statusMessage = "Distances now in ${next.label}."
        statusColor = FlightDeckColors.AccentSkyBlue
        saveCurrentState()
        syncUiState()
    }

    fun triggerGiveUp() {
        if (game.status != Status.Playing) return
        game.giveUp()
        resetSelection()
        routeExpanded = true
        mapFullScreen = false
        statusMessage = "A shortest route: ${game.routeText(game.bestRoute)} (${game.units.format(game.bestDistance)})\n${game.divergenceText()}"
        statusColor = FlightDeckColors.WarningOrange
        saveCurrentState()
        syncUiState()
    }

    private fun afterRestart(message: String) {
        resetSelection()
        userMapBounds = null
        statusMessage = message
        statusColor = FlightDeckColors.AccentSkyBlue
        saveCurrentState()
        syncUiState()
    }

    fun stepRouteHop(down: Boolean) {
        if (game.status == Status.Playing) return
        val totalSteps = computeStepCount()
        if (totalSteps <= 0) return
        val last = totalSteps - 1
        routeStep = when (val cur = routeStep) {
            null -> if (down) 0 else last
            else -> if (down) (cur + 1).coerceAtMost(last) else (cur - 1).coerceAtLeast(0)
        }
        feedback.onPreviewSelect(hapticsEnabled)
        syncUiState()
    }

    fun selectRouteHop(step: Int?) {
        if (game.status == Status.Playing) return
        val totalSteps = computeStepCount()
        routeStep = if (step != null && step in 0 until totalSteps) {
            if (routeStep == step) null else step
        } else {
            null
        }
        feedback.onPreviewSelect(hapticsEnabled)
        syncUiState()
    }

    fun toggleRouteExpanded() {
        routeExpanded = !routeExpanded
        syncUiState()
    }

    fun toggleMapFullScreen() {
        mapFullScreen = !mapFullScreen
        syncUiState()
    }

    fun setHelpVisible(visible: Boolean) {
        showHelp = visible
        syncUiState()
    }

    fun setSettingsVisible(visible: Boolean) {
        showSettings = visible
        syncUiState()
    }

    fun setDifficultyDialogVisible(visible: Boolean) {
        showDifficultyDialog = visible
        syncUiState()
    }

    fun applySettings(
        units: Units,
        curves: Boolean,
        haptics: Boolean,
        sound: Boolean,
        custom: Rules,
        playCustom: Boolean
    ): String? {
        game.units = units
        game.curves = curves
        hapticsEnabled = haptics
        soundEnabled = sound
        game.custom = custom

        if (!playCustom) {
            showSettings = false
            statusMessage = "Settings saved."
            statusColor = FlightDeckColors.AccentSkyBlue
            saveCurrentState()
            syncUiState()
            return null
        }

        val checkRes = custom.check(networkProvider)
        if (checkRes.isFailure) {
            val why = checkRes.exceptionOrNull()?.message ?: "no puzzles fit these settings"
            return "Can't play: $why."
        }

        showSettings = false
        startNewGame(Difficulty.Custom)
        return null
    }

    fun updateFittedBounds(bounds: MapBounds) {
        lastFittedBounds = bounds
    }

    /**
     * Zooms the map by `factor` (< 1 zooms in, > 1 zooms out) around `(focusFracX, focusFracY)`
     * where `(0, 0)` is top-left and `(1, 1)` is bottom-right.
     */
    fun zoomMap(
        factor: Double,
        focusFracX: Double = 0.5,
        focusFracY: Double = 0.5
    ) {
        val cur = userMapBounds ?: lastFittedBounds
        val widest = max(CoastlineData.MAX_VIEW_LAT, lastFittedBounds.latSpan)
        val newLatSpan = cur.latSpan * factor
        if (newLatSpan < CoastlineData.MIN_VIEW_LAT || newLatSpan > widest) {
            return
        }
        val cx = cur.lonMin + focusFracX * cur.lonSpan
        val cy = cur.latMax - focusFracY * cur.latSpan
        userMapBounds = MapBounds(
            lonMin = cx - (cx - cur.lonMin) * factor,
            lonMax = cx + (cur.lonMax - cx) * factor,
            latMin = cy - (cy - cur.latMin) * factor,
            latMax = cy + (cur.latMax - cy) * factor
        )
        syncUiState()
    }

    /**
     * Multi-touch gesture transform on the radar map: applies both pinch-zoom (`zoomFactor` < 1 zooms in)
     * around `(focusFracX, focusFracY)` and drag pan (`panFracX`, `panFracY` as fractions of view size).
     */
    fun transformMap(
        zoomFactor: Double,
        panFracX: Double,
        panFracY: Double,
        focusFracX: Double,
        focusFracY: Double
    ) {
        var cur = userMapBounds ?: lastFittedBounds

        // 1. Apply pan
        if (panFracX != 0.0 || panFracY != 0.0) {
            val dLon = -panFracX * cur.lonSpan
            val dLat = panFracY * cur.latSpan
            cur = MapBounds(
                lonMin = cur.lonMin + dLon,
                lonMax = cur.lonMax + dLon,
                latMin = cur.latMin + dLat,
                latMax = cur.latMax + dLat
            )
        }

        // 2. Apply zoom
        if (zoomFactor != 1.0) {
            val widest = max(CoastlineData.MAX_VIEW_LAT, lastFittedBounds.latSpan)
            val clampedFactor = when {
                cur.latSpan * zoomFactor < CoastlineData.MIN_VIEW_LAT ->
                    CoastlineData.MIN_VIEW_LAT / cur.latSpan
                cur.latSpan * zoomFactor > widest ->
                    widest / cur.latSpan
                else -> zoomFactor
            }
            val cx = cur.lonMin + focusFracX * cur.lonSpan
            val cy = cur.latMax - focusFracY * cur.latSpan
            cur = MapBounds(
                lonMin = cx - (cx - cur.lonMin) * clampedFactor,
                lonMax = cx + (cur.lonMax - cx) * clampedFactor,
                latMin = cy - (cy - cur.latMin) * clampedFactor,
                latMax = cy + (cur.latMax - cy) * clampedFactor
            )
        }

        userMapBounds = cur
        syncUiState()
    }

    fun fitMap() {
        userMapBounds = null
        syncUiState()
    }

    private fun computeStepCount(): Int {
        val best = if (game.status == Status.GivenUp) game.bestLegs.size else 0
        return game.legs.size + best
    }

    private fun computeSelectedHop(): SelectedHopInfo? {
        val step = routeStep ?: return null
        val yours = game.legs.size
        return if (step < yours) {
            val from = game.route.getOrNull(step) ?: return null
            val ticket = game.legs.getOrNull(step) ?: return null
            val to = game.route.getOrNull(step + 1) ?: return null
            SelectedHopInfo(
                from = from,
                ticket = ticket,
                to = to,
                isShortestRoute = false,
                hopNumber = step + 1
            )
        } else {
            val idx = step - yours
            val from = game.bestRoute.getOrNull(idx) ?: return null
            val ticket = game.bestLegs.getOrNull(idx) ?: return null
            val to = game.bestRoute.getOrNull(idx + 1) ?: return null
            SelectedHopInfo(
                from = from,
                ticket = ticket,
                to = to,
                isShortestRoute = true,
                hopNumber = idx + 1
            )
        }
    }

    private fun syncUiState() {
        val net = game.net
        val opts = game.options()
        val stepCount = computeStepCount()
        val selHop = computeSelectedHop()

        uiState = GameUiState(
            startCode = game.startCode,
            endCode = game.endCode,
            currentCode = game.currentCode,
            currentAirport = game.current,
            originAirport = game.origin,
            destinationAirport = game.destination,
            startPlace = net.place(game.origin),
            endPlace = net.place(game.destination),
            currentPlace = net.place(game.current),
            difficulty = game.difficulty,
            rules = game.rules,
            customRules = game.custom,
            units = game.units,
            curves = game.curves,
            hapticsEnabled = hapticsEnabled,
            soundEnabled = soundEnabled,
            dailyDate = game.dailyDate,
            status = game.status,
            hops = game.hops,
            totalDistanceNm = game.totalDistance(),
            bestDistanceNm = game.bestDistance,
            distancesVisible = game.distancesVisible(),
            atDestination = game.atDestination(),
            route = game.route.toList(),
            legs = game.legs.toList(),
            bestRoute = game.bestRoute,
            bestLegs = game.bestLegs,
            divergence = game.divergence(),
            divergenceText = game.divergenceText(),
            options = opts,
            selectedOptionIndex = selectedOptionIndex,
            routeStep = routeStep,
            stepCount = stepCount,
            selectedHop = selHop,
            userMapBounds = userMapBounds,
            mapFullScreen = mapFullScreen && game.rules.showsMap(),
            statusMessage = statusMessage,
            statusColor = statusColor,
            routeExpanded = routeExpanded || game.status != Status.Playing,
            showHelp = showHelp,
            showSettings = showSettings,
            showDifficultyDialog = showDifficultyDialog,
            shareSummary = game.shareSummary(),
            shareCardText = game.shareCardText()
        )
    }

    private fun buildPlaceholderState(): GameUiState {
        return GameUiState(
            startCode = "---",
            endCode = "---",
            currentCode = "---",
            currentAirport = 0,
            originAirport = 0,
            destinationAirport = 0,
            startPlace = "",
            endPlace = "",
            currentPlace = "",
            difficulty = Difficulty.Medium,
            rules = Rules(),
            customRules = Rules(),
            units = Units.Nm,
            curves = true,
            hapticsEnabled = true,
            soundEnabled = true,
            dailyDate = null,
            status = Status.Playing,
            hops = 0,
            totalDistanceNm = 0.0,
            bestDistanceNm = 0.0,
            distancesVisible = false,
            atDestination = false,
            route = emptyList(),
            legs = emptyList(),
            bestRoute = emptyList(),
            bestLegs = emptyList(),
            divergence = 0,
            divergenceText = "",
            options = emptyList(),
            selectedOptionIndex = null,
            routeStep = null,
            stepCount = 0,
            selectedHop = null,
            userMapBounds = null,
            mapFullScreen = false,
            statusMessage = "",
            statusColor = FlightDeckColors.TextSecondary,
            routeExpanded = false,
            showHelp = false,
            showSettings = false,
            showDifficultyDialog = false,
            shareSummary = "",
            shareCardText = ""
        )
    }
}
