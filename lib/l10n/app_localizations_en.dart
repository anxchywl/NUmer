// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

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
  String get yes => 'Yes';

  @override
  String get no => 'No';

  @override
  String get data => 'Data';

  @override
  String get exportToCalendar => 'Export to calendar';

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
  String get fileSavedSuccessfully => 'File saved successfully';

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
  String get accountDeleted => 'Account deleted';

  @override
  String get pleaseSignInToViewAccount =>
      'Please sign in to view your account.';

  @override
  String get signOut => 'Sign out';

  @override
  String get syncNow => 'Sync now';

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
  String get courseAnalysis => 'Course analysis';

  @override
  String get noCoursesAvailable => 'No courses available.';

  @override
  String get selectCourse => 'Select course';

  @override
  String get timePeriod => 'Time period';

  @override
  String get oneMonth => '1 month';

  @override
  String get threeMonths => '3 months';

  @override
  String get sixMonths => '6 months';

  @override
  String get generateInsight => 'Generate insight';

  @override
  String get analyzing => 'Analyzing...';

  @override
  String get analysisPlaceholder =>
      'Select a course and time period, then get AI-powered feedback of your studies.';

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
  String get overview => 'Overview';

  @override
  String get scrollUpHint => 'Scroll up';

  @override
  String get topTopics => 'Top topics';

  @override
  String get insights => 'Insights';

  @override
  String get recommendations => 'Recommendations';

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
  String get groupNameHint => 'Enter a name for your group';

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
  String get viaTimer => 'via Timer';

  @override
  String get viaStopwatch => 'via Stopwatch';

  @override
  String get viaPomodoro => 'via Pomodoro';

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
  String get on => 'on';

  @override
  String get off => 'off';

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
  String get resendEmail => 'Resend email';

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
  String get min8Chars => 'Minimum 8 characters.';

  @override
  String get loadingProfile => 'Loading your profile...';

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
  String get habitNameHint => 'e.g. morning jog';

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
  String get habitReminderDisabledSubtitle =>
      'This feature is currently disabled';

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
}
