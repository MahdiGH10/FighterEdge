# Fighter Edge release code shrinking (audit R-11).
#
# Firebase, Play Services, RevenueCat and flutter_local_notifications each
# ship their own consumer rules inside their AARs, which R8 applies
# automatically on top of this file. There is nothing project-specific to
# add yet: the app's own models use hand-written toJson/fromJson rather
# than reflection, and there are no deferred components.
#
# If a release build ever throws a ClassNotFoundException or
# NoSuchMethodError that a debug build does not, add a narrow -keep rule
# for that exact class here rather than turning shrinking off.

# Room builds its generated databases by reflection, through the no-argument
# constructor. WorkManager (a transitive dependency) has one:
# androidx.work.impl.WorkDatabase_Impl. R8 keeps the class but strips
# that constructor, because nothing calls it directly. The release APK then
# crashed on launch, before any Flutter code ran, in
# androidx.startup.InitializationProvider ("Failed to create an instance of
# androidx.work.impl.WorkDatabase"). Debug builds do not shrink, so only the
# release build hit it.
-keep class * extends androidx.room.RoomDatabase { <init>(); }
