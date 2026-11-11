package com.donation.app.ui.donation

import android.app.Application
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import androidx.lifecycle.AndroidViewModel
import androidx.lifecycle.SavedStateHandle
import androidx.lifecycle.viewModelScope
import com.donation.app.container
import com.donation.app.data.ChangeWithActor
import com.donation.app.data.DonationView
import kotlinx.coroutines.flow.SharingStarted
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.stateIn
import kotlinx.coroutines.launch

/** Lista de donaciones del usuario, como donante o como donatario. */
class DonationsListViewModel(app: Application) : AndroidViewModel(app) {
    private val repo = container.repository

    val userId: Long = container.session.currentUserId ?: -1L

    val donations: StateFlow<List<DonationView>?> =
        repo.observeDonationViews(userId)
            .stateIn(viewModelScope, SharingStarted.WhileSubscribed(5_000), null)

    init {
        // RF-12: las donaciones Entregadas sin confirmar a los 7 días se finalizan solas.
        viewModelScope.launch { repo.autoFinalizeExpired() }
    }
}

/** CU-30 a CU-36 en su versión MVP: estado, contacto, marcar entregada, confirmar y cancelar. */
class DonationDetailViewModel(app: Application, handle: SavedStateHandle) : AndroidViewModel(app) {
    private val repo = container.repository

    private val donationId: Long = handle.get<Long>("donationId") ?: -1L
    val userId: Long = container.session.currentUserId ?: -1L

    val donation: StateFlow<DonationView?> =
        repo.observeDonationView(donationId)
            .stateIn(viewModelScope, SharingStarted.WhileSubscribed(5_000), null)

    val changes: StateFlow<List<ChangeWithActor>> =
        repo.observeChanges(donationId)
            .stateIn(viewModelScope, SharingStarted.WhileSubscribed(5_000), emptyList())

    var busy by mutableStateOf(false)
        private set
    var error by mutableStateOf<String?>(null)
        private set

    var showCancelDialog by mutableStateOf(false)
        private set
    var cancelReason by mutableStateOf("")

    init {
        viewModelScope.launch { repo.autoFinalizeExpired() }
    }

    private fun perform(after: () -> Unit = {}, block: suspend () -> Result<Unit>) {
        if (busy) return
        busy = true
        error = null
        viewModelScope.launch {
            block()
                .onSuccess { after() }
                .onFailure { e -> error = e.message }
            busy = false
        }
    }

    fun markDelivered() = perform { repo.markDelivered(donationId, userId) }

    fun confirmReception() = perform { repo.confirmReception(donationId, userId) }

    fun openCancel() {
        cancelReason = ""
        error = null
        showCancelDialog = true
    }

    fun dismissCancel() {
        showCancelDialog = false
        error = null
    }

    fun cancel() = perform(after = { showCancelDialog = false }) {
        repo.cancelDonation(donationId, userId, cancelReason)
    }
}
