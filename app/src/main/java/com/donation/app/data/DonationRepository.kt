package com.donation.app.data

import android.content.Context
import android.net.Uri
import androidx.room.withTransaction
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.withContext
import java.io.File
import java.util.UUID

/** Error esperado de negocio; su mensaje se muestra tal cual al usuario. */
class DomainError(message: String, val field: String? = null) : Exception(message)

data class PostDraft(
    val type: PostType,
    val title: String,
    val description: String,
    val category: String,
    val quantity: Int,
    val condition: ItemCondition?,
    val urgency: Urgency?,
    val features: String,
    val location: String,
    val photoUris: List<Uri>
)

/**
 * Único punto de acceso a los datos. Las pantallas nunca tocan el DAO.
 * Si más adelante se conecta el backend (FastAPI), solo cambia esta clase.
 */
class DonationRepository(
    private val context: Context,
    private val db: AppDatabase
) {
    private val dao = db.dao()

    // ------------------------------------------------------------------
    // Consultas observables
    // ------------------------------------------------------------------

    fun observeUser(id: Long): Flow<UserEntity?> = dao.observeUser(id)
    fun observePost(id: Long): Flow<PostEntity?> = dao.observePost(id)

    fun observeFeed(type: PostType?, category: String?): Flow<List<PostEntity>> =
        dao.observeFeed(PostStatus.ACTIVA, type, category)

    fun observePendingRequests(postId: Long): Flow<List<RequestWithUser>> =
        dao.observePendingRequests(postId, RequestStatus.PENDIENTE)

    fun observeUserPendingRequest(postId: Long, userId: Long): Flow<RequestEntity?> =
        dao.observeUserRequest(postId, userId, RequestStatus.PENDIENTE)

    fun observeDonationViews(userId: Long): Flow<List<DonationView>> = dao.observeDonationViews(userId)
    fun observeDonationView(id: Long): Flow<DonationView?> = dao.observeDonationView(id)
    fun observeChanges(donationId: Long): Flow<List<ChangeWithActor>> = dao.observeChanges(donationId)

    fun observePostCount(): Flow<Int> = dao.observePostCount()
    fun observeRequestCount(): Flow<Int> = dao.observeRequestCount()
    fun observeDonationCount(): Flow<Int> = dao.observeDonationCount()
    fun observeDonationCountByStatus(status: DonationStatus): Flow<Int> =
        dao.observeDonationCountByStatus(status)

    // ------------------------------------------------------------------
    // CU-01 Registrarse / CU-07 Iniciar sesión
    // ------------------------------------------------------------------

    suspend fun register(
        username: String,
        legalName: String,
        email: String,
        phone: String,
        password: String
    ): Result<Long> = safe {
        val user = username.trim()
        val mail = email.trim().lowercase()
        if (dao.findByUsername(user) != null) {
            throw DomainError("Ese nombre de usuario ya existe.", field = "username")
        }
        if (dao.findByEmail(mail) != null) {
            throw DomainError("Ese correo ya está registrado.", field = "email")
        }
        val salt = PasswordHasher.newSalt()
        val hash = withContext(Dispatchers.Default) { PasswordHasher.hash(password, salt) }
        dao.insertUser(
            UserEntity(
                username = user,
                legalName = legalName.trim(),
                email = mail,
                phone = phone.trim(),
                passwordHash = hash,
                salt = salt,
                createdAt = System.currentTimeMillis()
            )
        )
    }

    suspend fun login(login: String, password: String): Result<Long> = safe {
        // Mensaje genérico: no revela cuál de los dos datos falló (RF-04).
        val invalid = DomainError("Usuario o contraseña incorrectos.")
        val user = dao.findByLogin(login.trim()) ?: throw invalid
        val ok = withContext(Dispatchers.Default) {
            PasswordHasher.verify(password, user.salt, user.passwordHash)
        }
        if (!ok) throw invalid
        user.id
    }

    suspend fun setPhoneShared(userId: Long, shared: Boolean) {
        dao.setPhoneShared(userId, shared)
    }

    // ------------------------------------------------------------------
    // CU-11 Publicar Necesidad / CU-14 Publicar Artículo
    // ------------------------------------------------------------------

    suspend fun publish(authorId: Long, draft: PostDraft): Result<Long> = safe {
        if (draft.type == PostType.ARTICULO && draft.photoUris.size !in 1..MAX_PHOTOS) {
            throw DomainError("Agrega de 1 a $MAX_PHOTOS fotografías.")
        }
        val paths = copyPhotos(draft.photoUris)
        dao.insertPost(
            PostEntity(
                type = draft.type,
                title = draft.title.trim(),
                description = draft.description.trim(),
                category = draft.category,
                quantity = draft.quantity,
                condition = draft.condition,
                urgency = draft.urgency,
                features = draft.features.trim(),
                location = draft.location.trim(),
                photoPaths = paths.joinToString("\n"),
                authorId = authorId,
                status = PostStatus.ACTIVA,
                createdAt = System.currentTimeMillis()
            )
        )
    }

    /** Copia las fotos elegidas al almacenamiento interno para no depender de permisos temporales. */
    private suspend fun copyPhotos(uris: List<Uri>): List<String> = withContext(Dispatchers.IO) {
        val dir = File(context.filesDir, "photos").apply { mkdirs() }
        uris.take(MAX_PHOTOS).map { uri ->
            val target = File(dir, "${UUID.randomUUID()}.jpg")
            val input = context.contentResolver.openInputStream(uri)
                ?: throw DomainError("No se pudo leer una de las fotografías.")
            input.use { source -> target.outputStream().use { out -> source.copyTo(out) } }
            target.absolutePath
        }
    }

    // ------------------------------------------------------------------
    // CU-23 Solicitar artículo
    // ------------------------------------------------------------------

    suspend fun sendRequest(
        postId: Long,
        userId: Long,
        message: String,
        clientKey: String
    ): Result<Unit> = safe {
        Validators.requestMessage(message)?.let { throw DomainError(it) }
        db.withTransaction {
            // Reintento con la misma clave: la solicitud ya existe, no se duplica (RNF-11).
            if (dao.findRequestByClientKey(clientKey) != null) return@withTransaction

            val post = dao.getPost(postId) ?: throw DomainError("La publicación ya no existe.")
            if (post.type != PostType.ARTICULO) throw DomainError("Solo puedes solicitar Artículos.")
            if (post.authorId == userId) throw DomainError("No puedes solicitar tu propio artículo.")
            if (post.status != PostStatus.ACTIVA) throw DomainError("Este artículo ya no está disponible.")
            if (dao.findRequestByUser(postId, userId, RequestStatus.PENDIENTE) != null) {
                throw DomainError("Ya tienes una solicitud pendiente sobre este artículo.")
            }
            dao.insertRequest(
                RequestEntity(
                    postId = postId,
                    requesterId = userId,
                    message = message.trim(),
                    status = RequestStatus.PENDIENTE,
                    clientKey = clientKey,
                    createdAt = System.currentTimeMillis()
                )
            )
            Unit
        }
    }

    // ------------------------------------------------------------------
    // CU-27 Aceptar Solicitud + CU-28 Crear Donación
    // ------------------------------------------------------------------

    /** Devuelve el id de la Donación creada. Es idempotente: aceptar dos veces no crea dos registros. */
    suspend fun acceptRequest(requestId: Long, actorId: Long): Result<Long> = safe {
        db.withTransaction {
            dao.getDonationByRequest(requestId)?.let { return@withTransaction it.id }

            val request = dao.getRequest(requestId) ?: throw DomainError("La solicitud ya no existe.")
            if (request.status != RequestStatus.PENDIENTE) {
                throw DomainError("Esta solicitud ya no está pendiente.")
            }
            val post = dao.getPost(request.postId) ?: throw DomainError("La publicación ya no existe.")
            if (post.authorId != actorId) {
                throw DomainError("Solo el autor de la publicación puede aceptar solicitudes.")
            }
            if (post.status != PostStatus.ACTIVA) throw DomainError("La publicación ya no está activa.")

            val now = System.currentTimeMillis()
            dao.setRequestStatus(request.id, RequestStatus.ACEPTADA)
            dao.rejectOtherPending(post.id, request.id, RequestStatus.PENDIENTE, RequestStatus.RECHAZADA)
            dao.setPostStatus(post.id, PostStatus.RESERVADA)

            val donationId = dao.insertDonation(
                DonationEntity(
                    postId = post.id,
                    requestId = request.id,
                    donorId = post.authorId,
                    doneeId = request.requesterId,
                    status = DonationStatus.ACEPTADA,
                    deliveredAt = null,
                    finalizedAt = null,
                    cancelReason = null,
                    createdAt = now
                )
            )
            dao.insertChange(
                StatusChangeEntity(
                    donationId = donationId,
                    fromStatus = null,
                    toStatus = DonationStatus.ACEPTADA,
                    actorId = actorId,
                    timestamp = now
                )
            )
            donationId
        }
    }

    // ------------------------------------------------------------------
    // CU-33 Marcar como Entregada / CU-34 Confirmar recepción / CU-36 Cancelar
    // ------------------------------------------------------------------

    suspend fun markDelivered(donationId: Long, actorId: Long): Result<Unit> = safe {
        db.withTransaction {
            val donation = dao.getDonation(donationId) ?: throw DomainError("La donación no existe.")
            if (donation.donorId != actorId) {
                throw DomainError("Solo el donante puede marcarla como entregada.")
            }
            when (donation.status) {
                DonationStatus.ENTREGADA -> Unit // doble toque o reintento (RNF-11)
                DonationStatus.ACEPTADA -> {
                    val now = System.currentTimeMillis()
                    transition(donation.copy(deliveredAt = now), DonationStatus.ENTREGADA, actorId, now)
                }
                else -> throw DomainError(
                    "La donación está ${donation.status.label.lowercase()} y no se puede marcar como entregada."
                )
            }
        }
    }

    suspend fun confirmReception(donationId: Long, actorId: Long): Result<Unit> = safe {
        db.withTransaction {
            val donation = dao.getDonation(donationId) ?: throw DomainError("La donación no existe.")
            if (donation.doneeId != actorId) {
                throw DomainError("Solo quien recibe el artículo puede confirmar la recepción.")
            }
            when (donation.status) {
                DonationStatus.FINALIZADA -> Unit // doble toque o reintento (RNF-11)
                DonationStatus.ENTREGADA -> finalizeDonation(donation, actorId, System.currentTimeMillis())
                else -> throw DomainError(
                    "El donante aún no marca el artículo como entregado."
                )
            }
        }
    }

    suspend fun cancelDonation(donationId: Long, actorId: Long, reason: String): Result<Unit> = safe {
        if (reason.isBlank()) throw DomainError("Indica el motivo de la cancelación.")
        db.withTransaction {
            val donation = dao.getDonation(donationId) ?: throw DomainError("La donación no existe.")
            if (actorId != donation.donorId && actorId != donation.doneeId) {
                throw DomainError("Solo las partes de la donación pueden cancelarla.")
            }
            when (donation.status) {
                DonationStatus.CANCELADA -> Unit
                DonationStatus.ACEPTADA -> {
                    val now = System.currentTimeMillis()
                    transition(
                        donation.copy(cancelReason = reason.trim()),
                        DonationStatus.CANCELADA,
                        actorId,
                        now
                    )
                    dao.setPostStatus(donation.postId, PostStatus.ACTIVA)
                }
                else -> throw DomainError(
                    "La donación está ${donation.status.label.lowercase()} y ya no se puede cancelar."
                )
            }
        }
    }

    /**
     * Finaliza a nombre del Sistema las donaciones Entregadas que llevan 7 días sin confirmarse (RF-12).
     * Se llama al abrir las pantallas de donaciones.
     */
    suspend fun autoFinalizeExpired() {
        try {
            val now = System.currentTimeMillis()
            dao.findDeliveredBefore(DonationStatus.ENTREGADA, now - AUTO_FINALIZE_MS).forEach { stale ->
                db.withTransaction {
                    val current = dao.getDonation(stale.id)
                    if (current != null && current.status == DonationStatus.ENTREGADA) {
                        finalizeDonation(current, null, now)
                    }
                    Unit
                }
            }
        } catch (e: CancellationException) {
            throw e
        } catch (e: Exception) {
            // Se reintentará la próxima vez que se abra la pantalla.
        }
    }

    // ------------------------------------------------------------------
    // Utilidades internas
    // ------------------------------------------------------------------

    /** Guarda el nuevo estado y deja constancia en el historial (RF-12, RNF-10, RNF-15). */
    private suspend fun transition(updated: DonationEntity, to: DonationStatus, actorId: Long?, now: Long) {
        dao.updateDonation(updated.copy(status = to))
        dao.insertChange(
            StatusChangeEntity(
                donationId = updated.id,
                fromStatus = updated.status,
                toStatus = to,
                actorId = actorId,
                timestamp = now
            )
        )
    }

    private suspend fun finalizeDonation(donation: DonationEntity, actorId: Long?, now: Long) {
        transition(donation.copy(finalizedAt = now), DonationStatus.FINALIZADA, actorId, now)
        dao.setPostStatus(donation.postId, PostStatus.CERRADA)
    }

    /** Convierte cualquier falla inesperada en un mensaje claro (RNF-12). */
    private suspend fun <T> safe(block: suspend () -> T): Result<T> = try {
        Result.success(block())
    } catch (e: CancellationException) {
        throw e
    } catch (e: DomainError) {
        Result.failure(e)
    } catch (e: Exception) {
        Result.failure(DomainError("No se pudo completar la operación. Inténtalo de nuevo."))
    }

    companion object {
        const val MAX_PHOTOS = 5
        const val AUTO_FINALIZE_MS = 7L * 24 * 60 * 60 * 1000
    }
}
