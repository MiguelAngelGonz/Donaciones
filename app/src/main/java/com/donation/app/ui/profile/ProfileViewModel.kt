package com.donation.app.ui.profile

import android.app.Application
import androidx.lifecycle.AndroidViewModel
import androidx.lifecycle.viewModelScope
import com.donation.app.container
import com.donation.app.data.DonationStatus
import com.donation.app.data.UserEntity
import kotlinx.coroutines.flow.SharingStarted
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.combine
import kotlinx.coroutines.flow.stateIn
import kotlinx.coroutines.launch

/** Métricas del piloto definidas en la metodología: publicaciones, solicitudes, contactos y tasa de confirmación. */
data class Metrics(
    val posts: Int,
    val requests: Int,
    /** Donaciones creadas = "contactos" (se acordó una entrega). */
    val accepted: Int,
    val finalized: Int,
    val canceled: Int
) {
    /** Tasa de confirmación de entrega = finalizadas ÷ (aceptadas − canceladas), en porcentaje. */
    val rate: Int?
        get() {
            val base = accepted - canceled
            return if (base > 0) finalized * 100 / base else null
        }
}

class ProfileViewModel(app: Application) : AndroidViewModel(app) {
    private val repo = container.repository
    private val userId: Long = container.session.currentUserId ?: -1L

    val user: StateFlow<UserEntity?> =
        repo.observeUser(userId).stateIn(viewModelScope, SharingStarted.WhileSubscribed(5_000), null)

    val metrics: StateFlow<Metrics?> =
        combine(
            repo.observePostCount(),
            repo.observeRequestCount(),
            repo.observeDonationCount(),
            repo.observeDonationCountByStatus(DonationStatus.FINALIZADA),
            repo.observeDonationCountByStatus(DonationStatus.CANCELADA)
        ) { posts, requests, accepted, finalized, canceled ->
            Metrics(posts, requests, accepted, finalized, canceled)
        }.stateIn(viewModelScope, SharingStarted.WhileSubscribed(5_000), null)

    fun setPhoneShared(shared: Boolean) {
        viewModelScope.launch { repo.setPhoneShared(userId, shared) }
    }

    /** CU-10 · Cerrar sesión. La navegación reacciona al cambio de sesión. */
    fun logout() {
        container.session.close()
    }
}
