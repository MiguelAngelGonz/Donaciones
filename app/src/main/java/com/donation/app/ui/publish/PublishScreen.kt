package com.donation.app.ui.publish

import android.widget.Toast
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.PickVisualMediaRequest
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Add
import androidx.compose.material3.Button
import androidx.compose.material3.FilledTonalButton
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.unit.dp
import androidx.lifecycle.viewmodel.compose.viewModel
import coil.compose.AsyncImage
import com.donation.app.data.Categories
import com.donation.app.data.DonationRepository
import com.donation.app.data.ItemCondition
import com.donation.app.data.PostType
import com.donation.app.data.Urgency
import com.donation.app.ui.components.AppTextField
import com.donation.app.ui.components.AppTopBar
import com.donation.app.ui.components.ChipGroup

/** CU-14 Publicar Artículo / CU-11 Publicar Necesidad. */
@Composable
fun PublishScreen(onBack: () -> Unit, vm: PublishViewModel = viewModel()) {
    val context = LocalContext.current
    val isArticle = vm.type == PostType.ARTICULO

    val picker = rememberLauncherForActivityResult(
        ActivityResultContracts.PickMultipleVisualMedia(DonationRepository.MAX_PHOTOS)
    ) { uris ->
        if (uris.isNotEmpty()) vm.photos = uris.take(DonationRepository.MAX_PHOTOS)
    }

    Scaffold(
        topBar = { AppTopBar(if (isArticle) "Donar un artículo" else "Publicar una necesidad", onBack) }
    ) { padding ->
        Column(
            modifier = Modifier
                .padding(padding)
                .verticalScroll(rememberScrollState())
                .padding(16.dp),
            verticalArrangement = Arrangement.spacedBy(12.dp)
        ) {
            AppTextField(
                value = vm.title,
                onValueChange = { vm.title = it },
                label = if (isArticle) "Nombre del artículo" else "Artículo que necesitas",
                error = vm.errors["title"]
            )
            AppTextField(
                value = vm.description,
                onValueChange = { vm.description = it },
                label = "Descripción",
                singleLine = false,
                minLines = 3,
                error = vm.errors["description"]
            )

            if (isArticle) {
                Text("Fotografías (de 1 a 5)", style = MaterialTheme.typography.titleSmall, fontWeight = FontWeight.SemiBold)
                FilledTonalButton(
                    onClick = {
                        picker.launch(PickVisualMediaRequest(ActivityResultContracts.PickVisualMedia.ImageOnly))
                    }
                ) {
                    Icon(Icons.Default.Add, contentDescription = null)
                    Spacer(Modifier.width(8.dp))
                    Text(if (vm.photos.isEmpty()) "Elegir fotos" else "Cambiar fotos (${vm.photos.size})")
                }
                if (vm.photos.isNotEmpty()) {
                    LazyRow(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                        items(vm.photos) { uri ->
                            AsyncImage(
                                model = uri,
                                contentDescription = "Vista previa",
                                contentScale = ContentScale.Crop,
                                modifier = Modifier
                                    .size(96.dp)
                                    .clip(RoundedCornerShape(12.dp))
                            )
                        }
                    }
                }
                vm.errors["photos"]?.let {
                    Text(it, color = MaterialTheme.colorScheme.error, style = MaterialTheme.typography.bodySmall)
                }
            }

            ChipGroup(
                title = "Categoría",
                options = Categories.all,
                selected = vm.category,
                label = { it },
                onSelect = { vm.category = it },
                error = vm.errors["category"]
            )

            AppTextField(
                value = vm.quantity,
                onValueChange = { vm.quantity = it.filter { c -> c.isDigit() } },
                label = if (isArticle) "Cantidad disponible" else "Cantidad que necesitas",
                keyboardType = KeyboardType.Number,
                maxChars = 4,
                error = vm.errors["quantity"]
            )

            ChipGroup(
                title = if (isArticle) "Estado del artículo" else "Estado aceptable (opcional)",
                options = ItemCondition.entries,
                selected = vm.condition,
                label = { it.label },
                onSelect = vm::selectCondition,
                error = vm.errors["condition"]
            )

            if (!isArticle) {
                ChipGroup(
                    title = "Urgencia",
                    options = Urgency.entries,
                    selected = vm.urgency,
                    label = { it.label },
                    onSelect = { vm.urgency = it },
                    error = vm.errors["urgency"]
                )
                AppTextField(
                    value = vm.features,
                    onValueChange = { vm.features = it },
                    label = "Características necesarias",
                    singleLine = false,
                    minLines = 2,
                    hint = "Por ejemplo: talla, medidas o color.",
                    error = vm.errors["features"]
                )
            }

            AppTextField(
                value = vm.location,
                onValueChange = { vm.location = it },
                label = "Colonia o código postal",
                hint = "Nunca escribas tu domicilio exacto.",
                error = vm.errors["location"]
            )

            vm.error?.let {
                Text(it, color = MaterialTheme.colorScheme.error, fontWeight = FontWeight.SemiBold)
            }

            Button(
                onClick = {
                    vm.publish {
                        Toast.makeText(context, "Publicación creada", Toast.LENGTH_SHORT).show()
                        onBack()
                    }
                },
                enabled = !vm.busy,
                modifier = Modifier.fillMaxWidth()
            ) {
                Text(if (vm.busy) "Publicando…" else "Publicar")
            }
        }
    }
}
