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
