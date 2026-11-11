package com.donation.app.data

/** Reglas de validación de RF-01 y RF-11. Cada función devuelve el mensaje de error o null si es válido. */
object Validators {
    const val MAX_MESSAGE = 300

    private val USERNAME = Regex("^[A-Za-z0-9_.]{3,20}$")
    private val EMAIL = Regex("^[A-Za-z0-9._%+\\-]+@[A-Za-z0-9.\\-]+\\.[A-Za-z]{2,}$")
    private val PHONE = Regex("^\\d{10}$")

    fun username(v: String): String? =
        if (USERNAME.matches(v.trim())) null
        else "Usa de 3 a 20 caracteres: letras, números, punto o guion bajo."

    fun legalName(v: String): String? {
        val words = v.trim().split(Regex("\\s+")).filter { it.isNotEmpty() }
        return if (words.size >= 2) null else "Escribe tu nombre legal completo, con nombre y apellido."
    }

    fun email(v: String): String? =
        if (EMAIL.matches(v.trim())) null else "Escribe un correo electrónico válido."

    fun phone(v: String): String? =
        if (PHONE.matches(v.trim())) null else "El teléfono debe tener exactamente 10 dígitos."

    fun password(v: String): String? =
        if (v.length >= 8 && v.any { it.isUpperCase() } && v.any { it.isLowerCase() } && v.any { it.isDigit() }) null
        else "Mínimo 8 caracteres, con una mayúscula, una minúscula y un número."

    fun requestMessage(v: String): String? =
        if (v.length <= MAX_MESSAGE) null else "El mensaje no puede pasar de $MAX_MESSAGE caracteres."
}
