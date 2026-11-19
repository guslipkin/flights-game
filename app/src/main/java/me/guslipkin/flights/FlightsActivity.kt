package me.guslipkin.flights

import android.content.pm.ActivityInfo
import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.SystemBarStyle
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.activity.viewModels
import me.guslipkin.flights.ui.FlightsScreen
import me.guslipkin.flights.ui.FlightsViewModel
import me.guslipkin.flights.ui.theme.FlightDeckTheme

class FlightsActivity : ComponentActivity() {
    private val viewModel: FlightsViewModel by viewModels()

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        // Lock phones / small screens (< 600dp smallest width) to portrait
        if (resources.configuration.smallestScreenWidthDp < 600) {
            requestedOrientation = ActivityInfo.SCREEN_ORIENTATION_PORTRAIT
        } else {
            requestedOrientation = ActivityInfo.SCREEN_ORIENTATION_UNSPECIFIED
        }
        enableEdgeToEdge(
            statusBarStyle = SystemBarStyle.dark(0xFF090D12.toInt()),
            navigationBarStyle = SystemBarStyle.dark(0xFF0D1117.toInt())
        )
        setContent {
            FlightDeckTheme {
                FlightsScreen(viewModel = viewModel)
            }
        }
    }
}
