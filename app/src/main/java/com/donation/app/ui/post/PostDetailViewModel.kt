package com.donation.app.ui.post

import android.app.Application
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import androidx.lifecycle.AndroidViewModel
import androidx.lifecycle.SavedStateHandle
import androidx.lifecycle.viewModelScope
import com.donation.app.container
import com.donation.app.data.PostEntity
import com.donation.app.data.RequestEntity
import com.donation.app.data.RequestWithUser
import com.donation.app.data.UserEntity
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.flow.SharingStarted
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.flatMapLatest
import kotlinx.coroutines.flow.flowOf
import kotlinx.coroutines.flow.stateIn
import kotlinx.coroutines.launch
import java.util.UUID

/** Detalle de una publicación: CU-23 Solicitar artículo (donatario) y CU-27 Aceptar solicitud (donante). */
class PostDetailViewModel(app: Application, handle: SavedStateHandle) : AndroidViewModel(app) {
    private val repo = container.repository

    private val postId: Long = handle.get<Long>("postId") ?: -1L
    val userId: Long = container.session.currentUserId ?: -1L

    val post: StateFlow<PostEntity?> =
        repo.observePost(postId).stateIn(viewModelScope, SharingStarted.WhileSubscribed(5_000), null)

    @OptIn(ExperimentalCoroutinesApi::class)
    val author: StateFlow<UserEntity?> =
        repo.observePost(postId)
            .flatMapLatest { p -> if (p == null) flowOf<UserEntity?>(null) else repo.observeUser(p.authorId) }
            .stateIn(viewModelScope, SharingStarted.WhileSubscribed(5_000), null)

    /** Solicitudes pendientes; solo las consulta el autor del artículo. */
    val requests: StateFlow<List<RequestWithUser>> =
        repo.observePendingRequests(postId)
            .stateIn(viewModelScope, SharingStarted.WhileSubscribed(5_000), emptyList())

    /** La solicitud pendiente de quien está mirando la publicación, si la hay. */
    val myRequest: StateFlow<RequestEntity?> =
        repo.observeUserPendingRequest(postId, userId)
            .stateIn(viewModelScope, SharingStarted.WhileSubscribed(5_000), null)

    var showDialog by mutableStateOf(false)
        private set
    var message by mutableStateOf("")
    var busy by mutableStateOf(false)
        private set
    var error by mutableStateOf<String?>(null)
        private set

    // La clave cambia cada vez que se abre el diálogo; dos toques en "Enviar" comparten clave (RNF-11).
    private var clientKey = UUID.randomUUID().toString()

    fun openDialog() {
        message = ""
        error = null
        clientKey = UUID.randomUUID().toString()
        showDialog = true
    }

    fun closeDialog() {
        showDialog = false
        error = null
    }

    fun sendRequest() {
        if (busy) return
        busy = true
        error = null
        viewModelScope.launch {
            repo.sendRequest(postId, userId, message, clientKey)
                .onSuccess { showDialog = false }
                .onFailure { e -> error = e.message }
            busy = false
        }
    }

    fun accept(requestId: Long, onAccepted: (Long) -> Unit) {
        if (busy) return
        busy = true
        error = null
        viewModelScope.launch {
            repo.acceptRequest(requestId, userId)
                .onSuccess { donationId -> onAccepted(donationId) }
                .onFailure { e -> error = e.message }
            busy = false
        }
    }
}
