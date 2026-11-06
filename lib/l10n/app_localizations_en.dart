// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get habitTypeLockedHint =>
      'Habit type cannot be changed after creation';

  @override
  String get settingsTitle => 'Account & settings';

  @override
  String get account => 'Account';

  @override
  String get profile => 'Profile';

  @override
  String get appearance => 'Appearance';

  @override
  String get system => 'System';

  @override
  String get light => 'Light';

  @override
  String get dark => 'Dark';

  @override
  String get language => 'Language';

  @override
  String get english => 'English';

  @override
  String get russian => 'Russian';

  @override
  String get kazakh => 'Kazakh';

  @override
  String get accentColor => 'Accent color';

  @override
  String get buttonPreview => 'Button';

  @override
  String get accentColorDescription => 'Customize your primary color';

  @override
  String get preview => 'Preview';

  @override
  String get textExample => 'Text example';

  @override
  String get customColor => 'Custom color';

  @override
  String get hue => 'Hue';

  @override
  String get saturation => 'Saturation';

  @override
  String get lightness => 'Lightness';

  @override
  String get presets => 'Presets';

  @override
  String get defaultPreset => 'Default';

  @override
  String get rosePreset => 'Rose';

  @override
  String get emeraldPreset => 'Emerald';

  @override
  String get indigoPreset => 'Indigo';

  @override
  String get coralPreset => 'Coral';

  @override
  String get tealPreset => 'Teal';

  @override
  String get createPreset => 'Create preset';

  @override
  String get presetName => 'Preset name';

  @override
  String get lettersOnly => 'Letters and spaces only';

  @override
  String get max16Symbols => 'Max 16 symbols';

  @override
  String get deletePreset => 'Delete preset';

  @override
  String get presetLimitReached => 'Preset limit reached (22)';

  @override
  String get weekStartsOn => 'Week starts on';

  @override
  String get displayTotalStudyTime =>
      'Display total study time per course over';

  @override
  String get displayProgressBar => 'Display progress bar of';

  @override
  String get quickNotes => 'Quick notes';

  @override
  String get wantToReceiveNudges => 'Want to receive nudges?';

  @override
  String get eisenhowerMatrix => 'Eisenhower matrix';

  @override
  String get quickNotesDescription =>
      'Existing notes will stay saved, but no new note popups will appear after sessions.';

  @override
  String get wantToReceiveNudgesDescription =>
      'Allow group members to send you gentle nudges to stay on track.';

  @override
  String get eisenhowerMatrixDescription =>
      'Use the Eisenhower matrix on the Habits screen to organize habits by urgency and importance.';

  @override
  String get sessionNotification => 'Session notification';

  @override
  String get sessionNotificationDescription =>
      'Show session controls in the notification bar while recording.';

  @override
  String get eisenhowerQuadrant1 => 'Urgent & Important';

  @override
  String get eisenhowerQuadrant2 => 'Not urgent & Important';

  @override
  String get eisenhowerQuadrant3 => 'Urgent & Not important';

  @override
  String get eisenhowerQuadrant4 => 'Not urgent & Not important';

  @override
  String get eisenhowerHint => 'Drag habits into the matrix to organize them';

  @override
  String get yes => 'Yes';

  @override
  String get no => 'No';

  @override
  String get data => 'Data';

  @override
  String get exportToCalendar => 'Export to calendar';

  @override
  String exportWillStartIn(int seconds) {
    return 'Export will start in $seconds seconds';
  }

  @override
  String get exportToCalendarSubtitle =>
      'Save your sessions as calendar events';

  @override
  String get allCourses => 'All courses';

  @override
  String get courseFallback => 'Course';

  @override
  String get export => 'Export';

  @override
  String get exporting => 'Exporting...';

  @override
  String exportFailedMessage(String error) {
    return 'Export failed: $error';
  }

  @override
  String sessionsFound(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count sessions found',
      one: '1 session found',
      zero: 'No sessions found',
    );
    return '$_temp0';
  }

  @override
  String habitReportDownloadCountdown(int seconds) {
    return 'Report generation will start in $seconds seconds';
  }

  @override
  String get fileSavedSuccessfully => 'File generated successfully';

  @override
  String get fileSavedAt => 'The file is saved at:';

  @override
  String get unknownPath => 'Unknown path';

  @override
  String get nextSteps => 'Next steps:';

  @override
  String get exportCalendarNextStepsBody =>
      '• Open this file and import it into your calendar app,\n• OR open your calendar app settings and import the file manually.';

  @override
  String get deleteAccount => 'Delete account';

  @override
  String get deleteAccountSubtitle =>
      'Permanently delete your account and all data';

  @override
  String get deleteAccountHoldConfirmDetail =>
      'After holding the button for 5 seconds the account will be deleted forever';

  @override
  String get deletingAccount => 'Deleting account...';

  @override
  String get deleteAccountPasswordTitle =>
      'Enter your password to delete the account';

  @override
  String get deleteAccountWrongPassword => 'Wrong password. Try again.';

  @override
  String get deleteAccountNetworkError => 'No connection. Try again.';

  @override
  String get deleteAccountFailed => 'Could not delete the account. Try again.';

  @override
  String get accountDeleted => 'Account deleted';

  @override
  String get pleaseSignInToViewAccount =>
      'Please sign in to view your account.';

  @override
  String get signOut => 'Sign out';

  @override
  String get syncNow => 'Sync now';

  @override
  String get syncing => 'Syncing';

  @override
  String get home => 'Home';

  @override
  String get statistics => 'Statistics';

  @override
  String get groups => 'Groups';

  @override
  String get addCourse => 'Add course';

  @override
  String get addTime => 'Add time';

  @override
  String get courseName => 'Course name';

  @override
  String get courseNameHint => '';

  @override
  String get required => 'Required';

  @override
  String get color => 'Color';

  @override
  String get creditsOptional => 'Credits (optional)';

  @override
  String get creditsHint => '6 or 7 for example';

  @override
  String get creditsHelper => 'Add credits to enable self-study goals';

  @override
  String get experienceLevel => 'Experience level';

  @override
  String get save => 'Save';

  @override
  String get cancel => 'Cancel';

  @override
  String get delete => 'Delete';

  @override
  String get deleteCourseTitle => 'Delete course';

  @override
  String get deleteCourseMessage =>
      'Are you sure? All data for this course will be deleted.';

  @override
  String timeSavedMessage(String courseName) {
    return 'Time for \"$courseName\" saved';
  }

  @override
  String get aiAnalysisComingSoon => 'Course analysis is coming soon.';

  @override
  String get courseAnalysis => 'Course analysis';

  @override
  String get noCoursesAvailable => 'No courses available.';

  @override
  String get selectCourse => 'Select course';

  @override
  String get sixMonths => '6 months';

  @override
  String get analysisUpdatesEveryPeriod =>
      'Your analysis updates every new period.';

  @override
  String get analysisAlreadyGenerated =>
      'You\'ve already generated an analysis for this period.';

  @override
  String get dayStatsTipLine1 =>
      '• The calendar highlights your study activity. The greener the day, the more you studied.';

  @override
  String get dayStatsTipLine2 =>
      '• You can edit session time and notes in the History screen.';

  @override
  String get dayStatsTipLine3 =>
      '• You can tap on any course, and the history screen will show only the sessions for that course.';

  @override
  String get syncOffline => 'Offline';

  @override
  String get syncSyncing => 'Syncing…';

  @override
  String get syncUpToDate => 'Up to date';

  @override
  String get setGoals => 'Set goals';

  @override
  String get daily => 'Daily';

  @override
  String get weekly => 'Weekly';

  @override
  String get studyTimer => 'Study timer';

  @override
  String get noCoursesYet => 'No courses yet. Add a course from Home.';

  @override
  String get chooseACourse => 'Choose a course';

  @override
  String get start => 'Start';

  @override
  String get stop => 'Stop';

  @override
  String get reset => 'Reset';

  @override
  String get ok => 'OK';

  @override
  String get timerStoppedAndSaved => 'Timer stopped and saved.';

  @override
  String get nothingToReset => 'Nothing to reset.';

  @override
  String anotherSessionRunning(String sessionType) {
    return 'Another $sessionType is already running.';
  }

  @override
  String anotherSessionRunningOn(String sessionType, String courseName) {
    return 'Another $sessionType is already running on \"$courseName\".';
  }

  @override
  String anotherSessionRunningSilly(String sessionType) {
    return 'Another $sessionType is already running, silly.';
  }

  @override
  String get alreadyStudiedThisPeriod =>
      'You already studied during this time period.';

  @override
  String get friendJoinPrompt =>
      'Your friend can join by typing your group’s name into the search bar.';

  @override
  String get enterTimeFirst => 'Enter time first';

  @override
  String get nothingToSave => 'Nothing to save';

  @override
  String get maxTimeCapped => 'Max is 3:00:00 — capped';

  @override
  String get studiedLabel => 'Studied';

  @override
  String get goalsUpdated => 'Goals updated';

  @override
  String get studiedToday => 'Studied today';

  @override
  String get studiedThisWeek => 'Studied this week';

  @override
  String get studiedThisMonth => 'Studied this month';

  @override
  String get studiedThisYear => 'Studied this year';

  @override
  String get studiedOverall => 'Studied overall';

  @override
  String get timer => 'timer';

  @override
  String get stopwatch => 'stopwatch';

  @override
  String get pomodoro => 'pomodoro';

  @override
  String get session => 'session';

  @override
  String get editCourse => 'Edit course';

  @override
  String get today => 'Today';

  @override
  String get edit => 'Edit';

  @override
  String get timerTab => 'Timer';

  @override
  String get stopwatchTab => 'Stopwatch';

  @override
  String get pomodoroTab => 'Pomodoro';

  @override
  String get typeTimeToStudy => 'Here type the time you need to study for';

  @override
  String get maxTime => 'Max: 3:00:00';

  @override
  String get elapsed => 'elapsed';

  @override
  String completedPomodoros(int completed) {
    return 'Completed pomodoros: $completed / 4';
  }

  @override
  String longBreakLength(int minutes) {
    return 'Long break length ($minutes min)';
  }

  @override
  String get work => 'Work';

  @override
  String get shortBreak => 'Short break';

  @override
  String get longBreak => 'Long break';

  @override
  String get paused => 'paused';

  @override
  String get resume => 'Resume';

  @override
  String get pause => 'Pause';

  @override
  String get skipBreak => 'Skip break';

  @override
  String get pomodoroExitWarning =>
      'A pomodoro session is running. Exit anyway?';

  @override
  String get exitAnyway => 'Exit anyway';

  @override
  String get expLevel1 => 'Complete noob';

  @override
  String get expLevel2 => 'Know some basics';

  @override
  String get expLevel3 => 'Comfortable with the subject';

  @override
  String get expLevel4 => 'Advanced level of knowledge';

  @override
  String get expLevel5 => 'Broad experience';

  @override
  String get expLevelDefault => 'Comfortable';

  @override
  String get dayStatistics => 'Day statistics';

  @override
  String get periodStatistics => 'Period statistics';

  @override
  String get tip => 'Tip';

  @override
  String get chartTip =>
      '• Hold your finger on the chart and slide left or right to move between days or months.';

  @override
  String get courseStatistics => 'Course statistics';

  @override
  String get previousDay => 'Previous day';

  @override
  String get nextDay => 'Next day';

  @override
  String get history => 'History';

  @override
  String get week => 'Week';

  @override
  String get month => 'Month';

  @override
  String get year => 'Year';

  @override
  String get previousWeek => 'previous week';

  @override
  String get previousMonth => 'previous month';

  @override
  String get previousYear => 'previous year';

  @override
  String get nextWeek => 'next week';

  @override
  String get nextMonth => 'next month';

  @override
  String get nextYear => 'next year';

  @override
  String get noData => 'No data';

  @override
  String get hours => 'Hours';

  @override
  String get minutes => 'Minutes';

  @override
  String totalThisPeriod(String period) {
    return 'Total this $period';
  }

  @override
  String get avgPerDay => 'Average per day';

  @override
  String get mostStudied => 'Most studied';

  @override
  String get leastStudied => 'Least studied';

  @override
  String get adjustWeeklyGoal => 'Adjust weekly goal';

  @override
  String get targetPerWeek => 'Target per week';

  @override
  String get targetPerDay => 'Target per day';

  @override
  String semester(int weeks) {
    return 'Semester (~$weeks wks)';
  }

  @override
  String hPerWeek(String hours) {
    return '$hours h/week';
  }

  @override
  String get createGroup => 'Create group';

  @override
  String get joinGroup => 'Join group';

  @override
  String get groupName => 'Group name';

  @override
  String get description => 'Description';

  @override
  String get privacy => 'Privacy';

  @override
  String get public => 'Public';

  @override
  String get private => 'Private';

  @override
  String get accessCode => 'Access code';

  @override
  String get members => 'Members';

  @override
  String get leaveGroup => 'Leave group';

  @override
  String get deleteGroup => 'Delete group';

  @override
  String get groupSettings => 'Group settings';

  @override
  String get noGroupsYet => 'You\'re not in any groups yet';

  @override
  String get noSearchResults => 'We have nothing like this here';

  @override
  String get createOrJoinPrompt =>
      'Create a new group or join an existing one to collaborate with others';

  @override
  String get signInPrompt => 'Sign in to explore groups.';

  @override
  String errorLoadingMemberships(String error) {
    return 'Error loading memberships: $error';
  }

  @override
  String get findPublicGroupHint => 'Find a group...';

  @override
  String get searchResults => 'Search results';

  @override
  String errorLoadingGroups(String error) {
    return 'Error loading groups: $error';
  }

  @override
  String get joinedSuccessfully => 'Joined group successfully';

  @override
  String get joinedPrivateSuccessfully => 'Joined private group successfully';

  @override
  String joinGroupDialogTitle(String groupName) {
    return 'Join $groupName';
  }

  @override
  String get joinGroupDialogMessage =>
      'Enter the join code to access this private group.';

  @override
  String get joinCodeHint => 'e.g. ABC123';

  @override
  String get publicGroups => 'Public groups';

  @override
  String joinError(String error) {
    return 'Could not join group: $error';
  }

  @override
  String get noDescription => 'No description provided.';

  @override
  String membersCount(int count) {
    return '$count members';
  }

  @override
  String get yourGroup => 'Your group';

  @override
  String get findStudyGroup => 'Find your study group';

  @override
  String get joinCommunityPrompt =>
      'Join a community to track progress, compete on leaderboards, and stay motivated together.';

  @override
  String get administrator => 'Admin';

  @override
  String get memberLabel => 'Member';

  @override
  String get unableToLoadGroup => 'Unable to load group data';

  @override
  String get checkConnection => 'Please check your internet connection';

  @override
  String get retry => 'Retry';

  @override
  String get groupNotFound => 'Group not found or was deleted.';

  @override
  String get signInToManage => 'You need to be signed in to manage this group.';

  @override
  String get noLongerMember => 'You are no longer a member of this group.';

  @override
  String get groupNameHint => 'Enter group name';

  @override
  String get visibility => 'Visibility';

  @override
  String get descriptionHint => 'Describe your group in a few words';

  @override
  String get codeRequired => 'Code is required';

  @override
  String get codeJoinPrompt => 'This code is required for new members to join.';

  @override
  String get onlyAdminVisibility => 'Only administrators can change settings.';

  @override
  String get saving => 'Saving...';

  @override
  String get saveChanges => 'Save changes';

  @override
  String get membersTitle => 'Members';

  @override
  String get unableToLoadMembers => 'Unable to load member list';

  @override
  String get checkConnectionTryAgain =>
      'Please check your connection and try again';

  @override
  String get noMembersYetLabel => 'No members yet.';

  @override
  String get youAdmin => 'You (admin)';

  @override
  String get youMember => 'You';

  @override
  String get youOwner => 'You (owner)';

  @override
  String get removeMemberTitle => 'Remove member?';

  @override
  String get removeMemberMessage =>
      'Remove this member from the group? They will lose access immediately.';

  @override
  String get memberRemoved => 'Member removed';

  @override
  String get groupUpdated => 'Group updated';

  @override
  String failedToUpdateGroup(String error) {
    return 'Failed to update group: $error';
  }

  @override
  String failedToDeleteGroup(String error) {
    return 'Failed to delete group: $error';
  }

  @override
  String failedToLeaveGroup(String error) {
    return 'Failed to leave group: $error';
  }

  @override
  String failedToRemoveMember(String error) {
    return 'Failed to remove member: $error';
  }

  @override
  String get groupCodeLabel => 'Group code';

  @override
  String get dailyGoal => 'Daily';

  @override
  String get weeklyGoal => 'Weekly';

  @override
  String get hUnit => 'h';

  @override
  String get mUnit => 'm';

  @override
  String get sUnit => 's';

  @override
  String errorLoadingLeaderboard(String error) {
    return 'Error loading leaderboard: $error';
  }

  @override
  String get courseHiddenFromLeaderboard =>
      'Course is hidden from the leaderboard.';

  @override
  String get courseVisibleInLeaderboard =>
      'Course is visible in the leaderboard.';

  @override
  String get hideFromLeaderboard => 'Hide from Leaderboard';

  @override
  String get unhideFromLeaderboard => 'Unhide from Leaderboard';

  @override
  String get noDataAvailable => 'No data available for this period';

  @override
  String get groupLeaderboard => 'Group leaderboard';

  @override
  String rankLabel(int rank) {
    return '#$rank';
  }

  @override
  String failedToLoadUserData(String error) {
    return 'Failed to load user data: $error';
  }

  @override
  String get sun => 'Sun';

  @override
  String get mon => 'Mon';

  @override
  String get tue => 'Tue';

  @override
  String get wed => 'Wed';

  @override
  String get thu => 'Thu';

  @override
  String get fri => 'Fri';

  @override
  String get sat => 'Sat';

  @override
  String get sunday => 'Sunday';

  @override
  String get monday => 'Monday';

  @override
  String get tuesday => 'Tuesday';

  @override
  String get wednesday => 'Wednesday';

  @override
  String get thursday => 'Thursday';

  @override
  String get friday => 'Friday';

  @override
  String get saturday => 'Saturday';

  @override
  String get january => 'January';

  @override
  String get february => 'February';

  @override
  String get march => 'March';

  @override
  String get april => 'April';

  @override
  String get may => 'May';

  @override
  String get june => 'June';

  @override
  String get july => 'July';

  @override
  String get august => 'August';

  @override
  String get september => 'September';

  @override
  String get october => 'October';

  @override
  String get november => 'November';

  @override
  String get december => 'December';

  @override
  String get total => 'Total';

  @override
  String get groupSummary => 'Group summary';

  @override
  String get average => 'Average';

  @override
  String get leader => 'Leader';

  @override
  String get lowest => 'Lowest';

  @override
  String get vsAverage => 'vs. average';

  @override
  String get studyTimeComparison => 'Study time comparison';

  @override
  String get performanceVsGroup => 'Performance vs. group';

  @override
  String get ofAverage => 'of average';

  @override
  String get studyTimeByDay => 'Study time by day';

  @override
  String get bestDay => 'Best day';

  @override
  String get avgDay => 'Average/day';

  @override
  String get member => 'Member';

  @override
  String get todayDataTable => 'Today';

  @override
  String get monthDataTable => 'Month';

  @override
  String get overThisWeek => 'over this week';

  @override
  String get overThisMonth => 'over this month';

  @override
  String get overThisYear => 'over this year';

  @override
  String get hour => 'hour';

  @override
  String get hours_plural => 'hours';

  @override
  String get minute => 'minute';

  @override
  String get minutes_plural => 'minutes';

  @override
  String get second => 'second';

  @override
  String get seconds_plural => 'seconds';

  @override
  String get jan => 'Jan';

  @override
  String get feb => 'Feb';

  @override
  String get mar => 'Mar';

  @override
  String get apr => 'Apr';

  @override
  String get mayShort => 'May';

  @override
  String get jun => 'Jun';

  @override
  String get jul => 'Jul';

  @override
  String get aug => 'Aug';

  @override
  String get sep => 'Sep';

  @override
  String get oct => 'Oct';

  @override
  String get nov => 'Nov';

  @override
  String get dec => 'Dec';

  @override
  String get via => 'via';

  @override
  String get viaTimer => 'via Timer';

  @override
  String get viaStopwatch => 'via Stopwatch';

  @override
  String get viaPomodoro => 'via Pomodoro';

  @override
  String get viaManualRecording => 'via manual recording';

  @override
  String get startTime => 'Start';

  @override
  String get endTime => 'End';

  @override
  String get duration => 'Duration';

  @override
  String get reflection => 'Reflection';

  @override
  String get overThis => 'over this';

  @override
  String get credits => 'Credit';

  @override
  String get credits_plural => 'Credits';

  @override
  String get deleteSession => 'Delete session?';

  @override
  String get deleteSessionMessage =>
      'This will remove the session from your history and statistics.';

  @override
  String get sessionDeleted => 'Session deleted';

  @override
  String get leaveGroupTitle => 'Leave group?';

  @override
  String get leaveGroupMessage => 'Are you sure you want to leave this group?';

  @override
  String get leave => 'Leave';

  @override
  String get deleteGroupTitle => 'Delete group?';

  @override
  String get deleteGroupMessage =>
      'This will permanently delete the group for all members.';

  @override
  String get manageGroup => 'Manage group';

  @override
  String get admin => 'Admin';

  @override
  String get removeMember => 'Remove member';

  @override
  String get makeAdmin => 'Make admin';

  @override
  String get removeAdmin => 'Remove admin';

  @override
  String get owner => 'Owner';

  @override
  String get memberPromoted => 'Member promoted to admin';

  @override
  String get adminDemoted => 'Admin demoted to member';

  @override
  String get failedToPromote => 'Failed to promote member';

  @override
  String get failedToDemote => 'Failed to demote member';

  @override
  String get demoteTooltip => 'Demote to member';

  @override
  String get makeAdminTooltip => 'Make admin';

  @override
  String get cannotEnterFutureTime => 'You cannot enter future time.';

  @override
  String get startTimeLaterThanEndTime =>
      'Start time can’t be later than end time.';

  @override
  String timeAddedToCourse(String courseName) {
    return 'Time added to $courseName';
  }

  @override
  String get currentDay => 'current day';

  @override
  String get thisWeekShort => 'this week';

  @override
  String get thisMonthShort => 'this month';

  @override
  String get thisYearShort => 'this year';

  @override
  String get overall => 'overall';

  @override
  String get dayGoalLabel => 'day goal';

  @override
  String get weekGoalLabel => 'week goal';

  @override
  String get on => 'On';

  @override
  String get off => 'Off';

  @override
  String get justSwipeIt => 'Just swipe it';

  @override
  String get customPhotosUnavailable =>
      'Custom photos are temporarily unavailable.';

  @override
  String get unableToPickImage => 'Unable to pick that image.';

  @override
  String get couldNotSaveProfile => 'Could not save profile. Please try again.';

  @override
  String get yourName => 'Your name';

  @override
  String get addPersonalGoal => 'Add a personal goal';

  @override
  String get nameLabel => 'Name';

  @override
  String get nameRequired => 'Name is required';

  @override
  String get majorLabel => 'Major';

  @override
  String get majorRequired => 'Major is required';

  @override
  String get contactLabel => 'How to contact you';

  @override
  String get contactHint => 'Phone number or tg username idk';

  @override
  String get personalGoalLabel => 'Personal goal';

  @override
  String get personalGoalHint => 'Become better';

  @override
  String get chooseAvatar => 'Choose an avatar';

  @override
  String get photoLibraryUnavailable => 'Photo library unavailable';

  @override
  String get iconColor => 'Icon color';

  @override
  String get saved => 'Saved';

  @override
  String get done => 'Done';

  @override
  String get stay => 'Stay';

  @override
  String get resetAndLeave => 'Reset & Leave';

  @override
  String get leavePomodoroTitle => 'Leave pomodoro?';

  @override
  String get leavePomodoroMessage =>
      'A Pomodoro cycle is running. Reset it before leaving this tab?';

  @override
  String get timeFormatHint => 'HH:MM:SS';

  @override
  String get addCourseFirst => 'Add a course first';

  @override
  String invalidTimeFormat(String format) {
    return 'Enter times as $format';
  }

  @override
  String get signIn => 'Sign in';

  @override
  String get register => 'Register';

  @override
  String get loginSubtitle => 'We missed you pal';

  @override
  String get registerSubtitle => '<3';

  @override
  String get emailAddress => 'Email address';

  @override
  String get password => 'Password';

  @override
  String get displayName => 'Display name';

  @override
  String get createAccount => 'Create account';

  @override
  String get afterCreatingAccount =>
      'After creating an account, you\'ll need to verify your email to start using the app.';

  @override
  String get verificationEmailSent => 'Verification email sent!';

  @override
  String get signedInSuccessfully => 'Signed in successfully';

  @override
  String get enterEmail => 'Please enter your email address.';

  @override
  String get invalidEmail => 'Please enter a valid email address.';

  @override
  String get enterPassword => 'Enter your password.';

  @override
  String get displayNameLength => 'Display name must be at least 2 characters.';

  @override
  String get passwordLength => 'Password must be at least 8 characters.';

  @override
  String get passwordInvalidChars =>
      'Only A–Z, a–z, 0–9 and allowed symbols are supported.';

  @override
  String get displayNameInvalidChars =>
      'Display name can contain only letters and numbers.';

  @override
  String get min8Chars => 'Minimum 8 characters.';

  @override
  String get loadingProfile => 'Loading your profile';

  @override
  String get loggingOut => 'Logging out of account...';

  @override
  String get forgotPassword => 'Forgot password?';

  @override
  String get resetPasswordTitle => 'Reset password';

  @override
  String get resetPasswordSubtitle =>
      'Enter your account email. We’ll send a reset link.';

  @override
  String get sendResetLink => 'Send reset link';

  @override
  String get resetLinkSent =>
      'If an account exists for this email, we sent a reset link.';

  @override
  String get backToSignIn => 'Back to sign in';

  @override
  String get verifyEmailFirst =>
      'Please verify your email first. We sent you a verification email.';

  @override
  String get resendVerificationEmail => 'Resend verification email';

  @override
  String get invalidEmailFormat => 'Enter a valid email address.';

  @override
  String get resetRateLimited => 'Please wait a moment before trying again.';

  @override
  String get networkRequestFailed =>
      'Network error. Check your connection and try again.';

  @override
  String get signInToResend => 'Sign in to resend the verification email.';

  @override
  String tryAgainInSeconds(int seconds) {
    return 'Try again in ${seconds}s';
  }

  @override
  String get sessionNotes => 'Session notes';

  @override
  String get sessionNotesHint => 'Add notes for this session';

  @override
  String get sendNotes => 'Send notes';

  @override
  String get updateNotes => 'Update notes';

  @override
  String get notesSaved => 'Notes saved';

  @override
  String get failedToPrepareData => 'Failed to prepare offline data.';

  @override
  String sessionFinished(String duration) {
    return 'Session finished: $duration';
  }

  @override
  String get whatDidYouWorkOn => 'What did you work on?';

  @override
  String failedToSaveReflection(String error) {
    return 'Failed to save reflection: $error';
  }

  @override
  String get skip => 'Skip';

  @override
  String streakDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count days streak',
      one: '$count day streak',
    );
    return '$_temp0';
  }

  @override
  String get noStreakYet => 'No streak yet';

  @override
  String nudgeWaitMinutes(int minutes) {
    String _temp0 = intl.Intl.pluralLogic(
      minutes,
      locale: localeName,
      other: 'minutes',
      one: 'minute',
    );
    return 'Please wait $minutes $_temp0 before nudging again.';
  }

  @override
  String nudgeWaitSeconds(int seconds) {
    String _temp0 = intl.Intl.pluralLogic(
      seconds,
      locale: localeName,
      other: 'seconds',
      one: 'second',
    );
    return 'Please wait $seconds $_temp0 before nudging again.';
  }

  @override
  String get memberCannotReceiveNudges =>
      'This member cannot receive nudges yet.';

  @override
  String get nudgeSent => 'Nudge sent.';

  @override
  String failedToSendNudge(String error) {
    return 'Failed to send nudge: $error';
  }

  @override
  String get cannotNudgeSelf => 'You cannot nudge yourself.';

  @override
  String get userProhibitedNudge => 'This user has disabled nudges.';

  @override
  String get leaderboardHintMessage =>
      '• You can tap any user in the leaderboard to view their study time.\n• Tap the hand icon next to a friend’s avatar to nudge him.';

  @override
  String get habitsNavLabel => 'Habits';

  @override
  String get habitStatistics => 'Habit statistics';

  @override
  String get habitsTabProgress => 'Progress';

  @override
  String get habitsTabList => 'My habits';

  @override
  String get habitsPleaseSignIn => 'Please sign in';

  @override
  String get habitsEmptyToday => 'Nothing to do today. Cheers!';

  @override
  String habitsListError(String error) {
    return 'Error: $error';
  }

  @override
  String get habitsEmptyListTitle => 'No habits yet';

  @override
  String get habitsEmptyListCta => 'Create your first';

  @override
  String get habitRequirementMarkDone => 'Mark as done';

  @override
  String habitRequirementToday(String current, String target, String unit) {
    return '$current / $target $unit today';
  }

  @override
  String habitRequirementTodayNoUnit(String current, String target) {
    return '$current / $target today';
  }

  @override
  String get habitFrequencyEveryDay => 'Every day';

  @override
  String get habitFrequencySpecificMonth => 'Specific days of month';

  @override
  String get habitFrequencySpecificDates => 'Specific dates';

  @override
  String habitFrequencyDaysLabel(String days) {
    return 'Days: $days';
  }

  @override
  String habitFrequencyInterval(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: 'days',
      one: 'day',
    );
    return 'Every $days $_temp0';
  }

  @override
  String habitFrequencyTimesPerPeriod(int count, String period) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count times per $period',
      one: '$count time per $period',
    );
    return '$_temp0';
  }

  @override
  String get habitPeriodWeek => 'Week';

  @override
  String get habitPeriodMonth => 'Month';

  @override
  String get habitPeriodYear => 'Year';

  @override
  String get habitDailyOverview => 'Daily overview';

  @override
  String get habitNoHabitsThisDay => 'No habits completed on this day.';

  @override
  String get habitMinutesShort => 'min';

  @override
  String get habitLogSetTotal => 'Set total';

  @override
  String get habitLogAddMore => 'Add more';

  @override
  String get habitUpdateProgress => 'Update progress';

  @override
  String get habitLogSetValueTitle => 'Set value';

  @override
  String get habitClearTime => 'Clear time';

  @override
  String habitProgressLabel(String date) {
    return 'Progress, $date';
  }

  @override
  String habitLogSettingTotal(String total) {
    return 'Setting total to $total';
  }

  @override
  String habitLogAdding(String value, String existing) {
    return 'Adding $value to $existing';
  }

  @override
  String habitGoalLabel(String goal) {
    return 'Goal: $goal';
  }

  @override
  String get habitCreateTitle => 'Create new habit';

  @override
  String get habitTrackingTitle => 'Tracking type';

  @override
  String get habitExplainHabit => 'Explain your habit';

  @override
  String get habitNameLabel => 'Habit name';

  @override
  String get habitNameHint => '';

  @override
  String get habitCategoryLabel => 'Category';

  @override
  String get habitCategoryNew => 'New category';

  @override
  String get habitCategoryNameLabel => 'Category name';

  @override
  String get habitCategoryNameHint => 'e.g. reading';

  @override
  String get habitCategoryDeleteTitle => 'Delete category';

  @override
  String habitCategoryDeleteMessage(String name) {
    return 'Delete \"$name\"? This cannot be undone.';
  }

  @override
  String get habitCategoryCreateAction => 'Create custom';

  @override
  String get habitBack => 'Back';

  @override
  String get habitNext => 'Next';

  @override
  String get habitYesNo => 'Yes / No';

  @override
  String get habitNumeric => 'Numeric';

  @override
  String get habitTime => 'Time';

  @override
  String get habitTrackingYesNoDescription =>
      'Mark whether you completed the habit or not.';

  @override
  String get habitTrackingNumericDescription =>
      'Set a specific number to reach each day.';

  @override
  String get habitTrackingTimeDescription =>
      'Set a time duration as your daily goal.';

  @override
  String get habitComparatorAtLeast => 'At least';

  @override
  String get habitComparatorLessThan => 'Less than';

  @override
  String get habitComparatorExactly => 'Exactly';

  @override
  String get habitComparatorAny => 'Any value';

  @override
  String get habitValueLabel => 'Value';

  @override
  String get habitUnitLabel => 'Unit';

  @override
  String get habitUnitHint => 'e.g. pages';

  @override
  String get habitPerDay => 'per day';

  @override
  String get habitTimeLabel => 'hours : minutes : seconds';

  @override
  String get habitTimePlaceholder => '00:00:00';

  @override
  String get habitFrequencyPrompt => 'Choose how often the habit should repeat';

  @override
  String get habitFrequencySpecificTitle => 'Specific days';

  @override
  String get habitFrequencyDailyDescription =>
      'Do the habit daily without skipping.';

  @override
  String get habitFrequencySpecificDescription =>
      'Choose exact weekdays or dates.';

  @override
  String get habitFrequencyPeriodWeekLabel => 'Week';

  @override
  String get habitFrequencyPeriodMonthLabel => 'Month';

  @override
  String get habitFrequencyPeriodYearLabel => 'Year';

  @override
  String get habitFrequencyTimesPerPeriodTitle => 'Days per period';

  @override
  String get habitFrequencyTimesPerPeriodDescription =>
      'Set how many days within a week, month, or year.';

  @override
  String get habitTimesPerLabel => 'times per';

  @override
  String get habitFrequencyWorkRestTitle => 'Work / Rest';

  @override
  String get habitFrequencyWorkRestDescription =>
      'Set a repeating cycle for the habit. Work — days when you do the habit. Rest — days off.';

  @override
  String get habitWorkLabel => 'Work';

  @override
  String get habitRestLabel => 'Rest';

  @override
  String get habitChooseTimeRangeTitle =>
      'Choose the time range when you want to start';

  @override
  String get habitSchedulingTitle => 'Scheduling';

  @override
  String get habitStartDateLabel => 'Start date';

  @override
  String get habitEndDateLabel => 'End date (optional)';

  @override
  String get habitNoEndDate => 'No end date';

  @override
  String get habitCreateAction => 'Create habit';

  @override
  String get habitForever => 'Forever';

  @override
  String get habitAddDateAction => 'Add date';

  @override
  String get habitScheduleTitle => 'Schedule';

  @override
  String get habitFrequencySectionTitle => 'Frequency';

  @override
  String get habitSelectDatePlaceholder => 'Select';

  @override
  String get habitDeleteTitle => 'Delete habit?';

  @override
  String get habitDeleteMessage => 'This action cannot be undone.';

  @override
  String get habitEditTitle => 'Edit habit';

  @override
  String get habitGeneralSection => 'General';

  @override
  String get habitAdvancedSection => 'Advanced';

  @override
  String get habitConnectCourse => 'Connect course';

  @override
  String get habitCourseSyncHint =>
      'Syncs progress when you study for these courses.';

  @override
  String get habitCourseNumericWarning =>
      'Switch to Yes/No or Time to connect courses.';

  @override
  String get habitReminderDisabledTitle => 'Remind me';

  @override
  String get habitReminderDisabledSubtitle => 'Coming soon';

  @override
  String get habitArchiveTitle => 'Archive habit';

  @override
  String get habitArchivedLabel => 'Archived';

  @override
  String get habitResetProgressTitle => 'Reset habit progress';

  @override
  String get habitResetProgressSubtitle => 'Clears all history';

  @override
  String get habitResetProgressConfirmTitle => 'Reset habit progress?';

  @override
  String get habitResetProgressConfirmMessage =>
      'This will delete all completion history for this habit. It cannot be undone.';

  @override
  String get habitUnarchived => 'Habit unarchived';

  @override
  String get connectionsTabLabel => 'People';

  @override
  String get addPersonTitle => 'Add Person';

  @override
  String get editPersonTitle => 'Edit Person';

  @override
  String get personNameLabel => 'Name';

  @override
  String get personNameHint => 'Enter full name';

  @override
  String get groupsLabel => 'Groups';

  @override
  String get tagsLabel => 'Tags';

  @override
  String get phoneLabel => 'Phone';

  @override
  String get emailLabel => 'Email';

  @override
  String get notesLabel => 'Notes';

  @override
  String get lastContactedLabel => 'Last contacted';

  @override
  String get remindMeLabel => 'Remind me to reach out';

  @override
  String get manageGroupsTitle => 'Manage Groups';

  @override
  String get interactionLogTitle => 'Interaction Log';

  @override
  String get markContactedToday => 'Mark contacted today';

  @override
  String get noConnectionsPlaceholder => 'No people yet';

  @override
  String get searchConnectionsHint => 'Search people...';

  @override
  String get filterAll => 'All';

  @override
  String get sortByRecent => 'Recent';

  @override
  String get sortByName => 'Name';

  @override
  String get sortByPriority => 'Priority';

  @override
  String get deleteContactTitle => 'Delete Contact?';

  @override
  String deleteContactMessage(String name) {
    return 'Are you sure you want to delete \"$name\"?';
  }

  @override
  String get deleteConnectionGroupTitle => 'Delete Group?';

  @override
  String deleteConnectionGroupMessage(String name) {
    return 'This will remove \"$name\" from all contacts. This action cannot be undone.';
  }

  @override
  String get renameGroup => 'Rename';

  @override
  String get newGroup => 'New Group';

  @override
  String get editGroup => 'Edit Group';

  @override
  String get groupNameLabel => 'Group name';

  @override
  String get noInteractionsYet => 'No interactions recorded yet';

  @override
  String get addInteractionHint => 'What did you discuss?';

  @override
  String get habitUnarchiveAction => 'Unarchive';

  @override
  String get archivedHabitsTitle => 'Archived habits';

  @override
  String get archivedHabitsEmpty => 'No archived habits';

  @override
  String get habitsCalendarTitle => 'Calendar';

  @override
  String get habitTimeHourShort => 'H';

  @override
  String get habitTimeMinuteShort => 'M';

  @override
  String get habitTimeSecondShort => 'S';

  @override
  String get habitCategoryStudy => 'Study';

  @override
  String get habitCategorySports => 'Sports';

  @override
  String get habitCategoryQuitBadHabit => 'Quit a bad habit';

  @override
  String get habitCategoryHome => 'Home';

  @override
  String get habitCategoryHealth => 'Health';

  @override
  String get habitCategoryWork => 'Work';

  @override
  String get habitResetProgressMessage =>
      'All progress history for this habit will be deleted. This cannot be undone.';

  @override
  String get habitResetProgressAction => 'Reset';

  @override
  String get habitFrequencyRepeatsTitle => 'Repeats';

  @override
  String habitFrequencyEveryXDays(int count) {
    return 'Every $count days';
  }

  @override
  String get habitDragToCategorize => 'Drag to categorize';

  @override
  String get habitStatsEmptyState =>
      'No habits found. Add a habit to start tracking your progress. It is cool trust me!';

  @override
  String get habitStatsCompletionRate => 'Completion rate';

  @override
  String get habitStatsCompleted => 'Completed';

  @override
  String get habitStatsMissed => 'Missed';

  @override
  String get habitReportDownload => 'Download Report';

  @override
  String get habitReportTitle => 'Download report';

  @override
  String get habitReportDownloadAction => 'Download';

  @override
  String get shareFile => 'Share file';

  @override
  String habitReportSaved(String path) {
    return 'Saved to: $path';
  }

  @override
  String habitReportFileName(String month, int year) {
    return 'habits_${month}_$year';
  }

  @override
  String habitReportFailed(String error) {
    return 'Export failed: $error';
  }

  @override
  String get csvDay => 'Day';

  @override
  String get csvTotalCompleted => 'Total completed';

  @override
  String get csvTarget => 'Target';

  @override
  String get csvRate => 'Rate';

  @override
  String get exportFormat => 'Export format';

  @override
  String get exportFormatCSV => 'CSV';

  @override
  String get exportFormatExcel => 'Excel';

  @override
  String get exportSuccess => 'Export successful';

  @override
  String get exportSuccessMessage => 'Your file has been saved successfully';

  @override
  String get openFile => 'Open file';

  @override
  String get close => 'Close';

  @override
  String get interactionCalendarTitle => 'Interaction Calendar';

  @override
  String get signInToViewConnections => 'Please sign in to view your people.';

  @override
  String get personNotFound => 'Person not found';

  @override
  String errorSaving(String error) {
    return 'Error saving: $error';
  }

  @override
  String get add => 'Add';

  @override
  String get habitWeekNext => 'Next week';

  @override
  String get habitWeekLast => 'Last week';

  @override
  String get habitWeeksAgo => 'weeks ago';

  @override
  String get habitWeekCurrent => 'This week';

  @override
  String get copiedToClipboard => 'Copied to clipboard';

  @override
  String get sessionNotificationTitle => 'Session reminder';

  @override
  String sessionNotificationBody(String name) {
    return 'It is time for your $name session.';
  }

  @override
  String get memberFallbackName => 'Member';

  @override
  String get joinCodeTooShort => 'Use at least 8 characters.';

  @override
  String get sessionNotificationAction => 'Start session';

  @override
  String get updateRequiredTitle => 'Update NUmer';

  @override
  String get updateRequiredBody =>
      'This version is no longer supported. Install the latest version to continue.';

  @override
  String get updateRequiredAction => 'Update';

  @override
  String get codeScreenTitle => 'Enter the code';

  @override
  String codeScreenSubtitle(String email) {
    return 'We sent a 6-digit code to $email';
  }

  @override
  String get codeFieldLabel => '6-digit code';

  @override
  String get verifyCodeButton => 'Verify';

  @override
  String get resendCode => 'Resend code';

  @override
  String resendCodeIn(int seconds) {
    return 'Resend code in $seconds s';
  }

  @override
  String get newCodeSent => 'New code sent.';

  @override
  String codeInvalid(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count attempts left.',
      one: '1 attempt left.',
    );
    return 'Wrong code. $_temp0';
  }

  @override
  String get codeInvalidOrExpired =>
      'Wrong or expired code. Request a new one.';

  @override
  String get codeExpired => 'Code expired. Request a new one.';

  @override
  String get codeTooManyAttempts =>
      'Too many wrong attempts. Request a new code.';

  @override
  String codeRateLimited(int seconds) {
    return 'Too many requests. Try again in $seconds s.';
  }

  @override
  String get codeDeliveryFailed => 'Could not send the email. Try again.';

  @override
  String get codeCheckFailed => 'Could not check the code. Try again.';

  @override
  String get codeOffline => 'No connection. Check the network and try again.';

  @override
  String get emailVerifiedMessage => 'Email verified.';
}
