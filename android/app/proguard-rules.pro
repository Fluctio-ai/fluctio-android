# workmanager 0.6.0's androidx.work has a known R8 gap: WorkDatabase (a
# Room @Database class) is instantiated reflectively via its generated
# WorkDatabase_Impl (whose constructor takes arguments — the keep must
# carry bodies, not just class names), and the bundled consumer rules
# don't keep the hierarchy. Release builds crash on launch with "Failed
# to create an instance of class androidx.work.impl.WorkDatabase".
-keep class androidx.work.impl.WorkDatabase* { *; }
-keep class * extends androidx.room.RoomDatabase { *; }
