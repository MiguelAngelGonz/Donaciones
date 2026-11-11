package com.donation.app.ui.publish

import android.app.Application
import android.net.Uri
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateMapOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import androidx.lifecycle.AndroidViewModel
import androidx.lifecycle.SavedStateHandle
import androidx.lifecycle.viewModelScope
import com.donation.app.container
import com.donation.app.data.ItemCondition
import com.donation.app.data.PostDraft
import com.donation.app.data.PostType
import com.donation.app.data.Urgency
import kotlinx.coroutines.launch

/**
 * CU-14 Publicar Artículo y CU-11 Publicar Necesidad comparten formulario.
 * El tipo llega por el argumento de navegación "type".
 */
class PublishViewModel(app: Application, handle: SavedStateHandle) : AndroidViewModel(app) {
    private val repo = container.repository

    val type: PostType = handle.get<String>("type")
        ?.let { name -> PostType.entries.firstOrNull { it.name == name } }
        ?: PostType.ARTICULO

    var title by mutableStateOf("")
    var description by mutableStateOf("")
    var category by mutableStateOf<String?>(null)
    var quantity by mutableStateOf("1")
    var condition by mutableStateOf<ItemCondition?>(null)
    var urgency by mutableStateOf<Urgency?>(null)
    var features by mutableStateOf("")
    var location by mutableStateOf("")
    var photos by mutableStateOf<List<Uri>>(emptyList())

    val errors = mutableStateMapOf<String, String>()

    var busy by mutableStateOf(false)
        private set
    var error by mutableStateOf<String?>(null)
        private set

    /** En un Artículo el estado es obligatorio; en una Necesidad es opcional y se puede quitar. */
    fun selectCondition(value: ItemCondition) {
        condition = if (type == PostType.NECESIDAD && condition == value) null else value
    }

    private fun validate(): Boolean {
        errors.clear()
        if (title.trim().length < 3) errors["title"] = "Escribe un nombre de al menos 3 caracteres."
        if (description.isBlank()) errors["description"] = "Agrega una descripción."
        if (category == null) errors["category"] = "Elige una categoría."
        val amount = quantity.trim().toIntOrNull()
        if (amount == null || amount < 1) errors["quantity"] = "Indica una cantidad válida (1 o más)."
        if (location.isBlank()) errors["location"] = "Indica tu colonia o código postal."
        if (type == PostType.ARTICULO) {
            if (condition == null) errors["condition"] = "Elige el estado del artículo."
            if (photos.isEmpty()) errors["photos"] = "Agrega al menos una fotografía."
        } else {
            if (urgency == null) errors["urgency"] = "Elige el nivel de urgencia."
            if (features.isBlank()) errors["features"] = "Indica las características necesarias."
        }
        return errors.isEmpty()
    }

    fun publish(onDone: () -> Unit) {
        if (busy) return
        val authorId = container.session.currentUserId ?: return
        val selectedCategory = category
        val amount = quantity.trim().toIntOrNull()
        if (!validate() || selectedCategory == null || amount == null) return

        val isArticle = type == PostType.ARTICULO
        val draft = PostDraft(
            type = type,
            title = title,
            description = description,
            category = selectedCategory,
            quantity = amount,
            condition = condition,
            urgency = if (isArticle) null else urgency,
            features = if (isArticle) "" else features,
            location = location,
            photoUris = if (isArticle) photos else emptyList()
        )

        busy = true
        error = null
        viewModelScope.launch {
            repo.publish(authorId, draft)
                .onSuccess { onDone() }
                .onFailure { e -> error = e.message }
            busy = false
        }
    }
}
