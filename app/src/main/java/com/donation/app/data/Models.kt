package com.donation.app.data

import androidx.room.Entity
import androidx.room.Index
import androidx.room.PrimaryKey

// ---------------------------------------------------------------------------
// Enumeraciones (tomadas del diagrama de clases del dominio)
// ---------------------------------------------------------------------------

enum class PostType(val label: String) {
    ARTICULO("Artículo"),
    NECESIDAD("Necesidad")
}

enum class PostStatus(val label: String) {
    ACTIVA("Activa"),
    RESERVADA("Reservada"),
    CERRADA("Cerrada"),
    RETIRADA("Retirada")
}

enum class ItemCondition(val label: String) {
    NUEVO("Nuevo"),
    COMO_NUEVO("Como nuevo"),
    USADO("Usado")
}

enum class Urgency(val label: String) {
    ALTA("Alta"),
    MEDIA("Media"),
    BAJA("Baja")
}

enum class RequestStatus { PENDIENTE, ACEPTADA, RECHAZADA, RETIRADA }

/**
 * Estados de la Donación en el MVP. El estado EN_ENTREGA (CU-32, lugar y fecha)
 * queda para una iteración posterior: aquí se pasa de ACEPTADA directo a ENTREGADA.
 */
enum class DonationStatus(val label: String) {
    ACEPTADA("Aceptada"),
    ENTREGADA("Entregada"),
    FINALIZADA("Finalizada"),
    CANCELADA("Cancelada")
}

/** Categorías fijas del MVP (la administración de categorías, CU-48 a CU-51, queda fuera). */
object Categories {
    val all = listOf(
        "Ropa y calzado",
        "Cobijas y hogar",
        "Alimentos",
        "Muebles",
        "Electrodomésticos",
        "Útiles escolares",
        "Juguetes",
        "Otros"
    )
}

// ---------------------------------------------------------------------------
// Entidades de Room
// ---------------------------------------------------------------------------

@Entity(
    tableName = "users",
    indices = [Index(value = ["username"], unique = true), Index(value = ["email"], unique = true)]
)
data class UserEntity(
    @PrimaryKey(autoGenerate = true) val id: Long = 0,
    val username: String,
    val legalName: String,
    val email: String,
    val phone: String,
    val passwordHash: String,
    val salt: String,
    val phoneShared: Boolean = false,
    val createdAt: Long
)

/** Una Publicación: Artículo (la ofrece un donante) o Necesidad (la pide un donatario). */
@Entity(tableName = "posts", indices = [Index("authorId"), Index("status")])
data class PostEntity(
    @PrimaryKey(autoGenerate = true) val id: Long = 0,
    val type: PostType,
    val title: String,
    val description: String,
    val category: String,
    /** Cantidad disponible (Artículo) o requerida (Necesidad). */
    val quantity: Int,
    /** Estado del artículo, o estado aceptable en una Necesidad (opcional). */
    val condition: ItemCondition?,
    /** Solo para Necesidades. */
    val urgency: Urgency?,
    /** Características necesarias (talla, etc.). Solo para Necesidades. */
    val features: String,
    /** Colonia o código postal. Nunca el domicilio exacto (RNF-09). */
    val location: String,
    /** Rutas de las fotos en el almacenamiento interno, separadas por salto de línea. */
    val photoPaths: String,
    val authorId: Long,
    val status: PostStatus,
    val createdAt: Long
)

fun PostEntity.photos(): List<String> =
    if (photoPaths.isBlank()) emptyList() else photoPaths.split("\n")

/** Solicitud de un donatario sobre un Artículo (CU-23). */
@Entity(
    tableName = "requests",
    indices = [Index("postId"), Index("requesterId"), Index(value = ["clientKey"], unique = true)]
)
data class RequestEntity(
    @PrimaryKey(autoGenerate = true) val id: Long = 0,
    val postId: Long,
    val requesterId: Long,
    val message: String,
    val status: RequestStatus,
    /** Clave generada por la pantalla; evita duplicados por doble toque (RNF-11). */
    val clientKey: String,
    val createdAt: Long
)

@Entity(
    tableName = "donations",
    indices = [Index(value = ["requestId"], unique = true), Index("donorId"), Index("doneeId")]
)
data class DonationEntity(
    @PrimaryKey(autoGenerate = true) val id: Long = 0,
    val postId: Long,
    val requestId: Long,
    val donorId: Long,
    val doneeId: Long,
    val status: DonationStatus,
    val deliveredAt: Long?,
    val finalizedAt: Long?,
    val cancelReason: String?,
    val createdAt: Long
)

/** Historial de cambios de estado (RF-12, RNF-15). actorId nulo = Sistema. */
@Entity(tableName = "status_changes", indices = [Index("donationId")])
data class StatusChangeEntity(
    @PrimaryKey(autoGenerate = true) val id: Long = 0,
    val donationId: Long,
    val fromStatus: DonationStatus?,
    val toStatus: DonationStatus,
    val actorId: Long?,
    val timestamp: Long
)

// ---------------------------------------------------------------------------
// Resultados de consultas con JOIN (no son tablas)
// ---------------------------------------------------------------------------

data class RequestWithUser(
    val id: Long,
    val postId: Long,
    val requesterId: Long,
    val message: String,
    val status: RequestStatus,
    val createdAt: Long,
    val requesterUsername: String
)

data class ChangeWithActor(
    val id: Long,
    val toStatus: DonationStatus,
    val timestamp: Long,
    val actorUsername: String?
)

/** Donación con los datos de las dos partes, lista para mostrarse. */
data class DonationView(
    val id: Long,
    val postId: Long,
    val status: DonationStatus,
    val createdAt: Long,
    val deliveredAt: Long?,
    val finalizedAt: Long?,
    val cancelReason: String?,
    val postTitle: String,
    val donorId: Long,
    val donorUsername: String,
    val donorEmail: String,
    val donorPhone: String,
    val donorPhoneShared: Boolean,
    val doneeId: Long,
    val doneeUsername: String,
    val doneeEmail: String,
    val doneePhone: String,
    val doneePhoneShared: Boolean
)
