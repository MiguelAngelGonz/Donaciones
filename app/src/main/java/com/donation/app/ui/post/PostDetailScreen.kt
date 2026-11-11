package com.donation.app.ui.post

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Button
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.lifecycle.viewmodel.compose.viewModel
import com.donation.app.data.PostStatus
import com.donation.app.data.PostType
import com.donation.app.data.RequestWithUser
import com.donation.app.data.Validators
import com.donation.app.data.photos
import com.donation.app.ui.components.AppTextField
import com.donation.app.ui.components.AppTopBar
import com.donation.app.ui.components.InfoRow
import com.donation.app.ui.components.LabelChip
import com.donation.app.ui.components.LoadingBox
import com.donation.app.ui.components.PhotoGallery
import com.donation.app.ui.components.SurfaceCard
import com.donation.app.ui.components.UrgencyChip
import com.donation.app.ui.components.formatDate
import com.donation.app.ui.theme.Primario
import com.donation.app.ui.theme.SuperficieSuave
import com.donation.app.ui.theme.TextoPrincipal

@Composable
fun PostDetailScreen(
    onBack: () -> Unit,
    onOpenDonation: (Long) -> Unit,
    vm: PostDetailViewModel = viewModel()
) {
    val post by vm.post.collectAsStateWithLifecycle()
    val author by vm.author.collectAsStateWithLifecycle()
    val requests by vm.requests.collectAsStateWithLifecycle()
    val myRequest by vm.myRequest.collectAsStateWithLifecycle()

    Scaffold(topBar = { AppTopBar("Detalle", onBack) }) { padding ->
        val p = post
        if (p == null) {
            LoadingBox(Modifier.padding(padding))
        } else {
            val isArticle = p.type == PostType.ARTICULO
            val isAuthor = p.authorId == vm.userId
            val photos = p.photos()

            Column(
                modifier = Modifier
                    .padding(padding)
                    .verticalScroll(rememberScrollState())
                    .padding(16.dp),
                verticalArrangement = Arrangement.spacedBy(12.dp)
            ) {
                if (photos.isNotEmpty()) PhotoGallery(photos)

                Row(horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                    LabelChip(p.type.label, Primario, Color.White)
                    p.urgency?.let { UrgencyChip(it) }
                    LabelChip(p.status.label, SuperficieSuave, TextoPrincipal)
                }
                Text(p.title, style = MaterialTheme.typography.headlineSmall, fontWeight = FontWeight.Bold)

                SurfaceCard {
                    InfoRow("Categoría", p.category)
                    InfoRow(if (isArticle) "Cantidad disponible" else "Cantidad requerida", p.quantity.toString())
                    p.condition?.let { InfoRow(if (isArticle) "Estado" else "Estado aceptable", it.label) }
                    InfoRow("Ubicación aproximada", p.location)
                    InfoRow("Publicado por", "@${author?.username ?: "…"}")
                    InfoRow("Fecha", formatDate(p.createdAt))
                }

                SurfaceCard {
                    Text("Descripción", style = MaterialTheme.typography.titleSmall, fontWeight = FontWeight.Bold)
                    Text(p.description)
                    if (p.features.isNotBlank()) {
                        Text("Características", style = MaterialTheme.typography.titleSmall, fontWeight = FontWeight.Bold)
                        Text(p.features)
                    }
                }

                // CU-27 · El autor del artículo revisa y acepta solicitudes.
                if (isArticle && isAuthor) {
                    if (p.status == PostStatus.ACTIVA) {
                        Text(
                            "Solicitudes recibidas (${requests.size})",
                            style = MaterialTheme.typography.titleMedium,
                            fontWeight = FontWeight.Bold
                        )
                        if (requests.isEmpty()) Text("Aún no hay solicitudes.")
                        requests.forEach { request ->
                            RequestCard(
                                request = request,
                                enabled = !vm.busy,
                                onAccept = { vm.accept(request.id, onOpenDonation) }
                            )
                        }
                    } else {
                        Text(
                            "Esta publicación está ${p.status.label.lowercase()}. " +
                                "Da seguimiento en la pestaña Donaciones."
                        )
                    }
                }

                // CU-23 · Otro usuario solicita el artículo.
                if (isArticle && !isAuthor) {
                    when {
                        p.status != PostStatus.ACTIVA -> Text("Este artículo ya no está disponible.")
                        myRequest != null -> Text(
                            "Enviaste una solicitud. Espera la respuesta del donante.",
                            fontWeight = FontWeight.SemiBold
                        )
                        else -> Button(onClick = vm::openDialog, modifier = Modifier.fillMaxWidth()) {
                            Text("Solicitar este artículo")
                        }
                    }
                }

                if (!vm.showDialog) {
                    vm.error?.let {
                        Text(it, color = MaterialTheme.colorScheme.error, fontWeight = FontWeight.SemiBold)
                    }
                }
            }
        }
    }

    if (vm.showDialog) {
        AlertDialog(
            onDismissRequest = { if (!vm.busy) vm.closeDialog() },
            title = { Text("Solicitar artículo") },
            text = {
                Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                    AppTextField(
                        value = vm.message,
                        onValueChange = { vm.message = it },
                        label = "Mensaje para el donante (opcional)",
                        singleLine = false,
                        minLines = 3,
                        maxChars = Validators.MAX_MESSAGE,
                        hint = "${vm.message.length}/${Validators.MAX_MESSAGE}"
                    )
                    vm.error?.let {
                        Text(it, color = MaterialTheme.colorScheme.error, fontWeight = FontWeight.SemiBold)
                    }
                }
            },
            confirmButton = {
                Button(onClick = vm::sendRequest, enabled = !vm.busy) {
                    Text(if (vm.busy) "Enviando…" else "Enviar solicitud")
                }
            },
            dismissButton = {
                TextButton(onClick = vm::closeDialog, enabled = !vm.busy) { Text("Cancelar") }
            }
        )
    }
}

@Composable
private fun RequestCard(request: RequestWithUser, enabled: Boolean, onAccept: () -> Unit) {
    SurfaceCard {
        Text("@${request.requesterUsername}", fontWeight = FontWeight.Bold)
        Text(formatDate(request.createdAt), style = MaterialTheme.typography.bodySmall)
        Text(if (request.message.isBlank()) "Sin mensaje." else request.message)
        Button(onClick = onAccept, enabled = enabled, modifier = Modifier.fillMaxWidth()) {
            Text("Aceptar solicitud")
        }
    }
}
