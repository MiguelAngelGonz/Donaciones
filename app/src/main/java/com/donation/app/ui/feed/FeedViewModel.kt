package com.donation.app.ui.feed

import android.app.Application
import androidx.lifecycle.AndroidViewModel
import androidx.lifecycle.viewModelScope
import com.donation.app.container
import com.donation.app.data.PostEntity
import com.donation.app.data.PostType
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.SharingStarted
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.combine
import kotlinx.coroutines.flow.flatMapLatest
import kotlinx.coroutines.flow.stateIn

/** CU-19 · Filtrar publicaciones por categoría y tipo (feed cronológico). */
class FeedViewModel(app: Application) : AndroidViewModel(app) {
    private val repo = container.repository

    val userId: Long = container.session.currentUserId ?: -1L

    private val _type = MutableStateFlow<PostType?>(null)
    private val _category = MutableStateFlow<String?>(null)
    val type: StateFlow<PostType?> = _type.asStateFlow()
    val category: StateFlow<String?> = _category.asStateFlow()

    /** null mientras carga la primera vez, para no mostrar "sin resultados" por un instante. */
    @OptIn(ExperimentalCoroutinesApi::class)
    val posts: StateFlow<List<PostEntity>?> =
        combine(_type, _category) { t, c -> t to c }
            .flatMapLatest { (t, c) -> repo.observeFeed(t, c) }
            .stateIn(viewModelScope, SharingStarted.WhileSubscribed(5_000), null)

    fun selectType(type: PostType?) {
        _type.value = type
    }

    fun selectCategory(category: String) {
        _category.value = if (_category.value == category) null else category
    }
}
