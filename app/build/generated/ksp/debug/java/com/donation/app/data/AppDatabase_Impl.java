package com.donation.app.data;

import androidx.annotation.NonNull;
import androidx.room.DatabaseConfiguration;
import androidx.room.InvalidationTracker;
import androidx.room.RoomDatabase;
import androidx.room.RoomOpenHelper;
import androidx.room.migration.AutoMigrationSpec;
import androidx.room.migration.Migration;
import androidx.room.util.DBUtil;
import androidx.room.util.TableInfo;
import androidx.sqlite.db.SupportSQLiteDatabase;
import androidx.sqlite.db.SupportSQLiteOpenHelper;
import java.lang.Class;
import java.lang.Override;
import java.lang.String;
import java.lang.SuppressWarnings;
import java.util.ArrayList;
import java.util.Arrays;
import java.util.HashMap;
import java.util.HashSet;
import java.util.List;
import java.util.Map;
import java.util.Set;
import javax.annotation.processing.Generated;

@Generated("androidx.room.RoomProcessor")
@SuppressWarnings({"unchecked", "deprecation"})
public final class AppDatabase_Impl extends AppDatabase {
  private volatile AppDao _appDao;

  @Override
  @NonNull
  protected SupportSQLiteOpenHelper createOpenHelper(@NonNull final DatabaseConfiguration config) {
    final SupportSQLiteOpenHelper.Callback _openCallback = new RoomOpenHelper(config, new RoomOpenHelper.Delegate(1) {
      @Override
      public void createAllTables(@NonNull final SupportSQLiteDatabase db) {
        db.execSQL("CREATE TABLE IF NOT EXISTS `users` (`id` INTEGER PRIMARY KEY AUTOINCREMENT NOT NULL, `username` TEXT NOT NULL, `legalName` TEXT NOT NULL, `email` TEXT NOT NULL, `phone` TEXT NOT NULL, `passwordHash` TEXT NOT NULL, `salt` TEXT NOT NULL, `phoneShared` INTEGER NOT NULL, `createdAt` INTEGER NOT NULL)");
        db.execSQL("CREATE UNIQUE INDEX IF NOT EXISTS `index_users_username` ON `users` (`username`)");
        db.execSQL("CREATE UNIQUE INDEX IF NOT EXISTS `index_users_email` ON `users` (`email`)");
        db.execSQL("CREATE TABLE IF NOT EXISTS `posts` (`id` INTEGER PRIMARY KEY AUTOINCREMENT NOT NULL, `type` TEXT NOT NULL, `title` TEXT NOT NULL, `description` TEXT NOT NULL, `category` TEXT NOT NULL, `quantity` INTEGER NOT NULL, `condition` TEXT, `urgency` TEXT, `features` TEXT NOT NULL, `location` TEXT NOT NULL, `photoPaths` TEXT NOT NULL, `authorId` INTEGER NOT NULL, `status` TEXT NOT NULL, `createdAt` INTEGER NOT NULL)");
        db.execSQL("CREATE INDEX IF NOT EXISTS `index_posts_authorId` ON `posts` (`authorId`)");
        db.execSQL("CREATE INDEX IF NOT EXISTS `index_posts_status` ON `posts` (`status`)");
        db.execSQL("CREATE TABLE IF NOT EXISTS `requests` (`id` INTEGER PRIMARY KEY AUTOINCREMENT NOT NULL, `postId` INTEGER NOT NULL, `requesterId` INTEGER NOT NULL, `message` TEXT NOT NULL, `status` TEXT NOT NULL, `clientKey` TEXT NOT NULL, `createdAt` INTEGER NOT NULL)");
        db.execSQL("CREATE INDEX IF NOT EXISTS `index_requests_postId` ON `requests` (`postId`)");
        db.execSQL("CREATE INDEX IF NOT EXISTS `index_requests_requesterId` ON `requests` (`requesterId`)");
        db.execSQL("CREATE UNIQUE INDEX IF NOT EXISTS `index_requests_clientKey` ON `requests` (`clientKey`)");
        db.execSQL("CREATE TABLE IF NOT EXISTS `donations` (`id` INTEGER PRIMARY KEY AUTOINCREMENT NOT NULL, `postId` INTEGER NOT NULL, `requestId` INTEGER NOT NULL, `donorId` INTEGER NOT NULL, `doneeId` INTEGER NOT NULL, `status` TEXT NOT NULL, `deliveredAt` INTEGER, `finalizedAt` INTEGER, `cancelReason` TEXT, `createdAt` INTEGER NOT NULL)");
        db.execSQL("CREATE UNIQUE INDEX IF NOT EXISTS `index_donations_requestId` ON `donations` (`requestId`)");
        db.execSQL("CREATE INDEX IF NOT EXISTS `index_donations_donorId` ON `donations` (`donorId`)");
        db.execSQL("CREATE INDEX IF NOT EXISTS `index_donations_doneeId` ON `donations` (`doneeId`)");
        db.execSQL("CREATE TABLE IF NOT EXISTS `status_changes` (`id` INTEGER PRIMARY KEY AUTOINCREMENT NOT NULL, `donationId` INTEGER NOT NULL, `fromStatus` TEXT, `toStatus` TEXT NOT NULL, `actorId` INTEGER, `timestamp` INTEGER NOT NULL)");
        db.execSQL("CREATE INDEX IF NOT EXISTS `index_status_changes_donationId` ON `status_changes` (`donationId`)");
        db.execSQL("CREATE TABLE IF NOT EXISTS room_master_table (id INTEGER PRIMARY KEY,identity_hash TEXT)");
        db.execSQL("INSERT OR REPLACE INTO room_master_table (id,identity_hash) VALUES(42, '27fde180b5bc66289c350fb8939fe25a')");
      }

      @Override
      public void dropAllTables(@NonNull final SupportSQLiteDatabase db) {
        db.execSQL("DROP TABLE IF EXISTS `users`");
        db.execSQL("DROP TABLE IF EXISTS `posts`");
        db.execSQL("DROP TABLE IF EXISTS `requests`");
        db.execSQL("DROP TABLE IF EXISTS `donations`");
        db.execSQL("DROP TABLE IF EXISTS `status_changes`");
        final List<? extends RoomDatabase.Callback> _callbacks = mCallbacks;
        if (_callbacks != null) {
          for (RoomDatabase.Callback _callback : _callbacks) {
            _callback.onDestructiveMigration(db);
          }
        }
      }

      @Override
      public void onCreate(@NonNull final SupportSQLiteDatabase db) {
        final List<? extends RoomDatabase.Callback> _callbacks = mCallbacks;
        if (_callbacks != null) {
          for (RoomDatabase.Callback _callback : _callbacks) {
            _callback.onCreate(db);
          }
        }
      }

      @Override
      public void onOpen(@NonNull final SupportSQLiteDatabase db) {
        mDatabase = db;
        internalInitInvalidationTracker(db);
        final List<? extends RoomDatabase.Callback> _callbacks = mCallbacks;
        if (_callbacks != null) {
          for (RoomDatabase.Callback _callback : _callbacks) {
            _callback.onOpen(db);
          }
        }
      }

      @Override
      public void onPreMigrate(@NonNull final SupportSQLiteDatabase db) {
        DBUtil.dropFtsSyncTriggers(db);
      }

      @Override
      public void onPostMigrate(@NonNull final SupportSQLiteDatabase db) {
      }

      @Override
      @NonNull
      public RoomOpenHelper.ValidationResult onValidateSchema(
          @NonNull final SupportSQLiteDatabase db) {
        final HashMap<String, TableInfo.Column> _columnsUsers = new HashMap<String, TableInfo.Column>(9);
        _columnsUsers.put("id", new TableInfo.Column("id", "INTEGER", true, 1, null, TableInfo.CREATED_FROM_ENTITY));
        _columnsUsers.put("username", new TableInfo.Column("username", "TEXT", true, 0, null, TableInfo.CREATED_FROM_ENTITY));
        _columnsUsers.put("legalName", new TableInfo.Column("legalName", "TEXT", true, 0, null, TableInfo.CREATED_FROM_ENTITY));
        _columnsUsers.put("email", new TableInfo.Column("email", "TEXT", true, 0, null, TableInfo.CREATED_FROM_ENTITY));
        _columnsUsers.put("phone", new TableInfo.Column("phone", "TEXT", true, 0, null, TableInfo.CREATED_FROM_ENTITY));
        _columnsUsers.put("passwordHash", new TableInfo.Column("passwordHash", "TEXT", true, 0, null, TableInfo.CREATED_FROM_ENTITY));
        _columnsUsers.put("salt", new TableInfo.Column("salt", "TEXT", true, 0, null, TableInfo.CREATED_FROM_ENTITY));
        _columnsUsers.put("phoneShared", new TableInfo.Column("phoneShared", "INTEGER", true, 0, null, TableInfo.CREATED_FROM_ENTITY));
        _columnsUsers.put("createdAt", new TableInfo.Column("createdAt", "INTEGER", true, 0, null, TableInfo.CREATED_FROM_ENTITY));
        final HashSet<TableInfo.ForeignKey> _foreignKeysUsers = new HashSet<TableInfo.ForeignKey>(0);
        final HashSet<TableInfo.Index> _indicesUsers = new HashSet<TableInfo.Index>(2);
        _indicesUsers.add(new TableInfo.Index("index_users_username", true, Arrays.asList("username"), Arrays.asList("ASC")));
        _indicesUsers.add(new TableInfo.Index("index_users_email", true, Arrays.asList("email"), Arrays.asList("ASC")));
        final TableInfo _infoUsers = new TableInfo("users", _columnsUsers, _foreignKeysUsers, _indicesUsers);
        final TableInfo _existingUsers = TableInfo.read(db, "users");
        if (!_infoUsers.equals(_existingUsers)) {
          return new RoomOpenHelper.ValidationResult(false, "users(com.donation.app.data.UserEntity).\n"
                  + " Expected:\n" + _infoUsers + "\n"
                  + " Found:\n" + _existingUsers);
        }
        final HashMap<String, TableInfo.Column> _columnsPosts = new HashMap<String, TableInfo.Column>(14);
        _columnsPosts.put("id", new TableInfo.Column("id", "INTEGER", true, 1, null, TableInfo.CREATED_FROM_ENTITY));
        _columnsPosts.put("type", new TableInfo.Column("type", "TEXT", true, 0, null, TableInfo.CREATED_FROM_ENTITY));
        _columnsPosts.put("title", new TableInfo.Column("title", "TEXT", true, 0, null, TableInfo.CREATED_FROM_ENTITY));
        _columnsPosts.put("description", new TableInfo.Column("description", "TEXT", true, 0, null, TableInfo.CREATED_FROM_ENTITY));
        _columnsPosts.put("category", new TableInfo.Column("category", "TEXT", true, 0, null, TableInfo.CREATED_FROM_ENTITY));
        _columnsPosts.put("quantity", new TableInfo.Column("quantity", "INTEGER", true, 0, null, TableInfo.CREATED_FROM_ENTITY));
        _columnsPosts.put("condition", new TableInfo.Column("condition", "TEXT", false, 0, null, TableInfo.CREATED_FROM_ENTITY));
        _columnsPosts.put("urgency", new TableInfo.Column("urgency", "TEXT", false, 0, null, TableInfo.CREATED_FROM_ENTITY));
        _columnsPosts.put("features", new TableInfo.Column("features", "TEXT", true, 0, null, TableInfo.CREATED_FROM_ENTITY));
        _columnsPosts.put("location", new TableInfo.Column("location", "TEXT", true, 0, null, TableInfo.CREATED_FROM_ENTITY));
        _columnsPosts.put("photoPaths", new TableInfo.Column("photoPaths", "TEXT", true, 0, null, TableInfo.CREATED_FROM_ENTITY));
        _columnsPosts.put("authorId", new TableInfo.Column("authorId", "INTEGER", true, 0, null, TableInfo.CREATED_FROM_ENTITY));
        _columnsPosts.put("status", new TableInfo.Column("status", "TEXT", true, 0, null, TableInfo.CREATED_FROM_ENTITY));
        _columnsPosts.put("createdAt", new TableInfo.Column("createdAt", "INTEGER", true, 0, null, TableInfo.CREATED_FROM_ENTITY));
        final HashSet<TableInfo.ForeignKey> _foreignKeysPosts = new HashSet<TableInfo.ForeignKey>(0);
        final HashSet<TableInfo.Index> _indicesPosts = new HashSet<TableInfo.Index>(2);
        _indicesPosts.add(new TableInfo.Index("index_posts_authorId", false, Arrays.asList("authorId"), Arrays.asList("ASC")));
        _indicesPosts.add(new TableInfo.Index("index_posts_status", false, Arrays.asList("status"), Arrays.asList("ASC")));
        final TableInfo _infoPosts = new TableInfo("posts", _columnsPosts, _foreignKeysPosts, _indicesPosts);
        final TableInfo _existingPosts = TableInfo.read(db, "posts");
        if (!_infoPosts.equals(_existingPosts)) {
          return new RoomOpenHelper.ValidationResult(false, "posts(com.donation.app.data.PostEntity).\n"
                  + " Expected:\n" + _infoPosts + "\n"
                  + " Found:\n" + _existingPosts);
        }
        final HashMap<String, TableInfo.Column> _columnsRequests = new HashMap<String, TableInfo.Column>(7);
        _columnsRequests.put("id", new TableInfo.Column("id", "INTEGER", true, 1, null, TableInfo.CREATED_FROM_ENTITY));
        _columnsRequests.put("postId", new TableInfo.Column("postId", "INTEGER", true, 0, null, TableInfo.CREATED_FROM_ENTITY));
        _columnsRequests.put("requesterId", new TableInfo.Column("requesterId", "INTEGER", true, 0, null, TableInfo.CREATED_FROM_ENTITY));
        _columnsRequests.put("message", new TableInfo.Column("message", "TEXT", true, 0, null, TableInfo.CREATED_FROM_ENTITY));
        _columnsRequests.put("status", new TableInfo.Column("status", "TEXT", true, 0, null, TableInfo.CREATED_FROM_ENTITY));
        _columnsRequests.put("clientKey", new TableInfo.Column("clientKey", "TEXT", true, 0, null, TableInfo.CREATED_FROM_ENTITY));
        _columnsRequests.put("createdAt", new TableInfo.Column("createdAt", "INTEGER", true, 0, null, TableInfo.CREATED_FROM_ENTITY));
        final HashSet<TableInfo.ForeignKey> _foreignKeysRequests = new HashSet<TableInfo.ForeignKey>(0);
        final HashSet<TableInfo.Index> _indicesRequests = new HashSet<TableInfo.Index>(3);
        _indicesRequests.add(new TableInfo.Index("index_requests_postId", false, Arrays.asList("postId"), Arrays.asList("ASC")));
        _indicesRequests.add(new TableInfo.Index("index_requests_requesterId", false, Arrays.asList("requesterId"), Arrays.asList("ASC")));
        _indicesRequests.add(new TableInfo.Index("index_requests_clientKey", true, Arrays.asList("clientKey"), Arrays.asList("ASC")));
        final TableInfo _infoRequests = new TableInfo("requests", _columnsRequests, _foreignKeysRequests, _indicesRequests);
        final TableInfo _existingRequests = TableInfo.read(db, "requests");
        if (!_infoRequests.equals(_existingRequests)) {
          return new RoomOpenHelper.ValidationResult(false, "requests(com.donation.app.data.RequestEntity).\n"
                  + " Expected:\n" + _infoRequests + "\n"
                  + " Found:\n" + _existingRequests);
        }
        final HashMap<String, TableInfo.Column> _columnsDonations = new HashMap<String, TableInfo.Column>(10);
        _columnsDonations.put("id", new TableInfo.Column("id", "INTEGER", true, 1, null, TableInfo.CREATED_FROM_ENTITY));
        _columnsDonations.put("postId", new TableInfo.Column("postId", "INTEGER", true, 0, null, TableInfo.CREATED_FROM_ENTITY));
        _columnsDonations.put("requestId", new TableInfo.Column("requestId", "INTEGER", true, 0, null, TableInfo.CREATED_FROM_ENTITY));
        _columnsDonations.put("donorId", new TableInfo.Column("donorId", "INTEGER", true, 0, null, TableInfo.CREATED_FROM_ENTITY));
        _columnsDonations.put("doneeId", new TableInfo.Column("doneeId", "INTEGER", true, 0, null, TableInfo.CREATED_FROM_ENTITY));
        _columnsDonations.put("status", new TableInfo.Column("status", "TEXT", true, 0, null, TableInfo.CREATED_FROM_ENTITY));
        _columnsDonations.put("deliveredAt", new TableInfo.Column("deliveredAt", "INTEGER", false, 0, null, TableInfo.CREATED_FROM_ENTITY));
        _columnsDonations.put("finalizedAt", new TableInfo.Column("finalizedAt", "INTEGER", false, 0, null, TableInfo.CREATED_FROM_ENTITY));
        _columnsDonations.put("cancelReason", new TableInfo.Column("cancelReason", "TEXT", false, 0, null, TableInfo.CREATED_FROM_ENTITY));
        _columnsDonations.put("createdAt", new TableInfo.Column("createdAt", "INTEGER", true, 0, null, TableInfo.CREATED_FROM_ENTITY));
        final HashSet<TableInfo.ForeignKey> _foreignKeysDonations = new HashSet<TableInfo.ForeignKey>(0);
        final HashSet<TableInfo.Index> _indicesDonations = new HashSet<TableInfo.Index>(3);
        _indicesDonations.add(new TableInfo.Index("index_donations_requestId", true, Arrays.asList("requestId"), Arrays.asList("ASC")));
        _indicesDonations.add(new TableInfo.Index("index_donations_donorId", false, Arrays.asList("donorId"), Arrays.asList("ASC")));
        _indicesDonations.add(new TableInfo.Index("index_donations_doneeId", false, Arrays.asList("doneeId"), Arrays.asList("ASC")));
        final TableInfo _infoDonations = new TableInfo("donations", _columnsDonations, _foreignKeysDonations, _indicesDonations);
        final TableInfo _existingDonations = TableInfo.read(db, "donations");
        if (!_infoDonations.equals(_existingDonations)) {
          return new RoomOpenHelper.ValidationResult(false, "donations(com.donation.app.data.DonationEntity).\n"
                  + " Expected:\n" + _infoDonations + "\n"
                  + " Found:\n" + _existingDonations);
        }
        final HashMap<String, TableInfo.Column> _columnsStatusChanges = new HashMap<String, TableInfo.Column>(6);
        _columnsStatusChanges.put("id", new TableInfo.Column("id", "INTEGER", true, 1, null, TableInfo.CREATED_FROM_ENTITY));
        _columnsStatusChanges.put("donationId", new TableInfo.Column("donationId", "INTEGER", true, 0, null, TableInfo.CREATED_FROM_ENTITY));
        _columnsStatusChanges.put("fromStatus", new TableInfo.Column("fromStatus", "TEXT", false, 0, null, TableInfo.CREATED_FROM_ENTITY));
        _columnsStatusChanges.put("toStatus", new TableInfo.Column("toStatus", "TEXT", true, 0, null, TableInfo.CREATED_FROM_ENTITY));
        _columnsStatusChanges.put("actorId", new TableInfo.Column("actorId", "INTEGER", false, 0, null, TableInfo.CREATED_FROM_ENTITY));
        _columnsStatusChanges.put("timestamp", new TableInfo.Column("timestamp", "INTEGER", true, 0, null, TableInfo.CREATED_FROM_ENTITY));
        final HashSet<TableInfo.ForeignKey> _foreignKeysStatusChanges = new HashSet<TableInfo.ForeignKey>(0);
        final HashSet<TableInfo.Index> _indicesStatusChanges = new HashSet<TableInfo.Index>(1);
        _indicesStatusChanges.add(new TableInfo.Index("index_status_changes_donationId", false, Arrays.asList("donationId"), Arrays.asList("ASC")));
        final TableInfo _infoStatusChanges = new TableInfo("status_changes", _columnsStatusChanges, _foreignKeysStatusChanges, _indicesStatusChanges);
        final TableInfo _existingStatusChanges = TableInfo.read(db, "status_changes");
        if (!_infoStatusChanges.equals(_existingStatusChanges)) {
          return new RoomOpenHelper.ValidationResult(false, "status_changes(com.donation.app.data.StatusChangeEntity).\n"
                  + " Expected:\n" + _infoStatusChanges + "\n"
                  + " Found:\n" + _existingStatusChanges);
        }
        return new RoomOpenHelper.ValidationResult(true, null);
      }
    }, "27fde180b5bc66289c350fb8939fe25a", "3dae8430c61dc1c4f2c50839ad3e05f3");
    final SupportSQLiteOpenHelper.Configuration _sqliteConfig = SupportSQLiteOpenHelper.Configuration.builder(config.context).name(config.name).callback(_openCallback).build();
    final SupportSQLiteOpenHelper _helper = config.sqliteOpenHelperFactory.create(_sqliteConfig);
    return _helper;
  }

  @Override
  @NonNull
  protected InvalidationTracker createInvalidationTracker() {
    final HashMap<String, String> _shadowTablesMap = new HashMap<String, String>(0);
    final HashMap<String, Set<String>> _viewTables = new HashMap<String, Set<String>>(0);
    return new InvalidationTracker(this, _shadowTablesMap, _viewTables, "users","posts","requests","donations","status_changes");
  }

  @Override
  public void clearAllTables() {
    super.assertNotMainThread();
    final SupportSQLiteDatabase _db = super.getOpenHelper().getWritableDatabase();
    try {
      super.beginTransaction();
      _db.execSQL("DELETE FROM `users`");
      _db.execSQL("DELETE FROM `posts`");
      _db.execSQL("DELETE FROM `requests`");
      _db.execSQL("DELETE FROM `donations`");
      _db.execSQL("DELETE FROM `status_changes`");
      super.setTransactionSuccessful();
    } finally {
      super.endTransaction();
      _db.query("PRAGMA wal_checkpoint(FULL)").close();
      if (!_db.inTransaction()) {
        _db.execSQL("VACUUM");
      }
    }
  }

  @Override
  @NonNull
  protected Map<Class<?>, List<Class<?>>> getRequiredTypeConverters() {
    final HashMap<Class<?>, List<Class<?>>> _typeConvertersMap = new HashMap<Class<?>, List<Class<?>>>();
    _typeConvertersMap.put(AppDao.class, AppDao_Impl.getRequiredConverters());
    return _typeConvertersMap;
  }

  @Override
  @NonNull
  public Set<Class<? extends AutoMigrationSpec>> getRequiredAutoMigrationSpecs() {
    final HashSet<Class<? extends AutoMigrationSpec>> _autoMigrationSpecsSet = new HashSet<Class<? extends AutoMigrationSpec>>();
    return _autoMigrationSpecsSet;
  }

  @Override
  @NonNull
  public List<Migration> getAutoMigrations(
      @NonNull final Map<Class<? extends AutoMigrationSpec>, AutoMigrationSpec> autoMigrationSpecs) {
    final List<Migration> _autoMigrations = new ArrayList<Migration>();
    return _autoMigrations;
  }

  @Override
  public AppDao dao() {
    if (_appDao != null) {
      return _appDao;
    } else {
      synchronized(this) {
        if(_appDao == null) {
          _appDao = new AppDao_Impl(this);
        }
        return _appDao;
      }
    }
  }
}
