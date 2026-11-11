package com.donation.app.data

import androidx.room.Dao
import androidx.room.Insert
import androidx.room.OnConflictStrategy
import androidx.room.Query
import androidx.room.Update
import kotlinx.coroutines.flow.Flow

internal const val DONATION_VIEW_SELECT = """
    SELECT d.id AS id, d.postId AS postId, d.status AS status, d.createdAt AS createdAt,
           d.deliveredAt AS deliveredAt, d.finalizedAt AS finalizedAt, d.cancelReason AS cancelReason,
           p.title AS postTitle,
           d.donorId AS donorId, du.username AS donorUsername, du.email AS donorEmail,
           du.phone AS donorPhone, du.phoneShared AS donorPhoneShared,
           d.doneeId AS doneeId, eu.username AS doneeUsername, eu.email AS doneeEmail,
           eu.phone AS doneePhone, eu.phoneShared AS doneePhoneShared
    FROM donations d
    JOIN posts p ON p.id = d.postId
    JOIN users du ON du.id = d.donorId
    JOIN users eu ON eu.id = d.doneeId
"""

@Dao
interface AppDao {

    // ----- Usuarios (CU-01, CU-07) -----

    @Insert
    suspend fun insertUser(user: UserEntity): Long

    @Query("SELECT * FROM users WHERE username = :username COLLATE NOCASE LIMIT 1")
    suspend fun findByUsername(username: String): UserEntity?

    @Query("SELECT * FROM users WHERE email = :email COLLATE NOCASE LIMIT 1")
    suspend fun findByEmail(email: String): UserEntity?

    @Query("SELECT * FROM users WHERE username = :login COLLATE NOCASE OR email = :login COLLATE NOCASE LIMIT 1")
    suspend fun findByLogin(login: String): UserEntity?

    @Query("SELECT * FROM users WHERE id = :id")
    fun observeUser(id: Long): Flow<UserEntity?>

    @Query("UPDATE users SET phoneShared = :shared WHERE id = :id")
    suspend fun setPhoneShared(id: Long, shared: Boolean)

    // ----- Publicaciones (CU-11, CU-14, CU-19) -----

    @Insert
    suspend fun insertPost(post: PostEntity): Long

    @Query("SELECT * FROM posts WHERE id = :id")
    suspend fun getPost(id: Long): PostEntity?

    @Query("SELECT * FROM posts WHERE id = :id")
    fun observePost(id: Long): Flow<PostEntity?>

    @Query("UPDATE posts SET status = :status WHERE id = :id")
    suspend fun setPostStatus(id: Long, status: PostStatus)

    /** Feed en orden cronológico inverso, con filtros opcionales de tipo y categoría. */
    @Query(
        """
        SELECT * FROM posts
        WHERE status = :status
          AND (:type IS NULL OR type = :type)
          AND (:category IS NULL OR category = :category)
        ORDER BY createdAt DESC
        """
    )
    fun observeFeed(status: PostStatus, type: PostType?, category: String?): Flow<List<PostEntity>>

    // ----- Solicitudes (CU-23, CU-27) -----

    @Insert(onConflict = OnConflictStrategy.IGNORE)
    suspend fun insertRequest(request: RequestEntity): Long

    @Query("SELECT * FROM requests WHERE id = :id")
    suspend fun getRequest(id: Long): RequestEntity?

    @Query("SELECT * FROM requests WHERE clientKey = :clientKey LIMIT 1")
    suspend fun findRequestByClientKey(clientKey: String): RequestEntity?

    @Query("SELECT * FROM requests WHERE postId = :postId AND requesterId = :userId AND status = :status LIMIT 1")
    suspend fun findRequestByUser(postId: Long, userId: Long, status: RequestStatus): RequestEntity?

    @Query("SELECT * FROM requests WHERE postId = :postId AND requesterId = :userId AND status = :status LIMIT 1")
    fun observeUserRequest(postId: Long, userId: Long, status: RequestStatus): Flow<RequestEntity?>

    @Query(
        """
        SELECT r.id AS id, r.postId AS postId, r.requesterId AS requesterId, r.message AS message,
               r.status AS status, r.createdAt AS createdAt, u.username AS requesterUsername
        FROM requests r
        JOIN users u ON u.id = r.requesterId
        WHERE r.postId = :postId AND r.status = :status
        ORDER BY r.createdAt ASC
        """
    )
    fun observePendingRequests(postId: Long, status: RequestStatus): Flow<List<RequestWithUser>>

    @Query("UPDATE requests SET status = :status WHERE id = :id")
    suspend fun setRequestStatus(id: Long, status: RequestStatus)

    @Query("UPDATE requests SET status = :newStatus WHERE postId = :postId AND id != :exceptId AND status = :oldStatus")
    suspend fun rejectOtherPending(postId: Long, exceptId: Long, oldStatus: RequestStatus, newStatus: RequestStatus)

    // ----- Donaciones (CU-27, CU-28, CU-33, CU-34) -----

    @Insert
    suspend fun insertDonation(donation: DonationEntity): Long

    @Update
    suspend fun updateDonation(donation: DonationEntity)

    @Query("SELECT * FROM donations WHERE id = :id")
    suspend fun getDonation(id: Long): DonationEntity?

    @Query("SELECT * FROM donations WHERE requestId = :requestId LIMIT 1")
    suspend fun getDonationByRequest(requestId: Long): DonationEntity?

    @Query("SELECT * FROM donations WHERE status = :status AND deliveredAt IS NOT NULL AND deliveredAt <= :cutoff")
    suspend fun findDeliveredBefore(status: DonationStatus, cutoff: Long): List<DonationEntity>

    @Query("$DONATION_VIEW_SELECT WHERE d.id = :id")
    fun observeDonationView(id: Long): Flow<DonationView?>

    @Query("$DONATION_VIEW_SELECT WHERE d.donorId = :userId OR d.doneeId = :userId ORDER BY d.createdAt DESC")
    fun observeDonationViews(userId: Long): Flow<List<DonationView>>

    @Insert
    suspend fun insertChange(change: StatusChangeEntity): Long

    @Query(
        """
        SELECT c.id AS id, c.toStatus AS toStatus, c.timestamp AS timestamp, u.username AS actorUsername
        FROM status_changes c
        LEFT JOIN users u ON u.id = c.actorId
        WHERE c.donationId = :donationId
        ORDER BY c.timestamp ASC, c.id ASC
        """
    )
    fun observeChanges(donationId: Long): Flow<List<ChangeWithActor>>

    // ----- Métricas del piloto -----

    @Query("SELECT COUNT(*) FROM posts")
    fun observePostCount(): Flow<Int>

    @Query("SELECT COUNT(*) FROM requests")
    fun observeRequestCount(): Flow<Int>

    @Query("SELECT COUNT(*) FROM donations")
    fun observeDonationCount(): Flow<Int>

    @Query("SELECT COUNT(*) FROM donations WHERE status = :status")
    fun observeDonationCountByStatus(status: DonationStatus): Flow<Int>
}
