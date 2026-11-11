package com.donation.app.data;

import android.database.Cursor;
import android.os.CancellationSignal;
import androidx.annotation.NonNull;
import androidx.annotation.Nullable;
import androidx.room.CoroutinesRoom;
import androidx.room.EntityDeletionOrUpdateAdapter;
import androidx.room.EntityInsertionAdapter;
import androidx.room.RoomDatabase;
import androidx.room.RoomSQLiteQuery;
import androidx.room.SharedSQLiteStatement;
import androidx.room.util.CursorUtil;
import androidx.room.util.DBUtil;
import androidx.sqlite.db.SupportSQLiteStatement;
import java.lang.Class;
import java.lang.Exception;
import java.lang.IllegalArgumentException;
import java.lang.Integer;
import java.lang.Long;
import java.lang.Object;
import java.lang.Override;
import java.lang.String;
import java.lang.SuppressWarnings;
import java.util.ArrayList;
import java.util.Collections;
import java.util.List;
import java.util.concurrent.Callable;
import javax.annotation.processing.Generated;
import kotlin.Unit;
import kotlin.coroutines.Continuation;
import kotlinx.coroutines.flow.Flow;

@Generated("androidx.room.RoomProcessor")
@SuppressWarnings({"unchecked", "deprecation"})
public final class AppDao_Impl implements AppDao {
  private final RoomDatabase __db;

  private final EntityInsertionAdapter<UserEntity> __insertionAdapterOfUserEntity;

  private final EntityInsertionAdapter<PostEntity> __insertionAdapterOfPostEntity;

  private final EntityInsertionAdapter<RequestEntity> __insertionAdapterOfRequestEntity;

  private final EntityInsertionAdapter<DonationEntity> __insertionAdapterOfDonationEntity;

  private final EntityInsertionAdapter<StatusChangeEntity> __insertionAdapterOfStatusChangeEntity;

  private final EntityDeletionOrUpdateAdapter<DonationEntity> __updateAdapterOfDonationEntity;

  private final SharedSQLiteStatement __preparedStmtOfSetPhoneShared;

  private final SharedSQLiteStatement __preparedStmtOfSetPostStatus;

  private final SharedSQLiteStatement __preparedStmtOfSetRequestStatus;

  private final SharedSQLiteStatement __preparedStmtOfRejectOtherPending;

  public AppDao_Impl(@NonNull final RoomDatabase __db) {
    this.__db = __db;
    this.__insertionAdapterOfUserEntity = new EntityInsertionAdapter<UserEntity>(__db) {
      @Override
      @NonNull
      protected String createQuery() {
        return "INSERT OR ABORT INTO `users` (`id`,`username`,`legalName`,`email`,`phone`,`passwordHash`,`salt`,`phoneShared`,`createdAt`) VALUES (nullif(?, 0),?,?,?,?,?,?,?,?)";
      }

      @Override
      protected void bind(@NonNull final SupportSQLiteStatement statement,
          @NonNull final UserEntity entity) {
        statement.bindLong(1, entity.getId());
        statement.bindString(2, entity.getUsername());
        statement.bindString(3, entity.getLegalName());
        statement.bindString(4, entity.getEmail());
        statement.bindString(5, entity.getPhone());
        statement.bindString(6, entity.getPasswordHash());
        statement.bindString(7, entity.getSalt());
        final int _tmp = entity.getPhoneShared() ? 1 : 0;
        statement.bindLong(8, _tmp);
        statement.bindLong(9, entity.getCreatedAt());
      }
    };
    this.__insertionAdapterOfPostEntity = new EntityInsertionAdapter<PostEntity>(__db) {
      @Override
      @NonNull
      protected String createQuery() {
        return "INSERT OR ABORT INTO `posts` (`id`,`type`,`title`,`description`,`category`,`quantity`,`condition`,`urgency`,`features`,`location`,`photoPaths`,`authorId`,`status`,`createdAt`) VALUES (nullif(?, 0),?,?,?,?,?,?,?,?,?,?,?,?,?)";
      }

      @Override
      protected void bind(@NonNull final SupportSQLiteStatement statement,
          @NonNull final PostEntity entity) {
        statement.bindLong(1, entity.getId());
        statement.bindString(2, __PostType_enumToString(entity.getType()));
        statement.bindString(3, entity.getTitle());
        statement.bindString(4, entity.getDescription());
        statement.bindString(5, entity.getCategory());
        statement.bindLong(6, entity.getQuantity());
        if (entity.getCondition() == null) {
          statement.bindNull(7);
        } else {
          statement.bindString(7, __ItemCondition_enumToString(entity.getCondition()));
        }
        if (entity.getUrgency() == null) {
          statement.bindNull(8);
        } else {
          statement.bindString(8, __Urgency_enumToString(entity.getUrgency()));
        }
        statement.bindString(9, entity.getFeatures());
        statement.bindString(10, entity.getLocation());
        statement.bindString(11, entity.getPhotoPaths());
        statement.bindLong(12, entity.getAuthorId());
        statement.bindString(13, __PostStatus_enumToString(entity.getStatus()));
        statement.bindLong(14, entity.getCreatedAt());
      }
    };
    this.__insertionAdapterOfRequestEntity = new EntityInsertionAdapter<RequestEntity>(__db) {
      @Override
      @NonNull
      protected String createQuery() {
        return "INSERT OR IGNORE INTO `requests` (`id`,`postId`,`requesterId`,`message`,`status`,`clientKey`,`createdAt`) VALUES (nullif(?, 0),?,?,?,?,?,?)";
      }

      @Override
      protected void bind(@NonNull final SupportSQLiteStatement statement,
          @NonNull final RequestEntity entity) {
        statement.bindLong(1, entity.getId());
        statement.bindLong(2, entity.getPostId());
        statement.bindLong(3, entity.getRequesterId());
        statement.bindString(4, entity.getMessage());
        statement.bindString(5, __RequestStatus_enumToString(entity.getStatus()));
        statement.bindString(6, entity.getClientKey());
        statement.bindLong(7, entity.getCreatedAt());
      }
    };
    this.__insertionAdapterOfDonationEntity = new EntityInsertionAdapter<DonationEntity>(__db) {
      @Override
      @NonNull
      protected String createQuery() {
        return "INSERT OR ABORT INTO `donations` (`id`,`postId`,`requestId`,`donorId`,`doneeId`,`status`,`deliveredAt`,`finalizedAt`,`cancelReason`,`createdAt`) VALUES (nullif(?, 0),?,?,?,?,?,?,?,?,?)";
      }

      @Override
      protected void bind(@NonNull final SupportSQLiteStatement statement,
          @NonNull final DonationEntity entity) {
        statement.bindLong(1, entity.getId());
        statement.bindLong(2, entity.getPostId());
        statement.bindLong(3, entity.getRequestId());
        statement.bindLong(4, entity.getDonorId());
        statement.bindLong(5, entity.getDoneeId());
        statement.bindString(6, __DonationStatus_enumToString(entity.getStatus()));
        if (entity.getDeliveredAt() == null) {
          statement.bindNull(7);
        } else {
          statement.bindLong(7, entity.getDeliveredAt());
        }
        if (entity.getFinalizedAt() == null) {
          statement.bindNull(8);
        } else {
          statement.bindLong(8, entity.getFinalizedAt());
        }
        if (entity.getCancelReason() == null) {
          statement.bindNull(9);
        } else {
          statement.bindString(9, entity.getCancelReason());
        }
        statement.bindLong(10, entity.getCreatedAt());
      }
    };
    this.__insertionAdapterOfStatusChangeEntity = new EntityInsertionAdapter<StatusChangeEntity>(__db) {
      @Override
      @NonNull
      protected String createQuery() {
        return "INSERT OR ABORT INTO `status_changes` (`id`,`donationId`,`fromStatus`,`toStatus`,`actorId`,`timestamp`) VALUES (nullif(?, 0),?,?,?,?,?)";
      }

      @Override
      protected void bind(@NonNull final SupportSQLiteStatement statement,
          @NonNull final StatusChangeEntity entity) {
        statement.bindLong(1, entity.getId());
        statement.bindLong(2, entity.getDonationId());
        if (entity.getFromStatus() == null) {
          statement.bindNull(3);
        } else {
          statement.bindString(3, __DonationStatus_enumToString(entity.getFromStatus()));
        }
        statement.bindString(4, __DonationStatus_enumToString(entity.getToStatus()));
        if (entity.getActorId() == null) {
          statement.bindNull(5);
        } else {
          statement.bindLong(5, entity.getActorId());
        }
        statement.bindLong(6, entity.getTimestamp());
      }
    };
    this.__updateAdapterOfDonationEntity = new EntityDeletionOrUpdateAdapter<DonationEntity>(__db) {
      @Override
      @NonNull
      protected String createQuery() {
        return "UPDATE OR ABORT `donations` SET `id` = ?,`postId` = ?,`requestId` = ?,`donorId` = ?,`doneeId` = ?,`status` = ?,`deliveredAt` = ?,`finalizedAt` = ?,`cancelReason` = ?,`createdAt` = ? WHERE `id` = ?";
      }

      @Override
      protected void bind(@NonNull final SupportSQLiteStatement statement,
          @NonNull final DonationEntity entity) {
        statement.bindLong(1, entity.getId());
        statement.bindLong(2, entity.getPostId());
        statement.bindLong(3, entity.getRequestId());
        statement.bindLong(4, entity.getDonorId());
        statement.bindLong(5, entity.getDoneeId());
        statement.bindString(6, __DonationStatus_enumToString(entity.getStatus()));
        if (entity.getDeliveredAt() == null) {
          statement.bindNull(7);
        } else {
          statement.bindLong(7, entity.getDeliveredAt());
        }
        if (entity.getFinalizedAt() == null) {
          statement.bindNull(8);
        } else {
          statement.bindLong(8, entity.getFinalizedAt());
        }
        if (entity.getCancelReason() == null) {
          statement.bindNull(9);
        } else {
          statement.bindString(9, entity.getCancelReason());
        }
        statement.bindLong(10, entity.getCreatedAt());
        statement.bindLong(11, entity.getId());
      }
    };
    this.__preparedStmtOfSetPhoneShared = new SharedSQLiteStatement(__db) {
      @Override
      @NonNull
      public String createQuery() {
        final String _query = "UPDATE users SET phoneShared = ? WHERE id = ?";
        return _query;
      }
    };
    this.__preparedStmtOfSetPostStatus = new SharedSQLiteStatement(__db) {
      @Override
      @NonNull
      public String createQuery() {
        final String _query = "UPDATE posts SET status = ? WHERE id = ?";
        return _query;
      }
    };
    this.__preparedStmtOfSetRequestStatus = new SharedSQLiteStatement(__db) {
      @Override
      @NonNull
      public String createQuery() {
        final String _query = "UPDATE requests SET status = ? WHERE id = ?";
        return _query;
      }
    };
    this.__preparedStmtOfRejectOtherPending = new SharedSQLiteStatement(__db) {
      @Override
      @NonNull
      public String createQuery() {
        final String _query = "UPDATE requests SET status = ? WHERE postId = ? AND id != ? AND status = ?";
        return _query;
      }
    };
  }

  @Override
  public Object insertUser(final UserEntity user, final Continuation<? super Long> $completion) {
    return CoroutinesRoom.execute(__db, true, new Callable<Long>() {
      @Override
      @NonNull
      public Long call() throws Exception {
        __db.beginTransaction();
        try {
          final Long _result = __insertionAdapterOfUserEntity.insertAndReturnId(user);
          __db.setTransactionSuccessful();
          return _result;
        } finally {
          __db.endTransaction();
        }
      }
    }, $completion);
  }

  @Override
  public Object insertPost(final PostEntity post, final Continuation<? super Long> $completion) {
    return CoroutinesRoom.execute(__db, true, new Callable<Long>() {
      @Override
      @NonNull
      public Long call() throws Exception {
        __db.beginTransaction();
        try {
          final Long _result = __insertionAdapterOfPostEntity.insertAndReturnId(post);
          __db.setTransactionSuccessful();
          return _result;
        } finally {
          __db.endTransaction();
        }
      }
    }, $completion);
  }

  @Override
  public Object insertRequest(final RequestEntity request,
      final Continuation<? super Long> $completion) {
    return CoroutinesRoom.execute(__db, true, new Callable<Long>() {
      @Override
      @NonNull
      public Long call() throws Exception {
        __db.beginTransaction();
        try {
          final Long _result = __insertionAdapterOfRequestEntity.insertAndReturnId(request);
          __db.setTransactionSuccessful();
          return _result;
        } finally {
          __db.endTransaction();
        }
      }
    }, $completion);
  }

  @Override
  public Object insertDonation(final DonationEntity donation,
      final Continuation<? super Long> $completion) {
    return CoroutinesRoom.execute(__db, true, new Callable<Long>() {
      @Override
      @NonNull
      public Long call() throws Exception {
        __db.beginTransaction();
        try {
          final Long _result = __insertionAdapterOfDonationEntity.insertAndReturnId(donation);
          __db.setTransactionSuccessful();
          return _result;
        } finally {
          __db.endTransaction();
        }
      }
    }, $completion);
  }

  @Override
  public Object insertChange(final StatusChangeEntity change,
      final Continuation<? super Long> $completion) {
    return CoroutinesRoom.execute(__db, true, new Callable<Long>() {
      @Override
      @NonNull
      public Long call() throws Exception {
        __db.beginTransaction();
        try {
          final Long _result = __insertionAdapterOfStatusChangeEntity.insertAndReturnId(change);
          __db.setTransactionSuccessful();
          return _result;
        } finally {
          __db.endTransaction();
        }
      }
    }, $completion);
  }

  @Override
  public Object updateDonation(final DonationEntity donation,
      final Continuation<? super Unit> $completion) {
    return CoroutinesRoom.execute(__db, true, new Callable<Unit>() {
      @Override
      @NonNull
      public Unit call() throws Exception {
        __db.beginTransaction();
        try {
          __updateAdapterOfDonationEntity.handle(donation);
          __db.setTransactionSuccessful();
          return Unit.INSTANCE;
        } finally {
          __db.endTransaction();
        }
      }
    }, $completion);
  }

  @Override
  public Object setPhoneShared(final long id, final boolean shared,
      final Continuation<? super Unit> $completion) {
    return CoroutinesRoom.execute(__db, true, new Callable<Unit>() {
      @Override
      @NonNull
      public Unit call() throws Exception {
        final SupportSQLiteStatement _stmt = __preparedStmtOfSetPhoneShared.acquire();
        int _argIndex = 1;
        final int _tmp = shared ? 1 : 0;
        _stmt.bindLong(_argIndex, _tmp);
        _argIndex = 2;
        _stmt.bindLong(_argIndex, id);
        try {
          __db.beginTransaction();
          try {
            _stmt.executeUpdateDelete();
            __db.setTransactionSuccessful();
            return Unit.INSTANCE;
          } finally {
            __db.endTransaction();
          }
        } finally {
          __preparedStmtOfSetPhoneShared.release(_stmt);
        }
      }
    }, $completion);
  }

  @Override
  public Object setPostStatus(final long id, final PostStatus status,
      final Continuation<? super Unit> $completion) {
    return CoroutinesRoom.execute(__db, true, new Callable<Unit>() {
      @Override
      @NonNull
      public Unit call() throws Exception {
        final SupportSQLiteStatement _stmt = __preparedStmtOfSetPostStatus.acquire();
        int _argIndex = 1;
        _stmt.bindString(_argIndex, __PostStatus_enumToString(status));
        _argIndex = 2;
        _stmt.bindLong(_argIndex, id);
        try {
          __db.beginTransaction();
          try {
            _stmt.executeUpdateDelete();
            __db.setTransactionSuccessful();
            return Unit.INSTANCE;
          } finally {
            __db.endTransaction();
          }
        } finally {
          __preparedStmtOfSetPostStatus.release(_stmt);
        }
      }
    }, $completion);
  }

  @Override
  public Object setRequestStatus(final long id, final RequestStatus status,
      final Continuation<? super Unit> $completion) {
    return CoroutinesRoom.execute(__db, true, new Callable<Unit>() {
      @Override
      @NonNull
      public Unit call() throws Exception {
        final SupportSQLiteStatement _stmt = __preparedStmtOfSetRequestStatus.acquire();
        int _argIndex = 1;
        _stmt.bindString(_argIndex, __RequestStatus_enumToString(status));
        _argIndex = 2;
        _stmt.bindLong(_argIndex, id);
        try {
          __db.beginTransaction();
          try {
            _stmt.executeUpdateDelete();
            __db.setTransactionSuccessful();
            return Unit.INSTANCE;
          } finally {
            __db.endTransaction();
          }
        } finally {
          __preparedStmtOfSetRequestStatus.release(_stmt);
        }
      }
    }, $completion);
  }

  @Override
  public Object rejectOtherPending(final long postId, final long exceptId,
      final RequestStatus oldStatus, final RequestStatus newStatus,
      final Continuation<? super Unit> $completion) {
    return CoroutinesRoom.execute(__db, true, new Callable<Unit>() {
      @Override
      @NonNull
      public Unit call() throws Exception {
        final SupportSQLiteStatement _stmt = __preparedStmtOfRejectOtherPending.acquire();
        int _argIndex = 1;
        _stmt.bindString(_argIndex, __RequestStatus_enumToString(newStatus));
        _argIndex = 2;
        _stmt.bindLong(_argIndex, postId);
        _argIndex = 3;
        _stmt.bindLong(_argIndex, exceptId);
        _argIndex = 4;
        _stmt.bindString(_argIndex, __RequestStatus_enumToString(oldStatus));
        try {
          __db.beginTransaction();
          try {
            _stmt.executeUpdateDelete();
            __db.setTransactionSuccessful();
            return Unit.INSTANCE;
          } finally {
            __db.endTransaction();
          }
        } finally {
          __preparedStmtOfRejectOtherPending.release(_stmt);
        }
      }
    }, $completion);
  }

  @Override
  public Object findByUsername(final String username,
      final Continuation<? super UserEntity> $completion) {
    final String _sql = "SELECT * FROM users WHERE username = ? COLLATE NOCASE LIMIT 1";
    final RoomSQLiteQuery _statement = RoomSQLiteQuery.acquire(_sql, 1);
    int _argIndex = 1;
    _statement.bindString(_argIndex, username);
    final CancellationSignal _cancellationSignal = DBUtil.createCancellationSignal();
    return CoroutinesRoom.execute(__db, false, _cancellationSignal, new Callable<UserEntity>() {
      @Override
      @Nullable
      public UserEntity call() throws Exception {
        final Cursor _cursor = DBUtil.query(__db, _statement, false, null);
        try {
          final int _cursorIndexOfId = CursorUtil.getColumnIndexOrThrow(_cursor, "id");
          final int _cursorIndexOfUsername = CursorUtil.getColumnIndexOrThrow(_cursor, "username");
          final int _cursorIndexOfLegalName = CursorUtil.getColumnIndexOrThrow(_cursor, "legalName");
          final int _cursorIndexOfEmail = CursorUtil.getColumnIndexOrThrow(_cursor, "email");
          final int _cursorIndexOfPhone = CursorUtil.getColumnIndexOrThrow(_cursor, "phone");
          final int _cursorIndexOfPasswordHash = CursorUtil.getColumnIndexOrThrow(_cursor, "passwordHash");
          final int _cursorIndexOfSalt = CursorUtil.getColumnIndexOrThrow(_cursor, "salt");
          final int _cursorIndexOfPhoneShared = CursorUtil.getColumnIndexOrThrow(_cursor, "phoneShared");
          final int _cursorIndexOfCreatedAt = CursorUtil.getColumnIndexOrThrow(_cursor, "createdAt");
          final UserEntity _result;
          if (_cursor.moveToFirst()) {
            final long _tmpId;
            _tmpId = _cursor.getLong(_cursorIndexOfId);
            final String _tmpUsername;
            _tmpUsername = _cursor.getString(_cursorIndexOfUsername);
            final String _tmpLegalName;
            _tmpLegalName = _cursor.getString(_cursorIndexOfLegalName);
            final String _tmpEmail;
            _tmpEmail = _cursor.getString(_cursorIndexOfEmail);
            final String _tmpPhone;
            _tmpPhone = _cursor.getString(_cursorIndexOfPhone);
            final String _tmpPasswordHash;
            _tmpPasswordHash = _cursor.getString(_cursorIndexOfPasswordHash);
            final String _tmpSalt;
            _tmpSalt = _cursor.getString(_cursorIndexOfSalt);
            final boolean _tmpPhoneShared;
            final int _tmp;
            _tmp = _cursor.getInt(_cursorIndexOfPhoneShared);
            _tmpPhoneShared = _tmp != 0;
            final long _tmpCreatedAt;
            _tmpCreatedAt = _cursor.getLong(_cursorIndexOfCreatedAt);
            _result = new UserEntity(_tmpId,_tmpUsername,_tmpLegalName,_tmpEmail,_tmpPhone,_tmpPasswordHash,_tmpSalt,_tmpPhoneShared,_tmpCreatedAt);
          } else {
            _result = null;
          }
          return _result;
        } finally {
          _cursor.close();
          _statement.release();
        }
      }
    }, $completion);
  }

  @Override
  public Object findByEmail(final String email,
      final Continuation<? super UserEntity> $completion) {
    final String _sql = "SELECT * FROM users WHERE email = ? COLLATE NOCASE LIMIT 1";
    final RoomSQLiteQuery _statement = RoomSQLiteQuery.acquire(_sql, 1);
    int _argIndex = 1;
    _statement.bindString(_argIndex, email);
    final CancellationSignal _cancellationSignal = DBUtil.createCancellationSignal();
    return CoroutinesRoom.execute(__db, false, _cancellationSignal, new Callable<UserEntity>() {
      @Override
      @Nullable
      public UserEntity call() throws Exception {
        final Cursor _cursor = DBUtil.query(__db, _statement, false, null);
        try {
          final int _cursorIndexOfId = CursorUtil.getColumnIndexOrThrow(_cursor, "id");
          final int _cursorIndexOfUsername = CursorUtil.getColumnIndexOrThrow(_cursor, "username");
          final int _cursorIndexOfLegalName = CursorUtil.getColumnIndexOrThrow(_cursor, "legalName");
          final int _cursorIndexOfEmail = CursorUtil.getColumnIndexOrThrow(_cursor, "email");
          final int _cursorIndexOfPhone = CursorUtil.getColumnIndexOrThrow(_cursor, "phone");
          final int _cursorIndexOfPasswordHash = CursorUtil.getColumnIndexOrThrow(_cursor, "passwordHash");
          final int _cursorIndexOfSalt = CursorUtil.getColumnIndexOrThrow(_cursor, "salt");
          final int _cursorIndexOfPhoneShared = CursorUtil.getColumnIndexOrThrow(_cursor, "phoneShared");
          final int _cursorIndexOfCreatedAt = CursorUtil.getColumnIndexOrThrow(_cursor, "createdAt");
          final UserEntity _result;
          if (_cursor.moveToFirst()) {
            final long _tmpId;
            _tmpId = _cursor.getLong(_cursorIndexOfId);
            final String _tmpUsername;
            _tmpUsername = _cursor.getString(_cursorIndexOfUsername);
            final String _tmpLegalName;
            _tmpLegalName = _cursor.getString(_cursorIndexOfLegalName);
            final String _tmpEmail;
            _tmpEmail = _cursor.getString(_cursorIndexOfEmail);
            final String _tmpPhone;
            _tmpPhone = _cursor.getString(_cursorIndexOfPhone);
            final String _tmpPasswordHash;
            _tmpPasswordHash = _cursor.getString(_cursorIndexOfPasswordHash);
            final String _tmpSalt;
            _tmpSalt = _cursor.getString(_cursorIndexOfSalt);
            final boolean _tmpPhoneShared;
            final int _tmp;
            _tmp = _cursor.getInt(_cursorIndexOfPhoneShared);
            _tmpPhoneShared = _tmp != 0;
            final long _tmpCreatedAt;
            _tmpCreatedAt = _cursor.getLong(_cursorIndexOfCreatedAt);
            _result = new UserEntity(_tmpId,_tmpUsername,_tmpLegalName,_tmpEmail,_tmpPhone,_tmpPasswordHash,_tmpSalt,_tmpPhoneShared,_tmpCreatedAt);
          } else {
            _result = null;
          }
          return _result;
        } finally {
          _cursor.close();
          _statement.release();
        }
      }
    }, $completion);
  }

  @Override
  public Object findByLogin(final String login,
      final Continuation<? super UserEntity> $completion) {
    final String _sql = "SELECT * FROM users WHERE username = ? COLLATE NOCASE OR email = ? COLLATE NOCASE LIMIT 1";
    final RoomSQLiteQuery _statement = RoomSQLiteQuery.acquire(_sql, 2);
    int _argIndex = 1;
    _statement.bindString(_argIndex, login);
    _argIndex = 2;
    _statement.bindString(_argIndex, login);
    final CancellationSignal _cancellationSignal = DBUtil.createCancellationSignal();
    return CoroutinesRoom.execute(__db, false, _cancellationSignal, new Callable<UserEntity>() {
      @Override
      @Nullable
      public UserEntity call() throws Exception {
        final Cursor _cursor = DBUtil.query(__db, _statement, false, null);
        try {
          final int _cursorIndexOfId = CursorUtil.getColumnIndexOrThrow(_cursor, "id");
          final int _cursorIndexOfUsername = CursorUtil.getColumnIndexOrThrow(_cursor, "username");
          final int _cursorIndexOfLegalName = CursorUtil.getColumnIndexOrThrow(_cursor, "legalName");
          final int _cursorIndexOfEmail = CursorUtil.getColumnIndexOrThrow(_cursor, "email");
          final int _cursorIndexOfPhone = CursorUtil.getColumnIndexOrThrow(_cursor, "phone");
          final int _cursorIndexOfPasswordHash = CursorUtil.getColumnIndexOrThrow(_cursor, "passwordHash");
          final int _cursorIndexOfSalt = CursorUtil.getColumnIndexOrThrow(_cursor, "salt");
          final int _cursorIndexOfPhoneShared = CursorUtil.getColumnIndexOrThrow(_cursor, "phoneShared");
          final int _cursorIndexOfCreatedAt = CursorUtil.getColumnIndexOrThrow(_cursor, "createdAt");
          final UserEntity _result;
          if (_cursor.moveToFirst()) {
            final long _tmpId;
            _tmpId = _cursor.getLong(_cursorIndexOfId);
            final String _tmpUsername;
            _tmpUsername = _cursor.getString(_cursorIndexOfUsername);
            final String _tmpLegalName;
            _tmpLegalName = _cursor.getString(_cursorIndexOfLegalName);
            final String _tmpEmail;
            _tmpEmail = _cursor.getString(_cursorIndexOfEmail);
            final String _tmpPhone;
            _tmpPhone = _cursor.getString(_cursorIndexOfPhone);
            final String _tmpPasswordHash;
            _tmpPasswordHash = _cursor.getString(_cursorIndexOfPasswordHash);
            final String _tmpSalt;
            _tmpSalt = _cursor.getString(_cursorIndexOfSalt);
            final boolean _tmpPhoneShared;
            final int _tmp;
            _tmp = _cursor.getInt(_cursorIndexOfPhoneShared);
            _tmpPhoneShared = _tmp != 0;
            final long _tmpCreatedAt;
            _tmpCreatedAt = _cursor.getLong(_cursorIndexOfCreatedAt);
            _result = new UserEntity(_tmpId,_tmpUsername,_tmpLegalName,_tmpEmail,_tmpPhone,_tmpPasswordHash,_tmpSalt,_tmpPhoneShared,_tmpCreatedAt);
          } else {
            _result = null;
          }
          return _result;
        } finally {
          _cursor.close();
          _statement.release();
        }
      }
    }, $completion);
  }

  @Override
  public Flow<UserEntity> observeUser(final long id) {
    final String _sql = "SELECT * FROM users WHERE id = ?";
    final RoomSQLiteQuery _statement = RoomSQLiteQuery.acquire(_sql, 1);
    int _argIndex = 1;
    _statement.bindLong(_argIndex, id);
    return CoroutinesRoom.createFlow(__db, false, new String[] {"users"}, new Callable<UserEntity>() {
      @Override
      @Nullable
      public UserEntity call() throws Exception {
        final Cursor _cursor = DBUtil.query(__db, _statement, false, null);
        try {
          final int _cursorIndexOfId = CursorUtil.getColumnIndexOrThrow(_cursor, "id");
          final int _cursorIndexOfUsername = CursorUtil.getColumnIndexOrThrow(_cursor, "username");
          final int _cursorIndexOfLegalName = CursorUtil.getColumnIndexOrThrow(_cursor, "legalName");
          final int _cursorIndexOfEmail = CursorUtil.getColumnIndexOrThrow(_cursor, "email");
          final int _cursorIndexOfPhone = CursorUtil.getColumnIndexOrThrow(_cursor, "phone");
          final int _cursorIndexOfPasswordHash = CursorUtil.getColumnIndexOrThrow(_cursor, "passwordHash");
          final int _cursorIndexOfSalt = CursorUtil.getColumnIndexOrThrow(_cursor, "salt");
          final int _cursorIndexOfPhoneShared = CursorUtil.getColumnIndexOrThrow(_cursor, "phoneShared");
          final int _cursorIndexOfCreatedAt = CursorUtil.getColumnIndexOrThrow(_cursor, "createdAt");
          final UserEntity _result;
          if (_cursor.moveToFirst()) {
            final long _tmpId;
            _tmpId = _cursor.getLong(_cursorIndexOfId);
            final String _tmpUsername;
            _tmpUsername = _cursor.getString(_cursorIndexOfUsername);
            final String _tmpLegalName;
            _tmpLegalName = _cursor.getString(_cursorIndexOfLegalName);
            final String _tmpEmail;
            _tmpEmail = _cursor.getString(_cursorIndexOfEmail);
            final String _tmpPhone;
            _tmpPhone = _cursor.getString(_cursorIndexOfPhone);
            final String _tmpPasswordHash;
            _tmpPasswordHash = _cursor.getString(_cursorIndexOfPasswordHash);
            final String _tmpSalt;
            _tmpSalt = _cursor.getString(_cursorIndexOfSalt);
            final boolean _tmpPhoneShared;
            final int _tmp;
            _tmp = _cursor.getInt(_cursorIndexOfPhoneShared);
            _tmpPhoneShared = _tmp != 0;
            final long _tmpCreatedAt;
            _tmpCreatedAt = _cursor.getLong(_cursorIndexOfCreatedAt);
            _result = new UserEntity(_tmpId,_tmpUsername,_tmpLegalName,_tmpEmail,_tmpPhone,_tmpPasswordHash,_tmpSalt,_tmpPhoneShared,_tmpCreatedAt);
          } else {
            _result = null;
          }
          return _result;
        } finally {
          _cursor.close();
        }
      }

      @Override
      protected void finalize() {
        _statement.release();
      }
    });
  }

  @Override
  public Object getPost(final long id, final Continuation<? super PostEntity> $completion) {
    final String _sql = "SELECT * FROM posts WHERE id = ?";
    final RoomSQLiteQuery _statement = RoomSQLiteQuery.acquire(_sql, 1);
    int _argIndex = 1;
    _statement.bindLong(_argIndex, id);
    final CancellationSignal _cancellationSignal = DBUtil.createCancellationSignal();
    return CoroutinesRoom.execute(__db, false, _cancellationSignal, new Callable<PostEntity>() {
      @Override
      @Nullable
      public PostEntity call() throws Exception {
        final Cursor _cursor = DBUtil.query(__db, _statement, false, null);
        try {
          final int _cursorIndexOfId = CursorUtil.getColumnIndexOrThrow(_cursor, "id");
          final int _cursorIndexOfType = CursorUtil.getColumnIndexOrThrow(_cursor, "type");
          final int _cursorIndexOfTitle = CursorUtil.getColumnIndexOrThrow(_cursor, "title");
          final int _cursorIndexOfDescription = CursorUtil.getColumnIndexOrThrow(_cursor, "description");
          final int _cursorIndexOfCategory = CursorUtil.getColumnIndexOrThrow(_cursor, "category");
          final int _cursorIndexOfQuantity = CursorUtil.getColumnIndexOrThrow(_cursor, "quantity");
          final int _cursorIndexOfCondition = CursorUtil.getColumnIndexOrThrow(_cursor, "condition");
          final int _cursorIndexOfUrgency = CursorUtil.getColumnIndexOrThrow(_cursor, "urgency");
          final int _cursorIndexOfFeatures = CursorUtil.getColumnIndexOrThrow(_cursor, "features");
          final int _cursorIndexOfLocation = CursorUtil.getColumnIndexOrThrow(_cursor, "location");
          final int _cursorIndexOfPhotoPaths = CursorUtil.getColumnIndexOrThrow(_cursor, "photoPaths");
          final int _cursorIndexOfAuthorId = CursorUtil.getColumnIndexOrThrow(_cursor, "authorId");
          final int _cursorIndexOfStatus = CursorUtil.getColumnIndexOrThrow(_cursor, "status");
          final int _cursorIndexOfCreatedAt = CursorUtil.getColumnIndexOrThrow(_cursor, "createdAt");
          final PostEntity _result;
          if (_cursor.moveToFirst()) {
            final long _tmpId;
            _tmpId = _cursor.getLong(_cursorIndexOfId);
            final PostType _tmpType;
            _tmpType = __PostType_stringToEnum(_cursor.getString(_cursorIndexOfType));
            final String _tmpTitle;
            _tmpTitle = _cursor.getString(_cursorIndexOfTitle);
            final String _tmpDescription;
            _tmpDescription = _cursor.getString(_cursorIndexOfDescription);
            final String _tmpCategory;
            _tmpCategory = _cursor.getString(_cursorIndexOfCategory);
            final int _tmpQuantity;
            _tmpQuantity = _cursor.getInt(_cursorIndexOfQuantity);
            final ItemCondition _tmpCondition;
            if (_cursor.isNull(_cursorIndexOfCondition)) {
              _tmpCondition = null;
            } else {
              _tmpCondition = __ItemCondition_stringToEnum(_cursor.getString(_cursorIndexOfCondition));
            }
            final Urgency _tmpUrgency;
            if (_cursor.isNull(_cursorIndexOfUrgency)) {
              _tmpUrgency = null;
            } else {
              _tmpUrgency = __Urgency_stringToEnum(_cursor.getString(_cursorIndexOfUrgency));
            }
            final String _tmpFeatures;
            _tmpFeatures = _cursor.getString(_cursorIndexOfFeatures);
            final String _tmpLocation;
            _tmpLocation = _cursor.getString(_cursorIndexOfLocation);
            final String _tmpPhotoPaths;
            _tmpPhotoPaths = _cursor.getString(_cursorIndexOfPhotoPaths);
            final long _tmpAuthorId;
            _tmpAuthorId = _cursor.getLong(_cursorIndexOfAuthorId);
            final PostStatus _tmpStatus;
            _tmpStatus = __PostStatus_stringToEnum(_cursor.getString(_cursorIndexOfStatus));
            final long _tmpCreatedAt;
            _tmpCreatedAt = _cursor.getLong(_cursorIndexOfCreatedAt);
            _result = new PostEntity(_tmpId,_tmpType,_tmpTitle,_tmpDescription,_tmpCategory,_tmpQuantity,_tmpCondition,_tmpUrgency,_tmpFeatures,_tmpLocation,_tmpPhotoPaths,_tmpAuthorId,_tmpStatus,_tmpCreatedAt);
          } else {
            _result = null;
          }
          return _result;
        } finally {
          _cursor.close();
          _statement.release();
        }
      }
    }, $completion);
  }

  @Override
  public Flow<PostEntity> observePost(final long id) {
    final String _sql = "SELECT * FROM posts WHERE id = ?";
    final RoomSQLiteQuery _statement = RoomSQLiteQuery.acquire(_sql, 1);
    int _argIndex = 1;
    _statement.bindLong(_argIndex, id);
    return CoroutinesRoom.createFlow(__db, false, new String[] {"posts"}, new Callable<PostEntity>() {
      @Override
      @Nullable
      public PostEntity call() throws Exception {
        final Cursor _cursor = DBUtil.query(__db, _statement, false, null);
        try {
          final int _cursorIndexOfId = CursorUtil.getColumnIndexOrThrow(_cursor, "id");
          final int _cursorIndexOfType = CursorUtil.getColumnIndexOrThrow(_cursor, "type");
          final int _cursorIndexOfTitle = CursorUtil.getColumnIndexOrThrow(_cursor, "title");
          final int _cursorIndexOfDescription = CursorUtil.getColumnIndexOrThrow(_cursor, "description");
          final int _cursorIndexOfCategory = CursorUtil.getColumnIndexOrThrow(_cursor, "category");
          final int _cursorIndexOfQuantity = CursorUtil.getColumnIndexOrThrow(_cursor, "quantity");
          final int _cursorIndexOfCondition = CursorUtil.getColumnIndexOrThrow(_cursor, "condition");
          final int _cursorIndexOfUrgency = CursorUtil.getColumnIndexOrThrow(_cursor, "urgency");
          final int _cursorIndexOfFeatures = CursorUtil.getColumnIndexOrThrow(_cursor, "features");
          final int _cursorIndexOfLocation = CursorUtil.getColumnIndexOrThrow(_cursor, "location");
          final int _cursorIndexOfPhotoPaths = CursorUtil.getColumnIndexOrThrow(_cursor, "photoPaths");
          final int _cursorIndexOfAuthorId = CursorUtil.getColumnIndexOrThrow(_cursor, "authorId");
          final int _cursorIndexOfStatus = CursorUtil.getColumnIndexOrThrow(_cursor, "status");
          final int _cursorIndexOfCreatedAt = CursorUtil.getColumnIndexOrThrow(_cursor, "createdAt");
          final PostEntity _result;
          if (_cursor.moveToFirst()) {
            final long _tmpId;
            _tmpId = _cursor.getLong(_cursorIndexOfId);
            final PostType _tmpType;
            _tmpType = __PostType_stringToEnum(_cursor.getString(_cursorIndexOfType));
            final String _tmpTitle;
            _tmpTitle = _cursor.getString(_cursorIndexOfTitle);
            final String _tmpDescription;
            _tmpDescription = _cursor.getString(_cursorIndexOfDescription);
            final String _tmpCategory;
            _tmpCategory = _cursor.getString(_cursorIndexOfCategory);
            final int _tmpQuantity;
            _tmpQuantity = _cursor.getInt(_cursorIndexOfQuantity);
            final ItemCondition _tmpCondition;
            if (_cursor.isNull(_cursorIndexOfCondition)) {
              _tmpCondition = null;
            } else {
              _tmpCondition = __ItemCondition_stringToEnum(_cursor.getString(_cursorIndexOfCondition));
            }
            final Urgency _tmpUrgency;
            if (_cursor.isNull(_cursorIndexOfUrgency)) {
              _tmpUrgency = null;
            } else {
              _tmpUrgency = __Urgency_stringToEnum(_cursor.getString(_cursorIndexOfUrgency));
            }
            final String _tmpFeatures;
            _tmpFeatures = _cursor.getString(_cursorIndexOfFeatures);
            final String _tmpLocation;
            _tmpLocation = _cursor.getString(_cursorIndexOfLocation);
            final String _tmpPhotoPaths;
            _tmpPhotoPaths = _cursor.getString(_cursorIndexOfPhotoPaths);
            final long _tmpAuthorId;
            _tmpAuthorId = _cursor.getLong(_cursorIndexOfAuthorId);
            final PostStatus _tmpStatus;
            _tmpStatus = __PostStatus_stringToEnum(_cursor.getString(_cursorIndexOfStatus));
            final long _tmpCreatedAt;
            _tmpCreatedAt = _cursor.getLong(_cursorIndexOfCreatedAt);
            _result = new PostEntity(_tmpId,_tmpType,_tmpTitle,_tmpDescription,_tmpCategory,_tmpQuantity,_tmpCondition,_tmpUrgency,_tmpFeatures,_tmpLocation,_tmpPhotoPaths,_tmpAuthorId,_tmpStatus,_tmpCreatedAt);
          } else {
            _result = null;
          }
          return _result;
        } finally {
          _cursor.close();
        }
      }

      @Override
      protected void finalize() {
        _statement.release();
      }
    });
  }

  @Override
  public Flow<List<PostEntity>> observeFeed(final PostStatus status, final PostType type,
      final String category) {
    final String _sql = "\n"
            + "        SELECT * FROM posts\n"
            + "        WHERE status = ?\n"
            + "          AND (? IS NULL OR type = ?)\n"
            + "          AND (? IS NULL OR category = ?)\n"
            + "        ORDER BY createdAt DESC\n"
            + "        ";
    final RoomSQLiteQuery _statement = RoomSQLiteQuery.acquire(_sql, 5);
    int _argIndex = 1;
    _statement.bindString(_argIndex, __PostStatus_enumToString(status));
    _argIndex = 2;
    if (type == null) {
      _statement.bindNull(_argIndex);
    } else {
      _statement.bindString(_argIndex, __PostType_enumToString(type));
    }
    _argIndex = 3;
    if (type == null) {
      _statement.bindNull(_argIndex);
    } else {
      _statement.bindString(_argIndex, __PostType_enumToString(type));
    }
    _argIndex = 4;
    if (category == null) {
      _statement.bindNull(_argIndex);
    } else {
      _statement.bindString(_argIndex, category);
    }
    _argIndex = 5;
    if (category == null) {
      _statement.bindNull(_argIndex);
    } else {
      _statement.bindString(_argIndex, category);
    }
    return CoroutinesRoom.createFlow(__db, false, new String[] {"posts"}, new Callable<List<PostEntity>>() {
      @Override
      @NonNull
      public List<PostEntity> call() throws Exception {
        final Cursor _cursor = DBUtil.query(__db, _statement, false, null);
        try {
          final int _cursorIndexOfId = CursorUtil.getColumnIndexOrThrow(_cursor, "id");
          final int _cursorIndexOfType = CursorUtil.getColumnIndexOrThrow(_cursor, "type");
          final int _cursorIndexOfTitle = CursorUtil.getColumnIndexOrThrow(_cursor, "title");
          final int _cursorIndexOfDescription = CursorUtil.getColumnIndexOrThrow(_cursor, "description");
          final int _cursorIndexOfCategory = CursorUtil.getColumnIndexOrThrow(_cursor, "category");
          final int _cursorIndexOfQuantity = CursorUtil.getColumnIndexOrThrow(_cursor, "quantity");
          final int _cursorIndexOfCondition = CursorUtil.getColumnIndexOrThrow(_cursor, "condition");
          final int _cursorIndexOfUrgency = CursorUtil.getColumnIndexOrThrow(_cursor, "urgency");
          final int _cursorIndexOfFeatures = CursorUtil.getColumnIndexOrThrow(_cursor, "features");
          final int _cursorIndexOfLocation = CursorUtil.getColumnIndexOrThrow(_cursor, "location");
          final int _cursorIndexOfPhotoPaths = CursorUtil.getColumnIndexOrThrow(_cursor, "photoPaths");
          final int _cursorIndexOfAuthorId = CursorUtil.getColumnIndexOrThrow(_cursor, "authorId");
          final int _cursorIndexOfStatus = CursorUtil.getColumnIndexOrThrow(_cursor, "status");
          final int _cursorIndexOfCreatedAt = CursorUtil.getColumnIndexOrThrow(_cursor, "createdAt");
          final List<PostEntity> _result = new ArrayList<PostEntity>(_cursor.getCount());
          while (_cursor.moveToNext()) {
            final PostEntity _item;
            final long _tmpId;
            _tmpId = _cursor.getLong(_cursorIndexOfId);
            final PostType _tmpType;
            _tmpType = __PostType_stringToEnum(_cursor.getString(_cursorIndexOfType));
            final String _tmpTitle;
            _tmpTitle = _cursor.getString(_cursorIndexOfTitle);
            final String _tmpDescription;
            _tmpDescription = _cursor.getString(_cursorIndexOfDescription);
            final String _tmpCategory;
            _tmpCategory = _cursor.getString(_cursorIndexOfCategory);
            final int _tmpQuantity;
            _tmpQuantity = _cursor.getInt(_cursorIndexOfQuantity);
            final ItemCondition _tmpCondition;
            if (_cursor.isNull(_cursorIndexOfCondition)) {
              _tmpCondition = null;
            } else {
              _tmpCondition = __ItemCondition_stringToEnum(_cursor.getString(_cursorIndexOfCondition));
            }
            final Urgency _tmpUrgency;
            if (_cursor.isNull(_cursorIndexOfUrgency)) {
              _tmpUrgency = null;
            } else {
              _tmpUrgency = __Urgency_stringToEnum(_cursor.getString(_cursorIndexOfUrgency));
            }
            final String _tmpFeatures;
            _tmpFeatures = _cursor.getString(_cursorIndexOfFeatures);
            final String _tmpLocation;
            _tmpLocation = _cursor.getString(_cursorIndexOfLocation);
            final String _tmpPhotoPaths;
            _tmpPhotoPaths = _cursor.getString(_cursorIndexOfPhotoPaths);
            final long _tmpAuthorId;
            _tmpAuthorId = _cursor.getLong(_cursorIndexOfAuthorId);
            final PostStatus _tmpStatus;
            _tmpStatus = __PostStatus_stringToEnum(_cursor.getString(_cursorIndexOfStatus));
            final long _tmpCreatedAt;
            _tmpCreatedAt = _cursor.getLong(_cursorIndexOfCreatedAt);
            _item = new PostEntity(_tmpId,_tmpType,_tmpTitle,_tmpDescription,_tmpCategory,_tmpQuantity,_tmpCondition,_tmpUrgency,_tmpFeatures,_tmpLocation,_tmpPhotoPaths,_tmpAuthorId,_tmpStatus,_tmpCreatedAt);
            _result.add(_item);
          }
          return _result;
        } finally {
          _cursor.close();
        }
      }

      @Override
      protected void finalize() {
        _statement.release();
      }
    });
  }

  @Override
  public Object getRequest(final long id, final Continuation<? super RequestEntity> $completion) {
    final String _sql = "SELECT * FROM requests WHERE id = ?";
    final RoomSQLiteQuery _statement = RoomSQLiteQuery.acquire(_sql, 1);
    int _argIndex = 1;
    _statement.bindLong(_argIndex, id);
    final CancellationSignal _cancellationSignal = DBUtil.createCancellationSignal();
    return CoroutinesRoom.execute(__db, false, _cancellationSignal, new Callable<RequestEntity>() {
      @Override
      @Nullable
      public RequestEntity call() throws Exception {
        final Cursor _cursor = DBUtil.query(__db, _statement, false, null);
        try {
          final int _cursorIndexOfId = CursorUtil.getColumnIndexOrThrow(_cursor, "id");
          final int _cursorIndexOfPostId = CursorUtil.getColumnIndexOrThrow(_cursor, "postId");
          final int _cursorIndexOfRequesterId = CursorUtil.getColumnIndexOrThrow(_cursor, "requesterId");
          final int _cursorIndexOfMessage = CursorUtil.getColumnIndexOrThrow(_cursor, "message");
          final int _cursorIndexOfStatus = CursorUtil.getColumnIndexOrThrow(_cursor, "status");
          final int _cursorIndexOfClientKey = CursorUtil.getColumnIndexOrThrow(_cursor, "clientKey");
          final int _cursorIndexOfCreatedAt = CursorUtil.getColumnIndexOrThrow(_cursor, "createdAt");
          final RequestEntity _result;
          if (_cursor.moveToFirst()) {
            final long _tmpId;
            _tmpId = _cursor.getLong(_cursorIndexOfId);
            final long _tmpPostId;
            _tmpPostId = _cursor.getLong(_cursorIndexOfPostId);
            final long _tmpRequesterId;
            _tmpRequesterId = _cursor.getLong(_cursorIndexOfRequesterId);
            final String _tmpMessage;
            _tmpMessage = _cursor.getString(_cursorIndexOfMessage);
            final RequestStatus _tmpStatus;
            _tmpStatus = __RequestStatus_stringToEnum(_cursor.getString(_cursorIndexOfStatus));
            final String _tmpClientKey;
            _tmpClientKey = _cursor.getString(_cursorIndexOfClientKey);
            final long _tmpCreatedAt;
            _tmpCreatedAt = _cursor.getLong(_cursorIndexOfCreatedAt);
            _result = new RequestEntity(_tmpId,_tmpPostId,_tmpRequesterId,_tmpMessage,_tmpStatus,_tmpClientKey,_tmpCreatedAt);
          } else {
            _result = null;
          }
          return _result;
        } finally {
          _cursor.close();
          _statement.release();
        }
      }
    }, $completion);
  }

  @Override
  public Object findRequestByClientKey(final String clientKey,
      final Continuation<? super RequestEntity> $completion) {
    final String _sql = "SELECT * FROM requests WHERE clientKey = ? LIMIT 1";
    final RoomSQLiteQuery _statement = RoomSQLiteQuery.acquire(_sql, 1);
    int _argIndex = 1;
    _statement.bindString(_argIndex, clientKey);
    final CancellationSignal _cancellationSignal = DBUtil.createCancellationSignal();
    return CoroutinesRoom.execute(__db, false, _cancellationSignal, new Callable<RequestEntity>() {
      @Override
      @Nullable
      public RequestEntity call() throws Exception {
        final Cursor _cursor = DBUtil.query(__db, _statement, false, null);
        try {
          final int _cursorIndexOfId = CursorUtil.getColumnIndexOrThrow(_cursor, "id");
          final int _cursorIndexOfPostId = CursorUtil.getColumnIndexOrThrow(_cursor, "postId");
          final int _cursorIndexOfRequesterId = CursorUtil.getColumnIndexOrThrow(_cursor, "requesterId");
          final int _cursorIndexOfMessage = CursorUtil.getColumnIndexOrThrow(_cursor, "message");
          final int _cursorIndexOfStatus = CursorUtil.getColumnIndexOrThrow(_cursor, "status");
          final int _cursorIndexOfClientKey = CursorUtil.getColumnIndexOrThrow(_cursor, "clientKey");
          final int _cursorIndexOfCreatedAt = CursorUtil.getColumnIndexOrThrow(_cursor, "createdAt");
          final RequestEntity _result;
          if (_cursor.moveToFirst()) {
            final long _tmpId;
            _tmpId = _cursor.getLong(_cursorIndexOfId);
            final long _tmpPostId;
            _tmpPostId = _cursor.getLong(_cursorIndexOfPostId);
            final long _tmpRequesterId;
            _tmpRequesterId = _cursor.getLong(_cursorIndexOfRequesterId);
            final String _tmpMessage;
            _tmpMessage = _cursor.getString(_cursorIndexOfMessage);
            final RequestStatus _tmpStatus;
            _tmpStatus = __RequestStatus_stringToEnum(_cursor.getString(_cursorIndexOfStatus));
            final String _tmpClientKey;
            _tmpClientKey = _cursor.getString(_cursorIndexOfClientKey);
            final long _tmpCreatedAt;
            _tmpCreatedAt = _cursor.getLong(_cursorIndexOfCreatedAt);
            _result = new RequestEntity(_tmpId,_tmpPostId,_tmpRequesterId,_tmpMessage,_tmpStatus,_tmpClientKey,_tmpCreatedAt);
          } else {
            _result = null;
          }
          return _result;
        } finally {
          _cursor.close();
          _statement.release();
        }
      }
    }, $completion);
  }

  @Override
  public Object findRequestByUser(final long postId, final long userId, final RequestStatus status,
      final Continuation<? super RequestEntity> $completion) {
    final String _sql = "SELECT * FROM requests WHERE postId = ? AND requesterId = ? AND status = ? LIMIT 1";
    final RoomSQLiteQuery _statement = RoomSQLiteQuery.acquire(_sql, 3);
    int _argIndex = 1;
    _statement.bindLong(_argIndex, postId);
    _argIndex = 2;
    _statement.bindLong(_argIndex, userId);
    _argIndex = 3;
    _statement.bindString(_argIndex, __RequestStatus_enumToString(status));
    final CancellationSignal _cancellationSignal = DBUtil.createCancellationSignal();
    return CoroutinesRoom.execute(__db, false, _cancellationSignal, new Callable<RequestEntity>() {
      @Override
      @Nullable
      public RequestEntity call() throws Exception {
        final Cursor _cursor = DBUtil.query(__db, _statement, false, null);
        try {
          final int _cursorIndexOfId = CursorUtil.getColumnIndexOrThrow(_cursor, "id");
          final int _cursorIndexOfPostId = CursorUtil.getColumnIndexOrThrow(_cursor, "postId");
          final int _cursorIndexOfRequesterId = CursorUtil.getColumnIndexOrThrow(_cursor, "requesterId");
          final int _cursorIndexOfMessage = CursorUtil.getColumnIndexOrThrow(_cursor, "message");
          final int _cursorIndexOfStatus = CursorUtil.getColumnIndexOrThrow(_cursor, "status");
          final int _cursorIndexOfClientKey = CursorUtil.getColumnIndexOrThrow(_cursor, "clientKey");
          final int _cursorIndexOfCreatedAt = CursorUtil.getColumnIndexOrThrow(_cursor, "createdAt");
          final RequestEntity _result;
          if (_cursor.moveToFirst()) {
            final long _tmpId;
            _tmpId = _cursor.getLong(_cursorIndexOfId);
            final long _tmpPostId;
            _tmpPostId = _cursor.getLong(_cursorIndexOfPostId);
            final long _tmpRequesterId;
            _tmpRequesterId = _cursor.getLong(_cursorIndexOfRequesterId);
            final String _tmpMessage;
            _tmpMessage = _cursor.getString(_cursorIndexOfMessage);
            final RequestStatus _tmpStatus;
            _tmpStatus = __RequestStatus_stringToEnum(_cursor.getString(_cursorIndexOfStatus));
            final String _tmpClientKey;
            _tmpClientKey = _cursor.getString(_cursorIndexOfClientKey);
            final long _tmpCreatedAt;
            _tmpCreatedAt = _cursor.getLong(_cursorIndexOfCreatedAt);
            _result = new RequestEntity(_tmpId,_tmpPostId,_tmpRequesterId,_tmpMessage,_tmpStatus,_tmpClientKey,_tmpCreatedAt);
          } else {
            _result = null;
          }
          return _result;
        } finally {
          _cursor.close();
          _statement.release();
        }
      }
    }, $completion);
  }

  @Override
  public Flow<RequestEntity> observeUserRequest(final long postId, final long userId,
      final RequestStatus status) {
    final String _sql = "SELECT * FROM requests WHERE postId = ? AND requesterId = ? AND status = ? LIMIT 1";
    final RoomSQLiteQuery _statement = RoomSQLiteQuery.acquire(_sql, 3);
    int _argIndex = 1;
    _statement.bindLong(_argIndex, postId);
    _argIndex = 2;
    _statement.bindLong(_argIndex, userId);
    _argIndex = 3;
    _statement.bindString(_argIndex, __RequestStatus_enumToString(status));
    return CoroutinesRoom.createFlow(__db, false, new String[] {"requests"}, new Callable<RequestEntity>() {
      @Override
      @Nullable
      public RequestEntity call() throws Exception {
        final Cursor _cursor = DBUtil.query(__db, _statement, false, null);
        try {
          final int _cursorIndexOfId = CursorUtil.getColumnIndexOrThrow(_cursor, "id");
          final int _cursorIndexOfPostId = CursorUtil.getColumnIndexOrThrow(_cursor, "postId");
          final int _cursorIndexOfRequesterId = CursorUtil.getColumnIndexOrThrow(_cursor, "requesterId");
          final int _cursorIndexOfMessage = CursorUtil.getColumnIndexOrThrow(_cursor, "message");
          final int _cursorIndexOfStatus = CursorUtil.getColumnIndexOrThrow(_cursor, "status");
          final int _cursorIndexOfClientKey = CursorUtil.getColumnIndexOrThrow(_cursor, "clientKey");
          final int _cursorIndexOfCreatedAt = CursorUtil.getColumnIndexOrThrow(_cursor, "createdAt");
          final RequestEntity _result;
          if (_cursor.moveToFirst()) {
            final long _tmpId;
            _tmpId = _cursor.getLong(_cursorIndexOfId);
            final long _tmpPostId;
            _tmpPostId = _cursor.getLong(_cursorIndexOfPostId);
            final long _tmpRequesterId;
            _tmpRequesterId = _cursor.getLong(_cursorIndexOfRequesterId);
            final String _tmpMessage;
            _tmpMessage = _cursor.getString(_cursorIndexOfMessage);
            final RequestStatus _tmpStatus;
            _tmpStatus = __RequestStatus_stringToEnum(_cursor.getString(_cursorIndexOfStatus));
            final String _tmpClientKey;
            _tmpClientKey = _cursor.getString(_cursorIndexOfClientKey);
            final long _tmpCreatedAt;
            _tmpCreatedAt = _cursor.getLong(_cursorIndexOfCreatedAt);
            _result = new RequestEntity(_tmpId,_tmpPostId,_tmpRequesterId,_tmpMessage,_tmpStatus,_tmpClientKey,_tmpCreatedAt);
          } else {
            _result = null;
          }
          return _result;
        } finally {
          _cursor.close();
        }
      }

      @Override
      protected void finalize() {
        _statement.release();
      }
    });
  }

  @Override
  public Flow<List<RequestWithUser>> observePendingRequests(final long postId,
      final RequestStatus status) {
    final String _sql = "\n"
            + "        SELECT r.id AS id, r.postId AS postId, r.requesterId AS requesterId, r.message AS message,\n"
            + "               r.status AS status, r.createdAt AS createdAt, u.username AS requesterUsername\n"
            + "        FROM requests r\n"
            + "        JOIN users u ON u.id = r.requesterId\n"
            + "        WHERE r.postId = ? AND r.status = ?\n"
            + "        ORDER BY r.createdAt ASC\n"
            + "        ";
    final RoomSQLiteQuery _statement = RoomSQLiteQuery.acquire(_sql, 2);
    int _argIndex = 1;
    _statement.bindLong(_argIndex, postId);
    _argIndex = 2;
    _statement.bindString(_argIndex, __RequestStatus_enumToString(status));
    return CoroutinesRoom.createFlow(__db, false, new String[] {"requests",
        "users"}, new Callable<List<RequestWithUser>>() {
      @Override
      @NonNull
      public List<RequestWithUser> call() throws Exception {
        final Cursor _cursor = DBUtil.query(__db, _statement, false, null);
        try {
          final int _cursorIndexOfId = 0;
          final int _cursorIndexOfPostId = 1;
          final int _cursorIndexOfRequesterId = 2;
          final int _cursorIndexOfMessage = 3;
          final int _cursorIndexOfStatus = 4;
          final int _cursorIndexOfCreatedAt = 5;
          final int _cursorIndexOfRequesterUsername = 6;
          final List<RequestWithUser> _result = new ArrayList<RequestWithUser>(_cursor.getCount());
          while (_cursor.moveToNext()) {
            final RequestWithUser _item;
            final long _tmpId;
            _tmpId = _cursor.getLong(_cursorIndexOfId);
            final long _tmpPostId;
            _tmpPostId = _cursor.getLong(_cursorIndexOfPostId);
            final long _tmpRequesterId;
            _tmpRequesterId = _cursor.getLong(_cursorIndexOfRequesterId);
            final String _tmpMessage;
            _tmpMessage = _cursor.getString(_cursorIndexOfMessage);
            final RequestStatus _tmpStatus;
            _tmpStatus = __RequestStatus_stringToEnum(_cursor.getString(_cursorIndexOfStatus));
            final long _tmpCreatedAt;
            _tmpCreatedAt = _cursor.getLong(_cursorIndexOfCreatedAt);
            final String _tmpRequesterUsername;
            _tmpRequesterUsername = _cursor.getString(_cursorIndexOfRequesterUsername);
            _item = new RequestWithUser(_tmpId,_tmpPostId,_tmpRequesterId,_tmpMessage,_tmpStatus,_tmpCreatedAt,_tmpRequesterUsername);
            _result.add(_item);
          }
          return _result;
        } finally {
          _cursor.close();
        }
      }

      @Override
      protected void finalize() {
        _statement.release();
      }
    });
  }

  @Override
  public Object getDonation(final long id, final Continuation<? super DonationEntity> $completion) {
    final String _sql = "SELECT * FROM donations WHERE id = ?";
    final RoomSQLiteQuery _statement = RoomSQLiteQuery.acquire(_sql, 1);
    int _argIndex = 1;
    _statement.bindLong(_argIndex, id);
    final CancellationSignal _cancellationSignal = DBUtil.createCancellationSignal();
    return CoroutinesRoom.execute(__db, false, _cancellationSignal, new Callable<DonationEntity>() {
      @Override
      @Nullable
      public DonationEntity call() throws Exception {
        final Cursor _cursor = DBUtil.query(__db, _statement, false, null);
        try {
          final int _cursorIndexOfId = CursorUtil.getColumnIndexOrThrow(_cursor, "id");
          final int _cursorIndexOfPostId = CursorUtil.getColumnIndexOrThrow(_cursor, "postId");
          final int _cursorIndexOfRequestId = CursorUtil.getColumnIndexOrThrow(_cursor, "requestId");
          final int _cursorIndexOfDonorId = CursorUtil.getColumnIndexOrThrow(_cursor, "donorId");
          final int _cursorIndexOfDoneeId = CursorUtil.getColumnIndexOrThrow(_cursor, "doneeId");
          final int _cursorIndexOfStatus = CursorUtil.getColumnIndexOrThrow(_cursor, "status");
          final int _cursorIndexOfDeliveredAt = CursorUtil.getColumnIndexOrThrow(_cursor, "deliveredAt");
          final int _cursorIndexOfFinalizedAt = CursorUtil.getColumnIndexOrThrow(_cursor, "finalizedAt");
          final int _cursorIndexOfCancelReason = CursorUtil.getColumnIndexOrThrow(_cursor, "cancelReason");
          final int _cursorIndexOfCreatedAt = CursorUtil.getColumnIndexOrThrow(_cursor, "createdAt");
          final DonationEntity _result;
          if (_cursor.moveToFirst()) {
            final long _tmpId;
            _tmpId = _cursor.getLong(_cursorIndexOfId);
            final long _tmpPostId;
            _tmpPostId = _cursor.getLong(_cursorIndexOfPostId);
            final long _tmpRequestId;
            _tmpRequestId = _cursor.getLong(_cursorIndexOfRequestId);
            final long _tmpDonorId;
            _tmpDonorId = _cursor.getLong(_cursorIndexOfDonorId);
            final long _tmpDoneeId;
            _tmpDoneeId = _cursor.getLong(_cursorIndexOfDoneeId);
            final DonationStatus _tmpStatus;
            _tmpStatus = __DonationStatus_stringToEnum(_cursor.getString(_cursorIndexOfStatus));
            final Long _tmpDeliveredAt;
            if (_cursor.isNull(_cursorIndexOfDeliveredAt)) {
              _tmpDeliveredAt = null;
            } else {
              _tmpDeliveredAt = _cursor.getLong(_cursorIndexOfDeliveredAt);
            }
            final Long _tmpFinalizedAt;
            if (_cursor.isNull(_cursorIndexOfFinalizedAt)) {
              _tmpFinalizedAt = null;
            } else {
              _tmpFinalizedAt = _cursor.getLong(_cursorIndexOfFinalizedAt);
            }
            final String _tmpCancelReason;
            if (_cursor.isNull(_cursorIndexOfCancelReason)) {
              _tmpCancelReason = null;
            } else {
              _tmpCancelReason = _cursor.getString(_cursorIndexOfCancelReason);
            }
            final long _tmpCreatedAt;
            _tmpCreatedAt = _cursor.getLong(_cursorIndexOfCreatedAt);
            _result = new DonationEntity(_tmpId,_tmpPostId,_tmpRequestId,_tmpDonorId,_tmpDoneeId,_tmpStatus,_tmpDeliveredAt,_tmpFinalizedAt,_tmpCancelReason,_tmpCreatedAt);
          } else {
            _result = null;
          }
          return _result;
        } finally {
          _cursor.close();
          _statement.release();
        }
      }
    }, $completion);
  }

  @Override
  public Object getDonationByRequest(final long requestId,
      final Continuation<? super DonationEntity> $completion) {
    final String _sql = "SELECT * FROM donations WHERE requestId = ? LIMIT 1";
    final RoomSQLiteQuery _statement = RoomSQLiteQuery.acquire(_sql, 1);
    int _argIndex = 1;
    _statement.bindLong(_argIndex, requestId);
    final CancellationSignal _cancellationSignal = DBUtil.createCancellationSignal();
    return CoroutinesRoom.execute(__db, false, _cancellationSignal, new Callable<DonationEntity>() {
      @Override
      @Nullable
      public DonationEntity call() throws Exception {
        final Cursor _cursor = DBUtil.query(__db, _statement, false, null);
        try {
          final int _cursorIndexOfId = CursorUtil.getColumnIndexOrThrow(_cursor, "id");
          final int _cursorIndexOfPostId = CursorUtil.getColumnIndexOrThrow(_cursor, "postId");
          final int _cursorIndexOfRequestId = CursorUtil.getColumnIndexOrThrow(_cursor, "requestId");
          final int _cursorIndexOfDonorId = CursorUtil.getColumnIndexOrThrow(_cursor, "donorId");
          final int _cursorIndexOfDoneeId = CursorUtil.getColumnIndexOrThrow(_cursor, "doneeId");
          final int _cursorIndexOfStatus = CursorUtil.getColumnIndexOrThrow(_cursor, "status");
          final int _cursorIndexOfDeliveredAt = CursorUtil.getColumnIndexOrThrow(_cursor, "deliveredAt");
          final int _cursorIndexOfFinalizedAt = CursorUtil.getColumnIndexOrThrow(_cursor, "finalizedAt");
          final int _cursorIndexOfCancelReason = CursorUtil.getColumnIndexOrThrow(_cursor, "cancelReason");
          final int _cursorIndexOfCreatedAt = CursorUtil.getColumnIndexOrThrow(_cursor, "createdAt");
          final DonationEntity _result;
          if (_cursor.moveToFirst()) {
            final long _tmpId;
            _tmpId = _cursor.getLong(_cursorIndexOfId);
            final long _tmpPostId;
            _tmpPostId = _cursor.getLong(_cursorIndexOfPostId);
            final long _tmpRequestId;
            _tmpRequestId = _cursor.getLong(_cursorIndexOfRequestId);
            final long _tmpDonorId;
            _tmpDonorId = _cursor.getLong(_cursorIndexOfDonorId);
            final long _tmpDoneeId;
            _tmpDoneeId = _cursor.getLong(_cursorIndexOfDoneeId);
            final DonationStatus _tmpStatus;
            _tmpStatus = __DonationStatus_stringToEnum(_cursor.getString(_cursorIndexOfStatus));
            final Long _tmpDeliveredAt;
            if (_cursor.isNull(_cursorIndexOfDeliveredAt)) {
              _tmpDeliveredAt = null;
            } else {
              _tmpDeliveredAt = _cursor.getLong(_cursorIndexOfDeliveredAt);
            }
            final Long _tmpFinalizedAt;
            if (_cursor.isNull(_cursorIndexOfFinalizedAt)) {
              _tmpFinalizedAt = null;
            } else {
              _tmpFinalizedAt = _cursor.getLong(_cursorIndexOfFinalizedAt);
            }
            final String _tmpCancelReason;
            if (_cursor.isNull(_cursorIndexOfCancelReason)) {
              _tmpCancelReason = null;
            } else {
              _tmpCancelReason = _cursor.getString(_cursorIndexOfCancelReason);
            }
            final long _tmpCreatedAt;
            _tmpCreatedAt = _cursor.getLong(_cursorIndexOfCreatedAt);
            _result = new DonationEntity(_tmpId,_tmpPostId,_tmpRequestId,_tmpDonorId,_tmpDoneeId,_tmpStatus,_tmpDeliveredAt,_tmpFinalizedAt,_tmpCancelReason,_tmpCreatedAt);
          } else {
            _result = null;
          }
          return _result;
        } finally {
          _cursor.close();
          _statement.release();
        }
      }
    }, $completion);
  }

  @Override
  public Object findDeliveredBefore(final DonationStatus status, final long cutoff,
      final Continuation<? super List<DonationEntity>> $completion) {
    final String _sql = "SELECT * FROM donations WHERE status = ? AND deliveredAt IS NOT NULL AND deliveredAt <= ?";
    final RoomSQLiteQuery _statement = RoomSQLiteQuery.acquire(_sql, 2);
    int _argIndex = 1;
    _statement.bindString(_argIndex, __DonationStatus_enumToString(status));
    _argIndex = 2;
    _statement.bindLong(_argIndex, cutoff);
    final CancellationSignal _cancellationSignal = DBUtil.createCancellationSignal();
    return CoroutinesRoom.execute(__db, false, _cancellationSignal, new Callable<List<DonationEntity>>() {
      @Override
      @NonNull
      public List<DonationEntity> call() throws Exception {
        final Cursor _cursor = DBUtil.query(__db, _statement, false, null);
        try {
          final int _cursorIndexOfId = CursorUtil.getColumnIndexOrThrow(_cursor, "id");
          final int _cursorIndexOfPostId = CursorUtil.getColumnIndexOrThrow(_cursor, "postId");
          final int _cursorIndexOfRequestId = CursorUtil.getColumnIndexOrThrow(_cursor, "requestId");
          final int _cursorIndexOfDonorId = CursorUtil.getColumnIndexOrThrow(_cursor, "donorId");
          final int _cursorIndexOfDoneeId = CursorUtil.getColumnIndexOrThrow(_cursor, "doneeId");
          final int _cursorIndexOfStatus = CursorUtil.getColumnIndexOrThrow(_cursor, "status");
          final int _cursorIndexOfDeliveredAt = CursorUtil.getColumnIndexOrThrow(_cursor, "deliveredAt");
          final int _cursorIndexOfFinalizedAt = CursorUtil.getColumnIndexOrThrow(_cursor, "finalizedAt");
          final int _cursorIndexOfCancelReason = CursorUtil.getColumnIndexOrThrow(_cursor, "cancelReason");
          final int _cursorIndexOfCreatedAt = CursorUtil.getColumnIndexOrThrow(_cursor, "createdAt");
          final List<DonationEntity> _result = new ArrayList<DonationEntity>(_cursor.getCount());
          while (_cursor.moveToNext()) {
            final DonationEntity _item;
            final long _tmpId;
            _tmpId = _cursor.getLong(_cursorIndexOfId);
            final long _tmpPostId;
            _tmpPostId = _cursor.getLong(_cursorIndexOfPostId);
            final long _tmpRequestId;
            _tmpRequestId = _cursor.getLong(_cursorIndexOfRequestId);
            final long _tmpDonorId;
            _tmpDonorId = _cursor.getLong(_cursorIndexOfDonorId);
            final long _tmpDoneeId;
            _tmpDoneeId = _cursor.getLong(_cursorIndexOfDoneeId);
            final DonationStatus _tmpStatus;
            _tmpStatus = __DonationStatus_stringToEnum(_cursor.getString(_cursorIndexOfStatus));
            final Long _tmpDeliveredAt;
            if (_cursor.isNull(_cursorIndexOfDeliveredAt)) {
              _tmpDeliveredAt = null;
            } else {
              _tmpDeliveredAt = _cursor.getLong(_cursorIndexOfDeliveredAt);
            }
            final Long _tmpFinalizedAt;
            if (_cursor.isNull(_cursorIndexOfFinalizedAt)) {
              _tmpFinalizedAt = null;
            } else {
              _tmpFinalizedAt = _cursor.getLong(_cursorIndexOfFinalizedAt);
            }
            final String _tmpCancelReason;
            if (_cursor.isNull(_cursorIndexOfCancelReason)) {
              _tmpCancelReason = null;
            } else {
              _tmpCancelReason = _cursor.getString(_cursorIndexOfCancelReason);
            }
            final long _tmpCreatedAt;
            _tmpCreatedAt = _cursor.getLong(_cursorIndexOfCreatedAt);
            _item = new DonationEntity(_tmpId,_tmpPostId,_tmpRequestId,_tmpDonorId,_tmpDoneeId,_tmpStatus,_tmpDeliveredAt,_tmpFinalizedAt,_tmpCancelReason,_tmpCreatedAt);
            _result.add(_item);
          }
          return _result;
        } finally {
          _cursor.close();
          _statement.release();
        }
      }
    }, $completion);
  }

  @Override
  public Flow<DonationView> observeDonationView(final long id) {
    final String _sql = "\n"
            + "    SELECT d.id AS id, d.postId AS postId, d.status AS status, d.createdAt AS createdAt,\n"
            + "           d.deliveredAt AS deliveredAt, d.finalizedAt AS finalizedAt, d.cancelReason AS cancelReason,\n"
            + "           p.title AS postTitle,\n"
            + "           d.donorId AS donorId, du.username AS donorUsername, du.email AS donorEmail,\n"
            + "           du.phone AS donorPhone, du.phoneShared AS donorPhoneShared,\n"
            + "           d.doneeId AS doneeId, eu.username AS doneeUsername, eu.email AS doneeEmail,\n"
            + "           eu.phone AS doneePhone, eu.phoneShared AS doneePhoneShared\n"
            + "    FROM donations d\n"
            + "    JOIN posts p ON p.id = d.postId\n"
            + "    JOIN users du ON du.id = d.donorId\n"
            + "    JOIN users eu ON eu.id = d.doneeId\n"
            + " WHERE d.id = ?";
    final RoomSQLiteQuery _statement = RoomSQLiteQuery.acquire(_sql, 1);
    int _argIndex = 1;
    _statement.bindLong(_argIndex, id);
    return CoroutinesRoom.createFlow(__db, false, new String[] {"donations", "posts",
        "users"}, new Callable<DonationView>() {
      @Override
      @Nullable
      public DonationView call() throws Exception {
        final Cursor _cursor = DBUtil.query(__db, _statement, false, null);
        try {
          final int _cursorIndexOfId = 0;
          final int _cursorIndexOfPostId = 1;
          final int _cursorIndexOfStatus = 2;
          final int _cursorIndexOfCreatedAt = 3;
          final int _cursorIndexOfDeliveredAt = 4;
          final int _cursorIndexOfFinalizedAt = 5;
          final int _cursorIndexOfCancelReason = 6;
          final int _cursorIndexOfPostTitle = 7;
          final int _cursorIndexOfDonorId = 8;
          final int _cursorIndexOfDonorUsername = 9;
          final int _cursorIndexOfDonorEmail = 10;
          final int _cursorIndexOfDonorPhone = 11;
          final int _cursorIndexOfDonorPhoneShared = 12;
          final int _cursorIndexOfDoneeId = 13;
          final int _cursorIndexOfDoneeUsername = 14;
          final int _cursorIndexOfDoneeEmail = 15;
          final int _cursorIndexOfDoneePhone = 16;
          final int _cursorIndexOfDoneePhoneShared = 17;
          final DonationView _result;
          if (_cursor.moveToFirst()) {
            final long _tmpId;
            _tmpId = _cursor.getLong(_cursorIndexOfId);
            final long _tmpPostId;
            _tmpPostId = _cursor.getLong(_cursorIndexOfPostId);
            final DonationStatus _tmpStatus;
            _tmpStatus = __DonationStatus_stringToEnum(_cursor.getString(_cursorIndexOfStatus));
            final long _tmpCreatedAt;
            _tmpCreatedAt = _cursor.getLong(_cursorIndexOfCreatedAt);
            final Long _tmpDeliveredAt;
            if (_cursor.isNull(_cursorIndexOfDeliveredAt)) {
              _tmpDeliveredAt = null;
            } else {
              _tmpDeliveredAt = _cursor.getLong(_cursorIndexOfDeliveredAt);
            }
            final Long _tmpFinalizedAt;
            if (_cursor.isNull(_cursorIndexOfFinalizedAt)) {
              _tmpFinalizedAt = null;
            } else {
              _tmpFinalizedAt = _cursor.getLong(_cursorIndexOfFinalizedAt);
            }
            final String _tmpCancelReason;
            if (_cursor.isNull(_cursorIndexOfCancelReason)) {
              _tmpCancelReason = null;
            } else {
              _tmpCancelReason = _cursor.getString(_cursorIndexOfCancelReason);
            }
            final String _tmpPostTitle;
            _tmpPostTitle = _cursor.getString(_cursorIndexOfPostTitle);
            final long _tmpDonorId;
            _tmpDonorId = _cursor.getLong(_cursorIndexOfDonorId);
            final String _tmpDonorUsername;
            _tmpDonorUsername = _cursor.getString(_cursorIndexOfDonorUsername);
            final String _tmpDonorEmail;
            _tmpDonorEmail = _cursor.getString(_cursorIndexOfDonorEmail);
            final String _tmpDonorPhone;
            _tmpDonorPhone = _cursor.getString(_cursorIndexOfDonorPhone);
            final boolean _tmpDonorPhoneShared;
            final int _tmp;
            _tmp = _cursor.getInt(_cursorIndexOfDonorPhoneShared);
            _tmpDonorPhoneShared = _tmp != 0;
            final long _tmpDoneeId;
            _tmpDoneeId = _cursor.getLong(_cursorIndexOfDoneeId);
            final String _tmpDoneeUsername;
            _tmpDoneeUsername = _cursor.getString(_cursorIndexOfDoneeUsername);
            final String _tmpDoneeEmail;
            _tmpDoneeEmail = _cursor.getString(_cursorIndexOfDoneeEmail);
            final String _tmpDoneePhone;
            _tmpDoneePhone = _cursor.getString(_cursorIndexOfDoneePhone);
            final boolean _tmpDoneePhoneShared;
            final int _tmp_1;
            _tmp_1 = _cursor.getInt(_cursorIndexOfDoneePhoneShared);
            _tmpDoneePhoneShared = _tmp_1 != 0;
            _result = new DonationView(_tmpId,_tmpPostId,_tmpStatus,_tmpCreatedAt,_tmpDeliveredAt,_tmpFinalizedAt,_tmpCancelReason,_tmpPostTitle,_tmpDonorId,_tmpDonorUsername,_tmpDonorEmail,_tmpDonorPhone,_tmpDonorPhoneShared,_tmpDoneeId,_tmpDoneeUsername,_tmpDoneeEmail,_tmpDoneePhone,_tmpDoneePhoneShared);
          } else {
            _result = null;
          }
          return _result;
        } finally {
          _cursor.close();
        }
      }

      @Override
      protected void finalize() {
        _statement.release();
      }
    });
  }

  @Override
  public Flow<List<DonationView>> observeDonationViews(final long userId) {
    final String _sql = "\n"
            + "    SELECT d.id AS id, d.postId AS postId, d.status AS status, d.createdAt AS createdAt,\n"
            + "           d.deliveredAt AS deliveredAt, d.finalizedAt AS finalizedAt, d.cancelReason AS cancelReason,\n"
            + "           p.title AS postTitle,\n"
            + "           d.donorId AS donorId, du.username AS donorUsername, du.email AS donorEmail,\n"
            + "           du.phone AS donorPhone, du.phoneShared AS donorPhoneShared,\n"
            + "           d.doneeId AS doneeId, eu.username AS doneeUsername, eu.email AS doneeEmail,\n"
            + "           eu.phone AS doneePhone, eu.phoneShared AS doneePhoneShared\n"
            + "    FROM donations d\n"
            + "    JOIN posts p ON p.id = d.postId\n"
            + "    JOIN users du ON du.id = d.donorId\n"
            + "    JOIN users eu ON eu.id = d.doneeId\n"
            + " WHERE d.donorId = ? OR d.doneeId = ? ORDER BY d.createdAt DESC";
    final RoomSQLiteQuery _statement = RoomSQLiteQuery.acquire(_sql, 2);
    int _argIndex = 1;
    _statement.bindLong(_argIndex, userId);
    _argIndex = 2;
    _statement.bindLong(_argIndex, userId);
    return CoroutinesRoom.createFlow(__db, false, new String[] {"donations", "posts",
        "users"}, new Callable<List<DonationView>>() {
      @Override
      @NonNull
      public List<DonationView> call() throws Exception {
        final Cursor _cursor = DBUtil.query(__db, _statement, false, null);
        try {
          final int _cursorIndexOfId = 0;
          final int _cursorIndexOfPostId = 1;
          final int _cursorIndexOfStatus = 2;
          final int _cursorIndexOfCreatedAt = 3;
          final int _cursorIndexOfDeliveredAt = 4;
          final int _cursorIndexOfFinalizedAt = 5;
          final int _cursorIndexOfCancelReason = 6;
          final int _cursorIndexOfPostTitle = 7;
          final int _cursorIndexOfDonorId = 8;
          final int _cursorIndexOfDonorUsername = 9;
          final int _cursorIndexOfDonorEmail = 10;
          final int _cursorIndexOfDonorPhone = 11;
          final int _cursorIndexOfDonorPhoneShared = 12;
          final int _cursorIndexOfDoneeId = 13;
          final int _cursorIndexOfDoneeUsername = 14;
          final int _cursorIndexOfDoneeEmail = 15;
          final int _cursorIndexOfDoneePhone = 16;
          final int _cursorIndexOfDoneePhoneShared = 17;
          final List<DonationView> _result = new ArrayList<DonationView>(_cursor.getCount());
          while (_cursor.moveToNext()) {
            final DonationView _item;
            final long _tmpId;
            _tmpId = _cursor.getLong(_cursorIndexOfId);
            final long _tmpPostId;
            _tmpPostId = _cursor.getLong(_cursorIndexOfPostId);
            final DonationStatus _tmpStatus;
            _tmpStatus = __DonationStatus_stringToEnum(_cursor.getString(_cursorIndexOfStatus));
            final long _tmpCreatedAt;
            _tmpCreatedAt = _cursor.getLong(_cursorIndexOfCreatedAt);
            final Long _tmpDeliveredAt;
            if (_cursor.isNull(_cursorIndexOfDeliveredAt)) {
              _tmpDeliveredAt = null;
            } else {
              _tmpDeliveredAt = _cursor.getLong(_cursorIndexOfDeliveredAt);
            }
            final Long _tmpFinalizedAt;
            if (_cursor.isNull(_cursorIndexOfFinalizedAt)) {
              _tmpFinalizedAt = null;
            } else {
              _tmpFinalizedAt = _cursor.getLong(_cursorIndexOfFinalizedAt);
            }
            final String _tmpCancelReason;
            if (_cursor.isNull(_cursorIndexOfCancelReason)) {
              _tmpCancelReason = null;
            } else {
              _tmpCancelReason = _cursor.getString(_cursorIndexOfCancelReason);
            }
            final String _tmpPostTitle;
            _tmpPostTitle = _cursor.getString(_cursorIndexOfPostTitle);
            final long _tmpDonorId;
            _tmpDonorId = _cursor.getLong(_cursorIndexOfDonorId);
            final String _tmpDonorUsername;
            _tmpDonorUsername = _cursor.getString(_cursorIndexOfDonorUsername);
            final String _tmpDonorEmail;
            _tmpDonorEmail = _cursor.getString(_cursorIndexOfDonorEmail);
            final String _tmpDonorPhone;
            _tmpDonorPhone = _cursor.getString(_cursorIndexOfDonorPhone);
            final boolean _tmpDonorPhoneShared;
            final int _tmp;
            _tmp = _cursor.getInt(_cursorIndexOfDonorPhoneShared);
            _tmpDonorPhoneShared = _tmp != 0;
            final long _tmpDoneeId;
            _tmpDoneeId = _cursor.getLong(_cursorIndexOfDoneeId);
            final String _tmpDoneeUsername;
            _tmpDoneeUsername = _cursor.getString(_cursorIndexOfDoneeUsername);
            final String _tmpDoneeEmail;
            _tmpDoneeEmail = _cursor.getString(_cursorIndexOfDoneeEmail);
            final String _tmpDoneePhone;
            _tmpDoneePhone = _cursor.getString(_cursorIndexOfDoneePhone);
            final boolean _tmpDoneePhoneShared;
            final int _tmp_1;
            _tmp_1 = _cursor.getInt(_cursorIndexOfDoneePhoneShared);
            _tmpDoneePhoneShared = _tmp_1 != 0;
            _item = new DonationView(_tmpId,_tmpPostId,_tmpStatus,_tmpCreatedAt,_tmpDeliveredAt,_tmpFinalizedAt,_tmpCancelReason,_tmpPostTitle,_tmpDonorId,_tmpDonorUsername,_tmpDonorEmail,_tmpDonorPhone,_tmpDonorPhoneShared,_tmpDoneeId,_tmpDoneeUsername,_tmpDoneeEmail,_tmpDoneePhone,_tmpDoneePhoneShared);
            _result.add(_item);
          }
          return _result;
        } finally {
          _cursor.close();
        }
      }

      @Override
      protected void finalize() {
        _statement.release();
      }
    });
  }

  @Override
  public Flow<List<ChangeWithActor>> observeChanges(final long donationId) {
    final String _sql = "\n"
            + "        SELECT c.id AS id, c.toStatus AS toStatus, c.timestamp AS timestamp, u.username AS actorUsername\n"
            + "        FROM status_changes c\n"
            + "        LEFT JOIN users u ON u.id = c.actorId\n"
            + "        WHERE c.donationId = ?\n"
            + "        ORDER BY c.timestamp ASC, c.id ASC\n"
            + "        ";
    final RoomSQLiteQuery _statement = RoomSQLiteQuery.acquire(_sql, 1);
    int _argIndex = 1;
    _statement.bindLong(_argIndex, donationId);
    return CoroutinesRoom.createFlow(__db, false, new String[] {"status_changes",
        "users"}, new Callable<List<ChangeWithActor>>() {
      @Override
      @NonNull
      public List<ChangeWithActor> call() throws Exception {
        final Cursor _cursor = DBUtil.query(__db, _statement, false, null);
        try {
          final int _cursorIndexOfId = 0;
          final int _cursorIndexOfToStatus = 1;
          final int _cursorIndexOfTimestamp = 2;
          final int _cursorIndexOfActorUsername = 3;
          final List<ChangeWithActor> _result = new ArrayList<ChangeWithActor>(_cursor.getCount());
          while (_cursor.moveToNext()) {
            final ChangeWithActor _item;
            final long _tmpId;
            _tmpId = _cursor.getLong(_cursorIndexOfId);
            final DonationStatus _tmpToStatus;
            _tmpToStatus = __DonationStatus_stringToEnum(_cursor.getString(_cursorIndexOfToStatus));
            final long _tmpTimestamp;
            _tmpTimestamp = _cursor.getLong(_cursorIndexOfTimestamp);
            final String _tmpActorUsername;
            if (_cursor.isNull(_cursorIndexOfActorUsername)) {
              _tmpActorUsername = null;
            } else {
              _tmpActorUsername = _cursor.getString(_cursorIndexOfActorUsername);
            }
            _item = new ChangeWithActor(_tmpId,_tmpToStatus,_tmpTimestamp,_tmpActorUsername);
            _result.add(_item);
          }
          return _result;
        } finally {
          _cursor.close();
        }
      }

      @Override
      protected void finalize() {
        _statement.release();
      }
    });
  }

  @Override
  public Flow<Integer> observePostCount() {
    final String _sql = "SELECT COUNT(*) FROM posts";
    final RoomSQLiteQuery _statement = RoomSQLiteQuery.acquire(_sql, 0);
    return CoroutinesRoom.createFlow(__db, false, new String[] {"posts"}, new Callable<Integer>() {
      @Override
      @NonNull
      public Integer call() throws Exception {
        final Cursor _cursor = DBUtil.query(__db, _statement, false, null);
        try {
          final Integer _result;
          if (_cursor.moveToFirst()) {
            final int _tmp;
            _tmp = _cursor.getInt(0);
            _result = _tmp;
          } else {
            _result = 0;
          }
          return _result;
        } finally {
          _cursor.close();
        }
      }

      @Override
      protected void finalize() {
        _statement.release();
      }
    });
  }

  @Override
  public Flow<Integer> observeRequestCount() {
    final String _sql = "SELECT COUNT(*) FROM requests";
    final RoomSQLiteQuery _statement = RoomSQLiteQuery.acquire(_sql, 0);
    return CoroutinesRoom.createFlow(__db, false, new String[] {"requests"}, new Callable<Integer>() {
      @Override
      @NonNull
      public Integer call() throws Exception {
        final Cursor _cursor = DBUtil.query(__db, _statement, false, null);
        try {
          final Integer _result;
          if (_cursor.moveToFirst()) {
            final int _tmp;
            _tmp = _cursor.getInt(0);
            _result = _tmp;
          } else {
            _result = 0;
          }
          return _result;
        } finally {
          _cursor.close();
        }
      }

      @Override
      protected void finalize() {
        _statement.release();
      }
    });
  }

  @Override
  public Flow<Integer> observeDonationCount() {
    final String _sql = "SELECT COUNT(*) FROM donations";
    final RoomSQLiteQuery _statement = RoomSQLiteQuery.acquire(_sql, 0);
    return CoroutinesRoom.createFlow(__db, false, new String[] {"donations"}, new Callable<Integer>() {
      @Override
      @NonNull
      public Integer call() throws Exception {
        final Cursor _cursor = DBUtil.query(__db, _statement, false, null);
        try {
          final Integer _result;
          if (_cursor.moveToFirst()) {
            final int _tmp;
            _tmp = _cursor.getInt(0);
            _result = _tmp;
          } else {
            _result = 0;
          }
          return _result;
        } finally {
          _cursor.close();
        }
      }

      @Override
      protected void finalize() {
        _statement.release();
      }
    });
  }

  @Override
  public Flow<Integer> observeDonationCountByStatus(final DonationStatus status) {
    final String _sql = "SELECT COUNT(*) FROM donations WHERE status = ?";
    final RoomSQLiteQuery _statement = RoomSQLiteQuery.acquire(_sql, 1);
    int _argIndex = 1;
    _statement.bindString(_argIndex, __DonationStatus_enumToString(status));
    return CoroutinesRoom.createFlow(__db, false, new String[] {"donations"}, new Callable<Integer>() {
      @Override
      @NonNull
      public Integer call() throws Exception {
        final Cursor _cursor = DBUtil.query(__db, _statement, false, null);
        try {
          final Integer _result;
          if (_cursor.moveToFirst()) {
            final int _tmp;
            _tmp = _cursor.getInt(0);
            _result = _tmp;
          } else {
            _result = 0;
          }
          return _result;
        } finally {
          _cursor.close();
        }
      }

      @Override
      protected void finalize() {
        _statement.release();
      }
    });
  }

  @NonNull
  public static List<Class<?>> getRequiredConverters() {
    return Collections.emptyList();
  }

  private String __PostType_enumToString(@NonNull final PostType _value) {
    switch (_value) {
      case ARTICULO: return "ARTICULO";
      case NECESIDAD: return "NECESIDAD";
      default: throw new IllegalArgumentException("Can't convert enum to string, unknown enum value: " + _value);
    }
  }

  private String __ItemCondition_enumToString(@NonNull final ItemCondition _value) {
    switch (_value) {
      case NUEVO: return "NUEVO";
      case COMO_NUEVO: return "COMO_NUEVO";
      case USADO: return "USADO";
      default: throw new IllegalArgumentException("Can't convert enum to string, unknown enum value: " + _value);
    }
  }

  private String __Urgency_enumToString(@NonNull final Urgency _value) {
    switch (_value) {
      case ALTA: return "ALTA";
      case MEDIA: return "MEDIA";
      case BAJA: return "BAJA";
      default: throw new IllegalArgumentException("Can't convert enum to string, unknown enum value: " + _value);
    }
  }

  private String __PostStatus_enumToString(@NonNull final PostStatus _value) {
    switch (_value) {
      case ACTIVA: return "ACTIVA";
      case RESERVADA: return "RESERVADA";
      case CERRADA: return "CERRADA";
      case RETIRADA: return "RETIRADA";
      default: throw new IllegalArgumentException("Can't convert enum to string, unknown enum value: " + _value);
    }
  }

  private String __RequestStatus_enumToString(@NonNull final RequestStatus _value) {
    switch (_value) {
      case PENDIENTE: return "PENDIENTE";
      case ACEPTADA: return "ACEPTADA";
      case RECHAZADA: return "RECHAZADA";
      case RETIRADA: return "RETIRADA";
      default: throw new IllegalArgumentException("Can't convert enum to string, unknown enum value: " + _value);
    }
  }

  private String __DonationStatus_enumToString(@NonNull final DonationStatus _value) {
    switch (_value) {
      case ACEPTADA: return "ACEPTADA";
      case ENTREGADA: return "ENTREGADA";
      case FINALIZADA: return "FINALIZADA";
      case CANCELADA: return "CANCELADA";
      default: throw new IllegalArgumentException("Can't convert enum to string, unknown enum value: " + _value);
    }
  }

  private PostType __PostType_stringToEnum(@NonNull final String _value) {
    switch (_value) {
      case "ARTICULO": return PostType.ARTICULO;
      case "NECESIDAD": return PostType.NECESIDAD;
      default: throw new IllegalArgumentException("Can't convert value to enum, unknown value: " + _value);
    }
  }

  private ItemCondition __ItemCondition_stringToEnum(@NonNull final String _value) {
    switch (_value) {
      case "NUEVO": return ItemCondition.NUEVO;
      case "COMO_NUEVO": return ItemCondition.COMO_NUEVO;
      case "USADO": return ItemCondition.USADO;
      default: throw new IllegalArgumentException("Can't convert value to enum, unknown value: " + _value);
    }
  }

  private Urgency __Urgency_stringToEnum(@NonNull final String _value) {
    switch (_value) {
      case "ALTA": return Urgency.ALTA;
      case "MEDIA": return Urgency.MEDIA;
      case "BAJA": return Urgency.BAJA;
      default: throw new IllegalArgumentException("Can't convert value to enum, unknown value: " + _value);
    }
  }

  private PostStatus __PostStatus_stringToEnum(@NonNull final String _value) {
    switch (_value) {
      case "ACTIVA": return PostStatus.ACTIVA;
      case "RESERVADA": return PostStatus.RESERVADA;
      case "CERRADA": return PostStatus.CERRADA;
      case "RETIRADA": return PostStatus.RETIRADA;
      default: throw new IllegalArgumentException("Can't convert value to enum, unknown value: " + _value);
    }
  }

  private RequestStatus __RequestStatus_stringToEnum(@NonNull final String _value) {
    switch (_value) {
      case "PENDIENTE": return RequestStatus.PENDIENTE;
      case "ACEPTADA": return RequestStatus.ACEPTADA;
      case "RECHAZADA": return RequestStatus.RECHAZADA;
      case "RETIRADA": return RequestStatus.RETIRADA;
      default: throw new IllegalArgumentException("Can't convert value to enum, unknown value: " + _value);
    }
  }

  private DonationStatus __DonationStatus_stringToEnum(@NonNull final String _value) {
    switch (_value) {
      case "ACEPTADA": return DonationStatus.ACEPTADA;
      case "ENTREGADA": return DonationStatus.ENTREGADA;
      case "FINALIZADA": return DonationStatus.FINALIZADA;
      case "CANCELADA": return DonationStatus.CANCELADA;
      default: throw new IllegalArgumentException("Can't convert value to enum, unknown value: " + _value);
    }
  }
}
