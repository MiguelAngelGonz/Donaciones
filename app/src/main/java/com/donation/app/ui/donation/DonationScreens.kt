package com.donation.app.ui.donation

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Check
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.FilledTonalButton
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.lifecycle.viewmodel.compose.viewModel
import com.donation.app.data.ChangeWithActor
import com.donation.app.data.DonationStatus
import com.donation.app.data.DonationView
import com.donation.app.ui.components.AppTextField
import com.donation.app.ui.components.AppTopBar
import com.donation.app.ui.components.DonationStatusChip
import com.donation.app.ui.components.EmptyState
import com.donation.app.ui.components.InfoRow
import com.donation.app.ui.components.LabelChip
import com.donation.app.ui.components.LoadingBox
import com.donation.app.ui.components.SurfaceCard
import com.donation.app.ui.components.formatDate
import com.donation.app.ui.theme.ErrorRojo
import com.donation.app.ui.theme.SuperficieSuave
import com.donation.app.ui.theme.TextoPrincipal

/** Pestaña "Donaciones": las donaciones donde el usuario es donante o donatario. */
@Composable
fun DonationsScreen(onOpen: (Long) -> Unit, vm: DonationsListViewModel = viewModel()) {
    val donations by vm.donations.collectAsStateWithLifecycle()

    Column(Modifier.fillMaxSize()) {
        Text(
            "Mis donaciones",
            style = MaterialTheme.typography.headlineSmall,
            fontWeight = FontWeight.Bold,
            modifier = Modifier.padding(start = 16.dp, top = 16.dp, end = 16.dp, bottom = 8.dp)
        )
        val list = donations
        when {
            list == null -> LoadingBox()
            list.isEmpty() -> EmptyState(
                "Aún no tienes donaciones. Solicita un artículo o acepta una solicitud para comenzar."
            )
            else -> LazyColumn(
                contentPadding = PaddingValues(16.dp),
                verticalArrangement = Arrangement.spacedBy(12.dp)
            ) {
                items(list, key = { it.id }) { donation ->
                    DonationCard(donation, vm.userId, onClick = { onOpen(donation.id) })
                }
            }
        }
    }
}

@Composable
private fun DonationCard(d: DonationView, userId: Long, onClick: () -> Unit) {
    val iAmDonor = d.donorId == userId
    Card(
        onClick = onClick,
        modifier = Modifier.fillMaxWidth(),
        colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surface)
    ) {
        Column(Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(6.dp)) {
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically
            ) {
                Text(
                    d.postTitle,
                    style = MaterialTheme.typography.titleMedium,
                    fontWeight = FontWeight.Bold,
                    modifier = Modifier.weight(1f)
                )
                DonationStatusChip(d.status)
            }
            Text(
                if (iAmDonor) "Eres el donante · para @${d.doneeUsername}"
                else "Eres el donatario · de @${d.donorUsername}",
                style = MaterialTheme.typography.bodyMedium
            )
            Text(formatDate(d.createdAt), style = MaterialTheme.typography.bodySmall)
        }
    }
}

/** CU-30 Coordinar entrega, CU-33 Marcar como Entregada, CU-34 Confirmar recepción, CU-36 Cancelar. */
@Composable
fun DonationDetailScreen(onBack: () -> Unit, vm: DonationDetailViewModel = viewModel()) {
    val donation by vm.donation.collectAsStateWithLifecycle()
    val changes by vm.changes.collectAsStateWithLifecycle()

    Scaffold(topBar = { AppTopBar("Donación", onBack) }) { padding ->
        val d = donation
        if (d == null) {
            LoadingBox(Modifier.padding(padding))
        } else {
            DonationContent(d, changes, vm, Modifier.padding(padding))
        }
    }

    if (vm.showCancelDialog) {
        AlertDialog(
            onDismissRequest = { if (!vm.busy) vm.dismissCancel() },
            title = { Text("Cancelar donación") },
            text = {
                Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                    Text("La publicación volverá a estar activa para otras personas.")
                    AppTextField(
                        value = vm.cancelReason,
                        onValueChange = { vm.cancelReason = it },
                        label = "Motivo de la cancelación",
                        singleLine = false,
                        minLines = 2,
                        maxChars = 200
                    )
                    vm.error?.let {
                        Text(it, color = MaterialTheme.colorScheme.error, fontWeight = FontWeight.SemiBold)
                    }
                }
            },
            confirmButton = {
                Button(
                    onClick = vm::cancel,
                    enabled = !vm.busy && vm.cancelReason.isNotBlank(),
                    colors = ButtonDefaults.buttonColors(containerColor = ErrorRojo)
                ) {
                    Text("Cancelar donación")
                }
            },
            dismissButton = {
                TextButton(onClick = vm::dismissCancel, enabled = !vm.busy) { Text("Volver") }
            }
        )
    }
}

@Composable
private fun DonationContent(
    d: DonationView,
    changes: List<ChangeWithActor>,
    vm: DonationDetailViewModel,
    modifier: Modifier
) {
    val iAmDonor = d.donorId == vm.userId
    val otherName = if (iAmDonor) d.doneeUsername else d.donorUsername
    val otherEmail = if (iAmDonor) d.doneeEmail else d.donorEmail
    val otherPhone = if (iAmDonor) d.doneePhone else d.donorPhone
    val otherSharesPhone = if (iAmDonor) d.doneePhoneShared else d.donorPhoneShared

    val hint: String? = when (d.status) {
        DonationStatus.ACEPTADA ->
            if (iAmDonor) "Acuerda la entrega con la otra parte y márcala como entregada cuando ocurra."
            else "Acuerda la entrega con el donante. Él marcará el artículo como entregado."
        DonationStatus.ENTREGADA ->
            if (iAmDonor) "Esperando la confirmación de recepción. Se finaliza sola a los 7 días."
            else "Confirma que recibiste el artículo. Si no lo haces, se finalizará sola a los 7 días."
        DonationStatus.FINALIZADA -> "Donación finalizada. Gracias por darle una segunda vida a este objeto."
        DonationStatus.CANCELADA -> null
    }

    Column(
        modifier = modifier
            .verticalScroll(rememberScrollState())
            .padding(16.dp),
        verticalArrangement = Arrangement.spacedBy(12.dp)
    ) {
        Text(d.postTitle, style = MaterialTheme.typography.headlineSmall, fontWeight = FontWeight.Bold)
        Row(horizontalArrangement = Arrangement.spacedBy(6.dp)) {
            DonationStatusChip(d.status)
            LabelChip(if (iAmDonor) "Eres el donante" else "Eres el donatario", SuperficieSuave, TextoPrincipal)
        }

        if (d.status == DonationStatus.CANCELADA) {
            SurfaceCard {
                Text("Donación cancelada", color = ErrorRojo, fontWeight = FontWeight.Bold)
                Text("Motivo: ${d.cancelReason.orEmpty()}")
            }
        } else {
            SurfaceCard { Timeline(d.status) }
        }

        // Sin chat en el MVP: tras aceptar, las partes ven el contacto de la otra para coordinar.
        if (d.status == DonationStatus.ACEPTADA || d.status == DonationStatus.ENTREGADA) {
            SurfaceCard {
                Text("Contacto de la otra parte", style = MaterialTheme.typography.titleMedium, fontWeight = FontWeight.Bold)
                InfoRow("Usuario", "@$otherName")
                InfoRow("Correo", otherEmail)
                InfoRow("Teléfono", if (otherSharesPhone) otherPhone else "No compartido")
                Text("Usa estos datos para acordar lugar y fecha de entrega.", style = MaterialTheme.typography.bodySmall)
            }
        }

        hint?.let { Text(it, style = MaterialTheme.typography.bodyMedium) }

        if (iAmDonor && d.status == DonationStatus.ACEPTADA) {
            Button(onClick = vm::markDelivered, enabled = !vm.busy, modifier = Modifier.fillMaxWidth()) {
                Text("Marcar como entregada")
            }
        }
        if (!iAmDonor && d.status == DonationStatus.ENTREGADA) {
            Button(onClick = vm::confirmReception, enabled = !vm.busy, modifier = Modifier.fillMaxWidth()) {
                Text("Confirmar recepción")
            }
        }
        if (d.status == DonationStatus.ACEPTADA) {
            FilledTonalButton(
                onClick = vm::openCancel,
                enabled = !vm.busy,
                colors = ButtonDefaults.filledTonalButtonColors(contentColor = ErrorRojo),
                modifier = Modifier.fillMaxWidth()
            ) {
                Text("Cancelar donación")
            }
        }

        if (!vm.showCancelDialog) {
            vm.error?.let {
                Text(it, color = MaterialTheme.colorScheme.error, fontWeight = FontWeight.SemiBold)
            }
        }

        SurfaceCard {
            Text("Historial de cambios", style = MaterialTheme.typography.titleMedium, fontWeight = FontWeight.Bold)
            changes.forEach { change ->
                val actor = change.actorUsername?.let { "@$it" } ?: "Sistema"
                Text(
                    "${change.toStatus.label} · $actor · ${formatDate(change.timestamp)}",
                    style = MaterialTheme.typography.bodySmall
                )
            }
        }
    }
}

/** Línea de tiempo Aceptada → Entregada → Finalizada. */
@Composable
private fun Timeline(status: DonationStatus) {
    val steps = listOf(DonationStatus.ACEPTADA, DonationStatus.ENTREGADA, DonationStatus.FINALIZADA)
    val reached = steps.indexOf(status)
    Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceEvenly) {
        steps.forEachIndexed { index, step ->
            val done = index <= reached
            Column(horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(4.dp)) {
                Box(
                    modifier = Modifier
                        .size(28.dp)
                        .background(
                            if (done) MaterialTheme.colorScheme.primary else MaterialTheme.colorScheme.surfaceVariant,
                            CircleShape
                        ),
                    contentAlignment = Alignment.Center
                ) {
                    if (done) {
                        Icon(
                            Icons.Default.Check,
                            contentDescription = null,
                            tint = MaterialTheme.colorScheme.onPrimary,
                            modifier = Modifier.size(18.dp)
                        )
                    }
                }
                Text(
                    step.label,
                    style = MaterialTheme.typography.labelMedium,
                    fontWeight = if (index == reached) FontWeight.Bold else FontWeight.Normal
                )
            }
        }
    }
}
