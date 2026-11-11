package com.donation.app.ui.profile

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.Button
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Switch
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.lifecycle.viewmodel.compose.viewModel
import com.donation.app.ui.components.InfoRow
import com.donation.app.ui.components.SurfaceCard

/** CU-03 Consultar perfil (versión MVP), preferencia de teléfono, métricas del piloto y CU-10 Cerrar sesión. */
@Composable
fun ProfileScreen(vm: ProfileViewModel = viewModel()) {
    val user by vm.user.collectAsStateWithLifecycle()
    val metrics by vm.metrics.collectAsStateWithLifecycle()

    Column(
        modifier = Modifier
            .fillMaxSize()
            .verticalScroll(rememberScrollState())
            .padding(16.dp),
        verticalArrangement = Arrangement.spacedBy(12.dp)
    ) {
        Text("Mi perfil", style = MaterialTheme.typography.headlineSmall, fontWeight = FontWeight.Bold)

        user?.let { u ->
            SurfaceCard {
                Text("@${u.username}", style = MaterialTheme.typography.titleLarge, fontWeight = FontWeight.Bold)
                InfoRow("Nombre", u.legalName)
                InfoRow("Correo", u.email)
                InfoRow("Teléfono", u.phone)
                Row(verticalAlignment = Alignment.CenterVertically) {
                    Column(Modifier.weight(1f)) {
                        Text("Compartir mi teléfono", fontWeight = FontWeight.SemiBold)
                        Text(
                            "Solo lo verá la otra parte de una donación aceptada.",
                            style = MaterialTheme.typography.bodySmall
                        )
                    }
                    Switch(checked = u.phoneShared, onCheckedChange = vm::setPhoneShared)
                }
            }
        }

        SurfaceCard {
            Text("Métricas del piloto", style = MaterialTheme.typography.titleMedium, fontWeight = FontWeight.Bold)
            val m = metrics
            if (m == null) {
                Text("Calculando…")
            } else {
                InfoRow("Publicaciones", m.posts.toString())
                InfoRow("Solicitudes", m.requests.toString())
                InfoRow("Contactos (donaciones aceptadas)", m.accepted.toString())
                InfoRow("Donaciones finalizadas", m.finalized.toString())
                InfoRow("Tasa de confirmación de entrega", m.rate?.let { "$it %" } ?: "—")
                Text(
                    "Tasa = finalizadas ÷ (aceptadas − canceladas).",
                    style = MaterialTheme.typography.bodySmall
                )
            }
        }

        Button(onClick = vm::logout, modifier = Modifier.fillMaxWidth()) {
            Text("Cerrar sesión")
        }
    }
}
