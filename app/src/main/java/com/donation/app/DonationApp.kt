package com.donation.app

import android.app.Application
import android.content.Context
import androidx.lifecycle.AndroidViewModel
import com.donation.app.data.AppDatabase
import com.donation.app.data.DonationRepository
import com.donation.app.data.SessionManager

class DonationApp : Application() {
    lateinit var container: AppContainer
        private set

    override fun onCreate() {
        super.onCreate()
        container = AppContainer(this)
    }
}

/** Dependencias compartidas de la app (sin librería de inyección, suficiente para el MVP). */
class AppContainer(context: Context) {
    val session = SessionManager(context)
    val repository = DonationRepository(context.applicationContext, AppDatabase.build(context))
}

val AndroidViewModel.container: AppContainer
    get() = getApplication<DonationApp>().container
