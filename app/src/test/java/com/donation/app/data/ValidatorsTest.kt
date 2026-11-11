package com.donation.app.data

import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Test

class ValidatorsTest {

    @Test
    fun password_requires_8_chars_upper_lower_and_digit() {
        assertNull(Validators.password("Abcdefg1"))
        assertNotNull(Validators.password("abcdefg1"))   // sin mayúscula
        assertNotNull(Validators.password("ABCDEFG1"))   // sin minúscula
        assertNotNull(Validators.password("Abcdefgh"))   // sin número
        assertNotNull(Validators.password("Abc1"))       // muy corta
    }

    @Test
    fun phone_must_have_exactly_10_digits() {
        assertNull(Validators.phone("2221234567"))
        assertNotNull(Validators.phone("222123456"))
        assertNotNull(Validators.phone("22212345678"))
        assertNotNull(Validators.phone("22212345ab"))
    }

    @Test
    fun username_allows_letters_digits_dot_and_underscore() {
        assertNull(Validators.username("angel_09"))
        assertNotNull(Validators.username("ab"))
        assertNotNull(Validators.username("con espacio"))
    }

    @Test
    fun legal_name_needs_at_least_two_words() {
        assertNull(Validators.legalName("Ángel Martínez Hernández"))
        assertNotNull(Validators.legalName("Ángel"))
    }

    @Test
    fun email_must_look_valid() {
        assertNull(Validators.email("angel@correo.com"))
        assertNotNull(Validators.email("angel@correo"))
        assertNotNull(Validators.email("sin-arroba.com"))
    }

    @Test
    fun request_message_is_limited_to_300_characters() {
        assertNull(Validators.requestMessage("a".repeat(300)))
        assertNotNull(Validators.requestMessage("a".repeat(301)))
    }
}
