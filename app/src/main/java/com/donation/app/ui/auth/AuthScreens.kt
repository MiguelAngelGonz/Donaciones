package com.donation.app.ui.auth

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.Button
import androidx.compose.material3.Checkbox
import androidx.compose.material3.FilledTonalButton
import androidx.compose.material3.LinearProgressIndicator
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.unit.dp
import androidx.compose.runtime.Composable
import androidx.lifecycle.viewmodel.compose.viewModel
import com.donation.app.ui.components.AppTextField

/** CU-07 · Iniciar sesión. */
@Composable
fun LoginScreen(onGoRegister: () -> Unit, vm: LoginViewModel = viewModel()) {
    Column(
        modifier = Modifier
            .fillMaxSize()
            .verticalScroll(rememberScrollState())
            .padding(24.dp),
        verticalArrangement = Arrangement.spacedBy(12.dp, Alignment.CenterVertically),
        horizontalAlignment = Alignment.CenterHorizontally
    ) {
        Text("Donation", style = MaterialTheme.typography.displaySmall, fontWeight = FontWeight.Bold)
        Text("Dona, recibe y confirma la entrega.", style = MaterialTheme.typography.bodyLarge)
        Spacer(Modifier.height(12.dp))

        AppTextField(
            value = vm.login,
            onValueChange = { vm.login = it },
            label = "Usuario o correo electrónico",
            keyboardType = KeyboardType.Email
        )
        AppTextField(
            value = vm.password,
            onValueChange = { vm.password = it },
            label = "Contraseña",
            password = true
        )
        vm.error?.let {
            Text(it, color = MaterialTheme.colorScheme.error, fontWeight = FontWeight.SemiBold)
        }
        Button(
            onClick = vm::submit,
            enabled = !vm.loading,
            modifier = Modifier.fillMaxWidth()
        ) {
            Text(if (vm.loading) "Entrando…" else "Iniciar sesión")
        }
        FilledTonalButton(onClick = onGoRegister, modifier = Modifier.fillMaxWidth()) {
            Text("Crear cuenta")
        }
    }
}

/** CU-01 · Registrarse en 3 pasos. */
@Composable
fun RegisterScreen(onBack: () -> Unit, vm: RegisterViewModel = viewModel()) {
    Column(
        modifier = Modifier
            .fillMaxSize()
            .verticalScroll(rememberScrollState())
            .padding(24.dp),
        verticalArrangement = Arrangement.spacedBy(12.dp)
    ) {
        Text("Crear cuenta", style = MaterialTheme.typography.headlineMedium, fontWeight = FontWeight.Bold)
        Text("Paso ${vm.step} de 3", style = MaterialTheme.typography.labelLarge)
        LinearProgressIndicator(
            progress = { vm.step / 3f },
            modifier = Modifier.fillMaxWidth(),
            trackColor = MaterialTheme.colorScheme.surface
        )
        Spacer(Modifier.height(4.dp))

        when (vm.step) {
            1 -> {
                AppTextField(
                    value = vm.username,
                    onValueChange = { vm.username = it },
                    label = "Nombre de usuario",
                    error = vm.errors["username"],
                    hint = "Será único y no se podrá cambiar."
                )
                AppTextField(
                    value = vm.legalName,
                    onValueChange = { vm.legalName = it },
                    label = "Nombre legal completo",
                    error = vm.errors["legalName"],
                    hint = "Como aparece en tu acta de nacimiento."
                )
            }
            2 -> {
                AppTextField(
                    value = vm.email,
                    onValueChange = { vm.email = it },
                    label = "Correo electrónico",
                    keyboardType = KeyboardType.Email,
                    error = vm.errors["email"]
                )
                AppTextField(
                    value = vm.phone,
                    onValueChange = { vm.phone = it.filter { c -> c.isDigit() } },
                    label = "Teléfono (10 dígitos)",
                    keyboardType = KeyboardType.Phone,
                    maxChars = 10,
                    error = vm.errors["phone"],
                    hint = "No se muestra a nadie salvo que tú decidas compartirlo."
                )
            }
            else -> {
                AppTextField(
                    value = vm.password,
                    onValueChange = { vm.password = it },
                    label = "Contraseña",
                    password = true,
                    error = vm.errors["password"],
                    hint = "Mínimo 8 caracteres, con mayúscula, minúscula y número."
                )
                Row(verticalAlignment = Alignment.CenterVertically) {
                    Checkbox(checked = vm.privacy, onCheckedChange = { vm.privacy = it })
                    Text("Acepto el aviso de privacidad", fontWeight = FontWeight.SemiBold)
                }
                Text(
                    "Tus datos personales solo se usan para coordinar donaciones. " +
                        "Tu domicilio exacto nunca se guarda.",
                    style = MaterialTheme.typography.bodySmall
                )
                vm.errors["privacy"]?.let {
                    Text(it, color = MaterialTheme.colorScheme.error, style = MaterialTheme.typography.bodySmall)
                }
            }
        }

        vm.error?.let {
            Text(it, color = MaterialTheme.colorScheme.error, fontWeight = FontWeight.SemiBold)
        }

        Row(horizontalArrangement = Arrangement.spacedBy(12.dp), modifier = Modifier.fillMaxWidth()) {
            FilledTonalButton(
                onClick = { if (vm.step == 1) onBack() else vm.back() },
                enabled = !vm.loading,
                modifier = Modifier.weight(1f)
            ) {
                Text(if (vm.step == 1) "Volver" else "Atrás")
            }
            Button(
                onClick = { if (vm.step < 3) vm.next() else vm.submit() },
                enabled = !vm.loading,
                modifier = Modifier.weight(1f)
            ) {
                Text(
                    when {
                        vm.step < 3 -> "Siguiente"
                        vm.loading -> "Creando…"
                        else -> "Crear cuenta"
                    }
                )
            }
        }
    }
}
