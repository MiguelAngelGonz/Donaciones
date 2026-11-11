package com.donation.app.ui.auth

import android.app.Application
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateMapOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import androidx.lifecycle.AndroidViewModel
import androidx.lifecycle.viewModelScope
import com.donation.app.container
import com.donation.app.data.DomainError
import com.donation.app.data.Validators
import kotlinx.coroutines.launch

/** CU-07 · Iniciar sesión. */
class LoginViewModel(app: Application) : AndroidViewModel(app) {
    var login by mutableStateOf("")
    var password by mutableStateOf("")

    var loading by mutableStateOf(false)
        private set
    var error by mutableStateOf<String?>(null)
        private set

    fun submit() {
        if (loading) return
        if (login.isBlank() || password.isBlank()) {
            error = "Ingresa tu usuario o correo y tu contraseña."
            return
        }
        loading = true
        error = null
        viewModelScope.launch {
            container.repository.login(login, password)
                .onSuccess { userId -> container.session.open(userId) }
                .onFailure { e -> error = e.message }
            loading = false
        }
    }
}

/** CU-01 · Registrarse, en 3 pasos como máximo (RNF-01). */
class RegisterViewModel(app: Application) : AndroidViewModel(app) {
    var step by mutableIntStateOf(1)
        private set

    var username by mutableStateOf("")
    var legalName by mutableStateOf("")
    var email by mutableStateOf("")
    var phone by mutableStateOf("")
    var password by mutableStateOf("")
    var privacy by mutableStateOf(false)

    val errors = mutableStateMapOf<String, String>()

    var loading by mutableStateOf(false)
        private set
    var error by mutableStateOf<String?>(null)
        private set

    private fun validateStep(s: Int): Boolean {
        errors.clear()
        when (s) {
            1 -> {
                Validators.username(username)?.let { errors["username"] = it }
                Validators.legalName(legalName)?.let { errors["legalName"] = it }
            }
            2 -> {
                Validators.email(email)?.let { errors["email"] = it }
                Validators.phone(phone)?.let { errors["phone"] = it }
            }
            3 -> {
                Validators.password(password)?.let { errors["password"] = it }
                if (!privacy) errors["privacy"] = "Debes aceptar el aviso de privacidad."
            }
        }
        return errors.isEmpty()
    }

    fun next() {
        if (validateStep(step) && step < 3) step++
    }

    fun back() {
        errors.clear()
        if (step > 1) step--
    }

    fun submit() {
        if (loading) return
        if (!validateStep(3)) return
        loading = true
        error = null
        viewModelScope.launch {
            container.repository.register(username, legalName, email, phone, password)
                .onSuccess { userId -> container.session.open(userId) }
                .onFailure { e ->
                    val message = e.message.orEmpty()
                    when ((e as? DomainError)?.field) {
                        "username" -> {
                            step = 1
                            errors["username"] = message
                        }
                        "email" -> {
                            step = 2
                            errors["email"] = message
                        }
                        else -> error = message
                    }
                }
            loading = false
        }
    }
}
