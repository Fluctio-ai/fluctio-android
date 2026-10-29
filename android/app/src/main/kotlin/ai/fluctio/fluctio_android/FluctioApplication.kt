package ai.fluctio.fluctio_android

import android.app.Application
import androidx.work.Configuration

/// FluctioApplication exists for one reason: WorkManager initialization.
///
/// The manifest disables androidx.startup's WorkManagerInitializer (eager
/// init at process start created the WorkDatabase too early and crashed
/// release builds under R8). Disabling it without a replacement leaves
/// WorkManager permanently uninitialized, and the background notification
/// poller's `registerPeriodicTask` then throws
/// "WorkManager is not initialized properly" — the 15-minute worker never
/// registers, so push delivery only ever worked while the app was in the
/// foreground (found on-device 2026-10-29).
///
/// Implementing Configuration.Provider is androidx's documented
/// replacement: WorkManager initializes on demand, the first time anything
/// calls getInstance — after the app is fully up, not during process
/// start, so the original crash cannot come back.
class FluctioApplication : Application(), Configuration.Provider {
    override val workManagerConfiguration: Configuration
        get() = Configuration.Builder().build()
}
