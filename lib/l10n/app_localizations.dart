import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_kk.dart';
import 'app_localizations_ru.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('kk'),
    Locale('ru'),
  ];

  /// No description provided for @habitTypeLockedHint.
  ///
  /// In en, this message translates to:
  /// **'Habit type cannot be changed after creation'**
  String get habitTypeLockedHint;

  /// No description provided for @settingsTitle.
  ///
  /// In en, this message translates to:
  /// **'Account & settings'**
  String get settingsTitle;

  /// No description provided for @account.
  ///
  /// In en, this message translates to:
  /// **'Account'**
  String get account;

  /// No description provided for @profile.
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get profile;

  /// No description provided for @appearance.
  ///
  /// In en, this message translates to:
  /// **'Appearance'**
  String get appearance;

  /// No description provided for @system.
  ///
  /// In en, this message translates to:
  /// **'System'**
  String get system;

  /// No description provided for @light.
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get light;

  /// No description provided for @dark.
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get dark;

  /// No description provided for @language.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get language;

  /// No description provided for @english.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get english;

  /// No description provided for @russian.
  ///
  /// In en, this message translates to:
  /// **'Russian'**
  String get russian;

  /// No description provided for @kazakh.
  ///
  /// In en, this message translates to:
  /// **'Kazakh'**
  String get kazakh;

  /// No description provided for @accentColor.
  ///
  /// In en, this message translates to:
  /// **'Accent color'**
  String get accentColor;

  /// No description provided for @buttonPreview.
  ///
  /// In en, this message translates to:
  /// **'Button'**
  String get buttonPreview;

  /// No description provided for @accentColorDescription.
  ///
  /// In en, this message translates to:
  /// **'Customize your primary color'**
  String get accentColorDescription;

  /// No description provided for @preview.
  ///
  /// In en, this message translates to:
  /// **'Preview'**
  String get preview;

  /// No description provided for @textExample.
  ///
  /// In en, this message translates to:
  /// **'Text example'**
  String get textExample;

  /// No description provided for @customColor.
  ///
  /// In en, this message translates to:
  /// **'Custom color'**
  String get customColor;

  /// No description provided for @hue.
  ///
  /// In en, this message translates to:
  /// **'Hue'**
  String get hue;

  /// No description provided for @saturation.
  ///
  /// In en, this message translates to:
  /// **'Saturation'**
  String get saturation;

  /// No description provided for @lightness.
  ///
  /// In en, this message translates to:
  /// **'Lightness'**
  String get lightness;

  /// No description provided for @presets.
  ///
  /// In en, this message translates to:
  /// **'Presets'**
  String get presets;

  /// No description provided for @defaultPreset.
  ///
  /// In en, this message translates to:
  /// **'Default'**
  String get defaultPreset;

  /// No description provided for @rosePreset.
  ///
  /// In en, this message translates to:
  /// **'Rose'**
  String get rosePreset;

  /// No description provided for @emeraldPreset.
  ///
  /// In en, this message translates to:
  /// **'Emerald'**
  String get emeraldPreset;

  /// No description provided for @indigoPreset.
  ///
  /// In en, this message translates to:
  /// **'Indigo'**
  String get indigoPreset;

  /// No description provided for @coralPreset.
  ///
  /// In en, this message translates to:
  /// **'Coral'**
  String get coralPreset;

  /// No description provided for @tealPreset.
  ///
  /// In en, this message translates to:
  /// **'Teal'**
  String get tealPreset;

  /// No description provided for @createPreset.
  ///
  /// In en, this message translates to:
  /// **'Create preset'**
  String get createPreset;

  /// No description provided for @presetName.
  ///
  /// In en, this message translates to:
  /// **'Preset name'**
  String get presetName;

  /// No description provided for @lettersOnly.
  ///
  /// In en, this message translates to:
  /// **'Letters and spaces only'**
  String get lettersOnly;

  /// No description provided for @max16Symbols.
  ///
  /// In en, this message translates to:
  /// **'Max 16 symbols'**
  String get max16Symbols;

  /// No description provided for @deletePreset.
  ///
  /// In en, this message translates to:
  /// **'Delete preset'**
  String get deletePreset;

  /// No description provided for @presetLimitReached.
  ///
  /// In en, this message translates to:
  /// **'Preset limit reached (22)'**
  String get presetLimitReached;

  /// No description provided for @weekStartsOn.
  ///
  /// In en, this message translates to:
  /// **'Week starts on'**
  String get weekStartsOn;

  /// No description provided for @displayTotalStudyTime.
  ///
  /// In en, this message translates to:
  /// **'Display total study time per course over'**
  String get displayTotalStudyTime;

  /// No description provided for @displayProgressBar.
  ///
  /// In en, this message translates to:
  /// **'Display progress bar of'**
  String get displayProgressBar;

  /// No description provided for @quickNotes.
  ///
  /// In en, this message translates to:
  /// **'Quick notes'**
  String get quickNotes;

  /// No description provided for @wantToReceiveNudges.
  ///
  /// In en, this message translates to:
  /// **'Want to receive nudges?'**
  String get wantToReceiveNudges;

  /// No description provided for @eisenhowerMatrix.
  ///
  /// In en, this message translates to:
  /// **'Eisenhower matrix'**
  String get eisenhowerMatrix;

  /// No description provided for @quickNotesDescription.
  ///
  /// In en, this message translates to:
  /// **'Existing notes will stay saved, but no new note popups will appear after sessions.'**
  String get quickNotesDescription;

  /// No description provided for @wantToReceiveNudgesDescription.
  ///
  /// In en, this message translates to:
  /// **'Allow group members to send you gentle nudges to stay on track.'**
  String get wantToReceiveNudgesDescription;

  /// No description provided for @eisenhowerMatrixDescription.
  ///
  /// In en, this message translates to:
  /// **'Use the Eisenhower matrix on the Habits screen to organize habits by urgency and importance.'**
  String get eisenhowerMatrixDescription;

  /// No description provided for @sessionNotification.
  ///
  /// In en, this message translates to:
  /// **'Session notification'**
  String get sessionNotification;

  /// No description provided for @sessionNotificationDescription.
  ///
  /// In en, this message translates to:
  /// **'Show session controls in the notification bar while recording.'**
  String get sessionNotificationDescription;

  /// No description provided for @eisenhowerQuadrant1.
  ///
  /// In en, this message translates to:
  /// **'Urgent & Important'**
  String get eisenhowerQuadrant1;

  /// No description provided for @eisenhowerQuadrant2.
  ///
  /// In en, this message translates to:
  /// **'Not urgent & Important'**
  String get eisenhowerQuadrant2;

  /// No description provided for @eisenhowerQuadrant3.
  ///
  /// In en, this message translates to:
  /// **'Urgent & Not important'**
  String get eisenhowerQuadrant3;

  /// No description provided for @eisenhowerQuadrant4.
  ///
  /// In en, this message translates to:
  /// **'Not urgent & Not important'**
  String get eisenhowerQuadrant4;

  /// No description provided for @eisenhowerHint.
  ///
  /// In en, this message translates to:
  /// **'Drag habits into the matrix to organize them'**
  String get eisenhowerHint;

  /// No description provided for @yes.
  ///
  /// In en, this message translates to:
  /// **'Yes'**
  String get yes;

  /// No description provided for @no.
  ///
  /// In en, this message translates to:
  /// **'No'**
  String get no;

  /// No description provided for @data.
  ///
  /// In en, this message translates to:
  /// **'Data'**
  String get data;

  /// No description provided for @exportToCalendar.
  ///
  /// In en, this message translates to:
  /// **'Export to calendar'**
  String get exportToCalendar;

  /// No description provided for @exportWillStartIn.
  ///
  /// In en, this message translates to:
  /// **'Export will start in {seconds} seconds'**
  String exportWillStartIn(int seconds);

  /// No description provided for @exportToCalendarSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Save your sessions as calendar events'**
  String get exportToCalendarSubtitle;

  /// No description provided for @allCourses.
  ///
  /// In en, this message translates to:
  /// **'All courses'**
  String get allCourses;

  /// No description provided for @courseFallback.
  ///
  /// In en, this message translates to:
  /// **'Course'**
  String get courseFallback;

  /// No description provided for @export.
  ///
  /// In en, this message translates to:
  /// **'Export'**
  String get export;

  /// No description provided for @exporting.
  ///
  /// In en, this message translates to:
  /// **'Exporting...'**
  String get exporting;

  /// No description provided for @exportFailedMessage.
  ///
  /// In en, this message translates to:
  /// **'Export failed: {error}'**
  String exportFailedMessage(String error);

  /// No description provided for @sessionsFound.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{No sessions found} one{1 session found} other{{count} sessions found}}'**
  String sessionsFound(int count);

  /// No description provided for @habitReportDownloadCountdown.
  ///
  /// In en, this message translates to:
  /// **'Report generation will start in {seconds} seconds'**
  String habitReportDownloadCountdown(int seconds);

  /// No description provided for @fileSavedSuccessfully.
  ///
  /// In en, this message translates to:
  /// **'File generated successfully'**
  String get fileSavedSuccessfully;

  /// No description provided for @fileSavedAt.
  ///
  /// In en, this message translates to:
  /// **'The file is saved at:'**
  String get fileSavedAt;

  /// No description provided for @unknownPath.
  ///
  /// In en, this message translates to:
  /// **'Unknown path'**
  String get unknownPath;

  /// No description provided for @nextSteps.
  ///
  /// In en, this message translates to:
  /// **'Next steps:'**
  String get nextSteps;

  /// No description provided for @exportCalendarNextStepsBody.
  ///
  /// In en, this message translates to:
  /// **'• Open this file and import it into your calendar app,\n• OR open your calendar app settings and import the file manually.'**
  String get exportCalendarNextStepsBody;

  /// No description provided for @deleteAccount.
  ///
  /// In en, this message translates to:
  /// **'Delete account'**
  String get deleteAccount;

  /// No description provided for @deleteAccountSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Permanently delete your account and all data'**
  String get deleteAccountSubtitle;

  /// No description provided for @deleteAccountHoldConfirmDetail.
  ///
  /// In en, this message translates to:
  /// **'After holding the button for 5 seconds the account will be deleted forever'**
  String get deleteAccountHoldConfirmDetail;

  /// No description provided for @deletingAccount.
  ///
  /// In en, this message translates to:
  /// **'Deleting account...'**
  String get deletingAccount;

  /// No description provided for @deleteAccountPasswordTitle.
  ///
  /// In en, this message translates to:
  /// **'Enter your password to delete the account'**
  String get deleteAccountPasswordTitle;

  /// No description provided for @deleteAccountWrongPassword.
  ///
  /// In en, this message translates to:
  /// **'Wrong password. Try again.'**
  String get deleteAccountWrongPassword;

  /// No description provided for @deleteAccountNetworkError.
  ///
  /// In en, this message translates to:
  /// **'No connection. Try again.'**
  String get deleteAccountNetworkError;

  /// No description provided for @deleteAccountFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not delete the account. Try again.'**
  String get deleteAccountFailed;

  /// No description provided for @accountDeleted.
  ///
  /// In en, this message translates to:
  /// **'Account deleted'**
  String get accountDeleted;

  /// No description provided for @pleaseSignInToViewAccount.
  ///
  /// In en, this message translates to:
  /// **'Please sign in to view your account.'**
  String get pleaseSignInToViewAccount;

  /// No description provided for @signOut.
  ///
  /// In en, this message translates to:
  /// **'Sign out'**
  String get signOut;

  /// No description provided for @syncNow.
  ///
  /// In en, this message translates to:
  /// **'Sync now'**
  String get syncNow;

  /// No description provided for @syncing.
  ///
  /// In en, this message translates to:
  /// **'Syncing'**
  String get syncing;

  /// No description provided for @home.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get home;

  /// No description provided for @statistics.
  ///
  /// In en, this message translates to:
  /// **'Statistics'**
  String get statistics;

  /// No description provided for @groups.
  ///
  /// In en, this message translates to:
  /// **'Groups'**
  String get groups;

  /// No description provided for @addCourse.
  ///
  /// In en, this message translates to:
  /// **'Add course'**
  String get addCourse;

  /// No description provided for @addTime.
  ///
  /// In en, this message translates to:
  /// **'Add time'**
  String get addTime;

  /// No description provided for @courseName.
  ///
  /// In en, this message translates to:
  /// **'Course name'**
  String get courseName;

  /// No description provided for @courseNameHint.
  ///
  /// In en, this message translates to:
  /// **''**
  String get courseNameHint;

  /// No description provided for @required.
  ///
  /// In en, this message translates to:
  /// **'Required'**
  String get required;

  /// No description provided for @color.
  ///
  /// In en, this message translates to:
  /// **'Color'**
  String get color;

  /// No description provided for @creditsOptional.
  ///
  /// In en, this message translates to:
  /// **'Credits (optional)'**
  String get creditsOptional;

  /// No description provided for @creditsHint.
  ///
  /// In en, this message translates to:
  /// **'6 or 7 for example'**
  String get creditsHint;

  /// No description provided for @creditsHelper.
  ///
  /// In en, this message translates to:
  /// **'Add credits to enable self-study goals'**
  String get creditsHelper;

  /// No description provided for @experienceLevel.
  ///
  /// In en, this message translates to:
  /// **'Experience level'**
  String get experienceLevel;

  /// No description provided for @save.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @delete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get delete;

  /// No description provided for @deleteCourseTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete course'**
  String get deleteCourseTitle;

  /// No description provided for @deleteCourseMessage.
  ///
  /// In en, this message translates to:
  /// **'Are you sure? All data for this course will be deleted.'**
  String get deleteCourseMessage;

  /// No description provided for @timeSavedMessage.
  ///
  /// In en, this message translates to:
  /// **'Time for \"{courseName}\" saved'**
  String timeSavedMessage(String courseName);

  /// No description provided for @aiAnalysisComingSoon.
  ///
  /// In en, this message translates to:
  /// **'Course analysis is coming soon.'**
  String get aiAnalysisComingSoon;

  /// No description provided for @courseAnalysis.
  ///
  /// In en, this message translates to:
  /// **'Course analysis'**
  String get courseAnalysis;

  /// No description provided for @noCoursesAvailable.
  ///
  /// In en, this message translates to:
  /// **'No courses available.'**
  String get noCoursesAvailable;

  /// No description provided for @selectCourse.
  ///
  /// In en, this message translates to:
  /// **'Select course'**
  String get selectCourse;

  /// No description provided for @sixMonths.
  ///
  /// In en, this message translates to:
  /// **'6 months'**
  String get sixMonths;

  /// No description provided for @analysisUpdatesEveryPeriod.
  ///
  /// In en, this message translates to:
  /// **'Your analysis updates every new period.'**
  String get analysisUpdatesEveryPeriod;

  /// No description provided for @analysisAlreadyGenerated.
  ///
  /// In en, this message translates to:
  /// **'You\'ve already generated an analysis for this period.'**
  String get analysisAlreadyGenerated;

  /// No description provided for @dayStatsTipLine1.
  ///
  /// In en, this message translates to:
  /// **'• The calendar highlights your study activity. The greener the day, the more you studied.'**
  String get dayStatsTipLine1;

  /// No description provided for @dayStatsTipLine2.
  ///
  /// In en, this message translates to:
  /// **'• You can edit session time and notes in the History screen.'**
  String get dayStatsTipLine2;

  /// No description provided for @dayStatsTipLine3.
  ///
  /// In en, this message translates to:
  /// **'• You can tap on any course, and the history screen will show only the sessions for that course.'**
  String get dayStatsTipLine3;

  /// No description provided for @syncOffline.
  ///
  /// In en, this message translates to:
  /// **'Offline'**
  String get syncOffline;

  /// No description provided for @syncSyncing.
  ///
  /// In en, this message translates to:
  /// **'Syncing…'**
  String get syncSyncing;

  /// No description provided for @syncUpToDate.
  ///
  /// In en, this message translates to:
  /// **'Up to date'**
  String get syncUpToDate;

  /// No description provided for @setGoals.
  ///
  /// In en, this message translates to:
  /// **'Set goals'**
  String get setGoals;

  /// No description provided for @daily.
  ///
  /// In en, this message translates to:
  /// **'Daily'**
  String get daily;

  /// No description provided for @weekly.
  ///
  /// In en, this message translates to:
  /// **'Weekly'**
  String get weekly;

  /// No description provided for @studyTimer.
  ///
  /// In en, this message translates to:
  /// **'Study timer'**
  String get studyTimer;

  /// No description provided for @noCoursesYet.
  ///
  /// In en, this message translates to:
  /// **'No courses yet. Add a course from Home.'**
  String get noCoursesYet;

  /// No description provided for @chooseACourse.
  ///
  /// In en, this message translates to:
  /// **'Choose a course'**
  String get chooseACourse;

  /// No description provided for @start.
  ///
  /// In en, this message translates to:
  /// **'Start'**
  String get start;

  /// No description provided for @stop.
  ///
  /// In en, this message translates to:
  /// **'Stop'**
  String get stop;

  /// No description provided for @reset.
  ///
  /// In en, this message translates to:
  /// **'Reset'**
  String get reset;

  /// No description provided for @ok.
  ///
  /// In en, this message translates to:
  /// **'OK'**
  String get ok;

  /// No description provided for @timerStoppedAndSaved.
  ///
  /// In en, this message translates to:
  /// **'Timer stopped and saved.'**
  String get timerStoppedAndSaved;

  /// No description provided for @nothingToReset.
  ///
  /// In en, this message translates to:
  /// **'Nothing to reset.'**
  String get nothingToReset;

  /// No description provided for @anotherSessionRunning.
  ///
  /// In en, this message translates to:
  /// **'Another {sessionType} is already running.'**
  String anotherSessionRunning(String sessionType);

  /// No description provided for @anotherSessionRunningOn.
  ///
  /// In en, this message translates to:
  /// **'Another {sessionType} is already running on \"{courseName}\".'**
  String anotherSessionRunningOn(String sessionType, String courseName);

  /// No description provided for @anotherSessionRunningSilly.
  ///
  /// In en, this message translates to:
  /// **'Another {sessionType} is already running, silly.'**
  String anotherSessionRunningSilly(String sessionType);

  /// No description provided for @alreadyStudiedThisPeriod.
  ///
  /// In en, this message translates to:
  /// **'You already studied during this time period.'**
  String get alreadyStudiedThisPeriod;

  /// No description provided for @friendJoinPrompt.
  ///
  /// In en, this message translates to:
  /// **'Your friend can join by typing your group’s name into the search bar.'**
  String get friendJoinPrompt;

  /// No description provided for @enterTimeFirst.
  ///
  /// In en, this message translates to:
  /// **'Enter time first'**
  String get enterTimeFirst;

  /// No description provided for @nothingToSave.
  ///
  /// In en, this message translates to:
  /// **'Nothing to save'**
  String get nothingToSave;

  /// No description provided for @maxTimeCapped.
  ///
  /// In en, this message translates to:
  /// **'Max is 3:00:00 — capped'**
  String get maxTimeCapped;

  /// No description provided for @studiedLabel.
  ///
  /// In en, this message translates to:
  /// **'Studied'**
  String get studiedLabel;

  /// No description provided for @goalsUpdated.
  ///
  /// In en, this message translates to:
  /// **'Goals updated'**
  String get goalsUpdated;

  /// No description provided for @studiedToday.
  ///
  /// In en, this message translates to:
  /// **'Studied today'**
  String get studiedToday;

  /// No description provided for @studiedThisWeek.
  ///
  /// In en, this message translates to:
  /// **'Studied this week'**
  String get studiedThisWeek;

  /// No description provided for @studiedThisMonth.
  ///
  /// In en, this message translates to:
  /// **'Studied this month'**
  String get studiedThisMonth;

  /// No description provided for @studiedThisYear.
  ///
  /// In en, this message translates to:
  /// **'Studied this year'**
  String get studiedThisYear;

  /// No description provided for @studiedOverall.
  ///
  /// In en, this message translates to:
  /// **'Studied overall'**
  String get studiedOverall;

  /// No description provided for @timer.
  ///
  /// In en, this message translates to:
  /// **'timer'**
  String get timer;

  /// No description provided for @stopwatch.
  ///
  /// In en, this message translates to:
  /// **'stopwatch'**
  String get stopwatch;

  /// No description provided for @pomodoro.
  ///
  /// In en, this message translates to:
  /// **'pomodoro'**
  String get pomodoro;

  /// No description provided for @session.
  ///
  /// In en, this message translates to:
  /// **'session'**
  String get session;

  /// No description provided for @editCourse.
  ///
  /// In en, this message translates to:
  /// **'Edit course'**
  String get editCourse;

  /// No description provided for @today.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get today;

  /// No description provided for @edit.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get edit;

  /// No description provided for @timerTab.
  ///
  /// In en, this message translates to:
  /// **'Timer'**
  String get timerTab;

  /// No description provided for @stopwatchTab.
  ///
  /// In en, this message translates to:
  /// **'Stopwatch'**
  String get stopwatchTab;

  /// No description provided for @pomodoroTab.
  ///
  /// In en, this message translates to:
  /// **'Pomodoro'**
  String get pomodoroTab;

  /// No description provided for @typeTimeToStudy.
  ///
  /// In en, this message translates to:
  /// **'Here type the time you need to study for'**
  String get typeTimeToStudy;

  /// No description provided for @maxTime.
  ///
  /// In en, this message translates to:
  /// **'Max: 3:00:00'**
  String get maxTime;

  /// No description provided for @elapsed.
  ///
  /// In en, this message translates to:
  /// **'elapsed'**
  String get elapsed;

  /// No description provided for @completedPomodoros.
  ///
  /// In en, this message translates to:
  /// **'Completed pomodoros: {completed} / 4'**
  String completedPomodoros(int completed);

  /// No description provided for @longBreakLength.
  ///
  /// In en, this message translates to:
  /// **'Long break length ({minutes} min)'**
  String longBreakLength(int minutes);

  /// No description provided for @work.
  ///
  /// In en, this message translates to:
  /// **'Work'**
  String get work;

  /// No description provided for @shortBreak.
  ///
  /// In en, this message translates to:
  /// **'Short break'**
  String get shortBreak;

  /// No description provided for @longBreak.
  ///
  /// In en, this message translates to:
  /// **'Long break'**
  String get longBreak;

  /// No description provided for @paused.
  ///
  /// In en, this message translates to:
  /// **'paused'**
  String get paused;

  /// No description provided for @resume.
  ///
  /// In en, this message translates to:
  /// **'Resume'**
  String get resume;

  /// No description provided for @pause.
  ///
  /// In en, this message translates to:
  /// **'Pause'**
  String get pause;

  /// No description provided for @skipBreak.
  ///
  /// In en, this message translates to:
  /// **'Skip break'**
  String get skipBreak;

  /// No description provided for @pomodoroExitWarning.
  ///
  /// In en, this message translates to:
  /// **'A pomodoro session is running. Exit anyway?'**
  String get pomodoroExitWarning;

  /// No description provided for @exitAnyway.
  ///
  /// In en, this message translates to:
  /// **'Exit anyway'**
  String get exitAnyway;

  /// No description provided for @expLevel1.
  ///
  /// In en, this message translates to:
  /// **'Complete noob'**
  String get expLevel1;

  /// No description provided for @expLevel2.
  ///
  /// In en, this message translates to:
  /// **'Know some basics'**
  String get expLevel2;

  /// No description provided for @expLevel3.
  ///
  /// In en, this message translates to:
  /// **'Comfortable with the subject'**
  String get expLevel3;

  /// No description provided for @expLevel4.
  ///
  /// In en, this message translates to:
  /// **'Advanced level of knowledge'**
  String get expLevel4;

  /// No description provided for @expLevel5.
  ///
  /// In en, this message translates to:
  /// **'Broad experience'**
  String get expLevel5;

  /// No description provided for @expLevelDefault.
  ///
  /// In en, this message translates to:
  /// **'Comfortable'**
  String get expLevelDefault;

  /// No description provided for @dayStatistics.
  ///
  /// In en, this message translates to:
  /// **'Day statistics'**
  String get dayStatistics;

  /// No description provided for @periodStatistics.
  ///
  /// In en, this message translates to:
  /// **'Period statistics'**
  String get periodStatistics;

  /// No description provided for @tip.
  ///
  /// In en, this message translates to:
  /// **'Tip'**
  String get tip;

  /// No description provided for @chartTip.
  ///
  /// In en, this message translates to:
  /// **'• Hold your finger on the chart and slide left or right to move between days or months.'**
  String get chartTip;

  /// No description provided for @courseStatistics.
  ///
  /// In en, this message translates to:
  /// **'Course statistics'**
  String get courseStatistics;

  /// No description provided for @previousDay.
  ///
  /// In en, this message translates to:
  /// **'Previous day'**
  String get previousDay;

  /// No description provided for @nextDay.
  ///
  /// In en, this message translates to:
  /// **'Next day'**
  String get nextDay;

  /// No description provided for @history.
  ///
  /// In en, this message translates to:
  /// **'History'**
  String get history;

  /// No description provided for @week.
  ///
  /// In en, this message translates to:
  /// **'Week'**
  String get week;

  /// No description provided for @month.
  ///
  /// In en, this message translates to:
  /// **'Month'**
  String get month;

  /// No description provided for @year.
  ///
  /// In en, this message translates to:
  /// **'Year'**
  String get year;

  /// No description provided for @previousWeek.
  ///
  /// In en, this message translates to:
  /// **'previous week'**
  String get previousWeek;

  /// No description provided for @previousMonth.
  ///
  /// In en, this message translates to:
  /// **'previous month'**
  String get previousMonth;

  /// No description provided for @previousYear.
  ///
  /// In en, this message translates to:
  /// **'previous year'**
  String get previousYear;

  /// No description provided for @nextWeek.
  ///
  /// In en, this message translates to:
  /// **'next week'**
  String get nextWeek;

  /// No description provided for @nextMonth.
  ///
  /// In en, this message translates to:
  /// **'next month'**
  String get nextMonth;

  /// No description provided for @nextYear.
  ///
  /// In en, this message translates to:
  /// **'next year'**
  String get nextYear;

  /// No description provided for @noData.
  ///
  /// In en, this message translates to:
  /// **'No data'**
  String get noData;

  /// No description provided for @hours.
  ///
  /// In en, this message translates to:
  /// **'Hours'**
  String get hours;

  /// No description provided for @minutes.
  ///
  /// In en, this message translates to:
  /// **'Minutes'**
  String get minutes;

  /// No description provided for @totalThisPeriod.
  ///
  /// In en, this message translates to:
  /// **'Total this {period}'**
  String totalThisPeriod(String period);

  /// No description provided for @avgPerDay.
  ///
  /// In en, this message translates to:
  /// **'Average per day'**
  String get avgPerDay;

  /// No description provided for @mostStudied.
  ///
  /// In en, this message translates to:
  /// **'Most studied'**
  String get mostStudied;

  /// No description provided for @leastStudied.
  ///
  /// In en, this message translates to:
  /// **'Least studied'**
  String get leastStudied;

  /// No description provided for @adjustWeeklyGoal.
  ///
  /// In en, this message translates to:
  /// **'Adjust weekly goal'**
  String get adjustWeeklyGoal;

  /// No description provided for @targetPerWeek.
  ///
  /// In en, this message translates to:
  /// **'Target per week'**
  String get targetPerWeek;

  /// No description provided for @targetPerDay.
  ///
  /// In en, this message translates to:
  /// **'Target per day'**
  String get targetPerDay;

  /// No description provided for @semester.
  ///
  /// In en, this message translates to:
  /// **'Semester (~{weeks} wks)'**
  String semester(int weeks);

  /// No description provided for @hPerWeek.
  ///
  /// In en, this message translates to:
  /// **'{hours} h/week'**
  String hPerWeek(String hours);

  /// No description provided for @createGroup.
  ///
  /// In en, this message translates to:
  /// **'Create group'**
  String get createGroup;

  /// No description provided for @joinGroup.
  ///
  /// In en, this message translates to:
  /// **'Join group'**
  String get joinGroup;

  /// No description provided for @groupName.
  ///
  /// In en, this message translates to:
  /// **'Group name'**
  String get groupName;

  /// No description provided for @description.
  ///
  /// In en, this message translates to:
  /// **'Description'**
  String get description;

  /// No description provided for @privacy.
  ///
  /// In en, this message translates to:
  /// **'Privacy'**
  String get privacy;

  /// No description provided for @public.
  ///
  /// In en, this message translates to:
  /// **'Public'**
  String get public;

  /// No description provided for @private.
  ///
  /// In en, this message translates to:
  /// **'Private'**
  String get private;

  /// No description provided for @accessCode.
  ///
  /// In en, this message translates to:
  /// **'Access code'**
  String get accessCode;

  /// No description provided for @members.
  ///
  /// In en, this message translates to:
  /// **'Members'**
  String get members;

  /// No description provided for @leaveGroup.
  ///
  /// In en, this message translates to:
  /// **'Leave group'**
  String get leaveGroup;

  /// No description provided for @deleteGroup.
  ///
  /// In en, this message translates to:
  /// **'Delete group'**
  String get deleteGroup;

  /// No description provided for @groupSettings.
  ///
  /// In en, this message translates to:
  /// **'Group settings'**
  String get groupSettings;

  /// No description provided for @noGroupsYet.
  ///
  /// In en, this message translates to:
  /// **'You\'re not in any groups yet'**
  String get noGroupsYet;

  /// No description provided for @noSearchResults.
  ///
  /// In en, this message translates to:
  /// **'We have nothing like this here'**
  String get noSearchResults;

  /// No description provided for @createOrJoinPrompt.
  ///
  /// In en, this message translates to:
  /// **'Create a new group or join an existing one to collaborate with others'**
  String get createOrJoinPrompt;

  /// No description provided for @signInPrompt.
  ///
  /// In en, this message translates to:
  /// **'Sign in to explore groups.'**
  String get signInPrompt;

  /// No description provided for @errorLoadingMemberships.
  ///
  /// In en, this message translates to:
  /// **'Error loading memberships: {error}'**
  String errorLoadingMemberships(String error);

  /// No description provided for @findPublicGroupHint.
  ///
  /// In en, this message translates to:
  /// **'Find a group...'**
  String get findPublicGroupHint;

  /// No description provided for @searchResults.
  ///
  /// In en, this message translates to:
  /// **'Search results'**
  String get searchResults;

  /// No description provided for @errorLoadingGroups.
  ///
  /// In en, this message translates to:
  /// **'Error loading groups: {error}'**
  String errorLoadingGroups(String error);

  /// No description provided for @joinedSuccessfully.
  ///
  /// In en, this message translates to:
  /// **'Joined group successfully'**
  String get joinedSuccessfully;

  /// No description provided for @joinedPrivateSuccessfully.
  ///
  /// In en, this message translates to:
  /// **'Joined private group successfully'**
  String get joinedPrivateSuccessfully;

  /// No description provided for @joinGroupDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Join {groupName}'**
  String joinGroupDialogTitle(String groupName);

  /// No description provided for @joinGroupDialogMessage.
  ///
  /// In en, this message translates to:
  /// **'Enter the join code to access this private group.'**
  String get joinGroupDialogMessage;

  /// No description provided for @joinCodeHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. ABC123'**
  String get joinCodeHint;

  /// No description provided for @publicGroups.
  ///
  /// In en, this message translates to:
  /// **'Public groups'**
  String get publicGroups;

  /// No description provided for @joinError.
  ///
  /// In en, this message translates to:
  /// **'Could not join group: {error}'**
  String joinError(String error);

  /// No description provided for @noDescription.
  ///
  /// In en, this message translates to:
  /// **'No description provided.'**
  String get noDescription;

  /// No description provided for @membersCount.
  ///
  /// In en, this message translates to:
  /// **'{count} members'**
  String membersCount(int count);

  /// No description provided for @yourGroup.
  ///
  /// In en, this message translates to:
  /// **'Your group'**
  String get yourGroup;

  /// No description provided for @findStudyGroup.
  ///
  /// In en, this message translates to:
  /// **'Find your study group'**
  String get findStudyGroup;

  /// No description provided for @joinCommunityPrompt.
  ///
  /// In en, this message translates to:
  /// **'Join a community to track progress, compete on leaderboards, and stay motivated together.'**
  String get joinCommunityPrompt;

  /// No description provided for @administrator.
  ///
  /// In en, this message translates to:
  /// **'Admin'**
  String get administrator;

  /// No description provided for @memberLabel.
  ///
  /// In en, this message translates to:
  /// **'Member'**
  String get memberLabel;

  /// No description provided for @unableToLoadGroup.
  ///
  /// In en, this message translates to:
  /// **'Unable to load group data'**
  String get unableToLoadGroup;

  /// No description provided for @checkConnection.
  ///
  /// In en, this message translates to:
  /// **'Please check your internet connection'**
  String get checkConnection;

  /// No description provided for @retry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get retry;

  /// No description provided for @groupNotFound.
  ///
  /// In en, this message translates to:
  /// **'Group not found or was deleted.'**
  String get groupNotFound;

  /// No description provided for @signInToManage.
  ///
  /// In en, this message translates to:
  /// **'You need to be signed in to manage this group.'**
  String get signInToManage;

  /// No description provided for @noLongerMember.
  ///
  /// In en, this message translates to:
  /// **'You are no longer a member of this group.'**
  String get noLongerMember;

  /// No description provided for @groupNameHint.
  ///
  /// In en, this message translates to:
  /// **'Enter group name'**
  String get groupNameHint;

  /// No description provided for @visibility.
  ///
  /// In en, this message translates to:
  /// **'Visibility'**
  String get visibility;

  /// No description provided for @descriptionHint.
  ///
  /// In en, this message translates to:
  /// **'Describe your group in a few words'**
  String get descriptionHint;

  /// No description provided for @codeRequired.
  ///
  /// In en, this message translates to:
  /// **'Code is required'**
  String get codeRequired;

  /// No description provided for @codeJoinPrompt.
  ///
  /// In en, this message translates to:
  /// **'This code is required for new members to join.'**
  String get codeJoinPrompt;

  /// No description provided for @onlyAdminVisibility.
  ///
  /// In en, this message translates to:
  /// **'Only administrators can change settings.'**
  String get onlyAdminVisibility;

  /// No description provided for @saving.
  ///
  /// In en, this message translates to:
  /// **'Saving...'**
  String get saving;

  /// No description provided for @saveChanges.
  ///
  /// In en, this message translates to:
  /// **'Save changes'**
  String get saveChanges;

  /// No description provided for @membersTitle.
  ///
  /// In en, this message translates to:
  /// **'Members'**
  String get membersTitle;

  /// No description provided for @unableToLoadMembers.
  ///
  /// In en, this message translates to:
  /// **'Unable to load member list'**
  String get unableToLoadMembers;

  /// No description provided for @checkConnectionTryAgain.
  ///
  /// In en, this message translates to:
  /// **'Please check your connection and try again'**
  String get checkConnectionTryAgain;

  /// No description provided for @noMembersYetLabel.
  ///
  /// In en, this message translates to:
  /// **'No members yet.'**
  String get noMembersYetLabel;

  /// No description provided for @youAdmin.
  ///
  /// In en, this message translates to:
  /// **'You (admin)'**
  String get youAdmin;

  /// No description provided for @youMember.
  ///
  /// In en, this message translates to:
  /// **'You'**
  String get youMember;

  /// No description provided for @youOwner.
  ///
  /// In en, this message translates to:
  /// **'You (owner)'**
  String get youOwner;

  /// No description provided for @removeMemberTitle.
  ///
  /// In en, this message translates to:
  /// **'Remove member?'**
  String get removeMemberTitle;

  /// No description provided for @removeMemberMessage.
  ///
  /// In en, this message translates to:
  /// **'Remove this member from the group? They will lose access immediately.'**
  String get removeMemberMessage;

  /// No description provided for @memberRemoved.
  ///
  /// In en, this message translates to:
  /// **'Member removed'**
  String get memberRemoved;

  /// No description provided for @groupUpdated.
  ///
  /// In en, this message translates to:
  /// **'Group updated'**
  String get groupUpdated;

  /// No description provided for @failedToUpdateGroup.
  ///
  /// In en, this message translates to:
  /// **'Failed to update group: {error}'**
  String failedToUpdateGroup(String error);

  /// No description provided for @failedToDeleteGroup.
  ///
  /// In en, this message translates to:
  /// **'Failed to delete group: {error}'**
  String failedToDeleteGroup(String error);

  /// No description provided for @failedToLeaveGroup.
  ///
  /// In en, this message translates to:
  /// **'Failed to leave group: {error}'**
  String failedToLeaveGroup(String error);

  /// No description provided for @failedToRemoveMember.
  ///
  /// In en, this message translates to:
  /// **'Failed to remove member: {error}'**
  String failedToRemoveMember(String error);

  /// No description provided for @groupCodeLabel.
  ///
  /// In en, this message translates to:
  /// **'Group code'**
  String get groupCodeLabel;

  /// No description provided for @dailyGoal.
  ///
  /// In en, this message translates to:
  /// **'Daily'**
  String get dailyGoal;

  /// No description provided for @weeklyGoal.
  ///
  /// In en, this message translates to:
  /// **'Weekly'**
  String get weeklyGoal;

  /// No description provided for @hUnit.
  ///
  /// In en, this message translates to:
  /// **'h'**
  String get hUnit;

  /// No description provided for @mUnit.
  ///
  /// In en, this message translates to:
  /// **'m'**
  String get mUnit;

  /// No description provided for @sUnit.
  ///
  /// In en, this message translates to:
  /// **'s'**
  String get sUnit;

  /// No description provided for @errorLoadingLeaderboard.
  ///
  /// In en, this message translates to:
  /// **'Error loading leaderboard: {error}'**
  String errorLoadingLeaderboard(String error);

  /// No description provided for @courseHiddenFromLeaderboard.
  ///
  /// In en, this message translates to:
  /// **'Course is hidden from the leaderboard.'**
  String get courseHiddenFromLeaderboard;

  /// No description provided for @courseVisibleInLeaderboard.
  ///
  /// In en, this message translates to:
  /// **'Course is visible in the leaderboard.'**
  String get courseVisibleInLeaderboard;

  /// No description provided for @hideFromLeaderboard.
  ///
  /// In en, this message translates to:
  /// **'Hide from Leaderboard'**
  String get hideFromLeaderboard;

  /// No description provided for @unhideFromLeaderboard.
  ///
  /// In en, this message translates to:
  /// **'Unhide from Leaderboard'**
  String get unhideFromLeaderboard;

  /// No description provided for @noDataAvailable.
  ///
  /// In en, this message translates to:
  /// **'No data available for this period'**
  String get noDataAvailable;

  /// No description provided for @groupLeaderboard.
  ///
  /// In en, this message translates to:
  /// **'Group leaderboard'**
  String get groupLeaderboard;

  /// No description provided for @rankLabel.
  ///
  /// In en, this message translates to:
  /// **'#{rank}'**
  String rankLabel(int rank);

  /// No description provided for @failedToLoadUserData.
  ///
  /// In en, this message translates to:
  /// **'Failed to load user data: {error}'**
  String failedToLoadUserData(String error);

  /// No description provided for @sun.
  ///
  /// In en, this message translates to:
  /// **'Sun'**
  String get sun;

  /// No description provided for @mon.
  ///
  /// In en, this message translates to:
  /// **'Mon'**
  String get mon;

  /// No description provided for @tue.
  ///
  /// In en, this message translates to:
  /// **'Tue'**
  String get tue;

  /// No description provided for @wed.
  ///
  /// In en, this message translates to:
  /// **'Wed'**
  String get wed;

  /// No description provided for @thu.
  ///
  /// In en, this message translates to:
  /// **'Thu'**
  String get thu;

  /// No description provided for @fri.
  ///
  /// In en, this message translates to:
  /// **'Fri'**
  String get fri;

  /// No description provided for @sat.
  ///
  /// In en, this message translates to:
  /// **'Sat'**
  String get sat;

  /// No description provided for @sunday.
  ///
  /// In en, this message translates to:
  /// **'Sunday'**
  String get sunday;

  /// No description provided for @monday.
  ///
  /// In en, this message translates to:
  /// **'Monday'**
  String get monday;

  /// No description provided for @tuesday.
  ///
  /// In en, this message translates to:
  /// **'Tuesday'**
  String get tuesday;

  /// No description provided for @wednesday.
  ///
  /// In en, this message translates to:
  /// **'Wednesday'**
  String get wednesday;

  /// No description provided for @thursday.
  ///
  /// In en, this message translates to:
  /// **'Thursday'**
  String get thursday;

  /// No description provided for @friday.
  ///
  /// In en, this message translates to:
  /// **'Friday'**
  String get friday;

  /// No description provided for @saturday.
  ///
  /// In en, this message translates to:
  /// **'Saturday'**
  String get saturday;

  /// No description provided for @january.
  ///
  /// In en, this message translates to:
  /// **'January'**
  String get january;

  /// No description provided for @february.
  ///
  /// In en, this message translates to:
  /// **'February'**
  String get february;

  /// No description provided for @march.
  ///
  /// In en, this message translates to:
  /// **'March'**
  String get march;

  /// No description provided for @april.
  ///
  /// In en, this message translates to:
  /// **'April'**
  String get april;

  /// No description provided for @may.
  ///
  /// In en, this message translates to:
  /// **'May'**
  String get may;

  /// No description provided for @june.
  ///
  /// In en, this message translates to:
  /// **'June'**
  String get june;

  /// No description provided for @july.
  ///
  /// In en, this message translates to:
  /// **'July'**
  String get july;

  /// No description provided for @august.
  ///
  /// In en, this message translates to:
  /// **'August'**
  String get august;

  /// No description provided for @september.
  ///
  /// In en, this message translates to:
  /// **'September'**
  String get september;

  /// No description provided for @october.
  ///
  /// In en, this message translates to:
  /// **'October'**
  String get october;

  /// No description provided for @november.
  ///
  /// In en, this message translates to:
  /// **'November'**
  String get november;

  /// No description provided for @december.
  ///
  /// In en, this message translates to:
  /// **'December'**
  String get december;

  /// No description provided for @total.
  ///
  /// In en, this message translates to:
  /// **'Total'**
  String get total;

  /// No description provided for @groupSummary.
  ///
  /// In en, this message translates to:
  /// **'Group summary'**
  String get groupSummary;

  /// No description provided for @average.
  ///
  /// In en, this message translates to:
  /// **'Average'**
  String get average;

  /// No description provided for @leader.
  ///
  /// In en, this message translates to:
  /// **'Leader'**
  String get leader;

  /// No description provided for @lowest.
  ///
  /// In en, this message translates to:
  /// **'Lowest'**
  String get lowest;

  /// No description provided for @vsAverage.
  ///
  /// In en, this message translates to:
  /// **'vs. average'**
  String get vsAverage;

  /// No description provided for @studyTimeComparison.
  ///
  /// In en, this message translates to:
  /// **'Study time comparison'**
  String get studyTimeComparison;

  /// No description provided for @performanceVsGroup.
  ///
  /// In en, this message translates to:
  /// **'Performance vs. group'**
  String get performanceVsGroup;

  /// No description provided for @ofAverage.
  ///
  /// In en, this message translates to:
  /// **'of average'**
  String get ofAverage;

  /// No description provided for @studyTimeByDay.
  ///
  /// In en, this message translates to:
  /// **'Study time by day'**
  String get studyTimeByDay;

  /// No description provided for @bestDay.
  ///
  /// In en, this message translates to:
  /// **'Best day'**
  String get bestDay;

  /// No description provided for @avgDay.
  ///
  /// In en, this message translates to:
  /// **'Average/day'**
  String get avgDay;

  /// No description provided for @member.
  ///
  /// In en, this message translates to:
  /// **'Member'**
  String get member;

  /// No description provided for @todayDataTable.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get todayDataTable;

  /// No description provided for @monthDataTable.
  ///
  /// In en, this message translates to:
  /// **'Month'**
  String get monthDataTable;

  /// No description provided for @overThisWeek.
  ///
  /// In en, this message translates to:
  /// **'over this week'**
  String get overThisWeek;

  /// No description provided for @overThisMonth.
  ///
  /// In en, this message translates to:
  /// **'over this month'**
  String get overThisMonth;

  /// No description provided for @overThisYear.
  ///
  /// In en, this message translates to:
  /// **'over this year'**
  String get overThisYear;

  /// No description provided for @hour.
  ///
  /// In en, this message translates to:
  /// **'hour'**
  String get hour;

  /// No description provided for @hours_plural.
  ///
  /// In en, this message translates to:
  /// **'hours'**
  String get hours_plural;

  /// No description provided for @minute.
  ///
  /// In en, this message translates to:
  /// **'minute'**
  String get minute;

  /// No description provided for @minutes_plural.
  ///
  /// In en, this message translates to:
  /// **'minutes'**
  String get minutes_plural;

  /// No description provided for @second.
  ///
  /// In en, this message translates to:
  /// **'second'**
  String get second;

  /// No description provided for @seconds_plural.
  ///
  /// In en, this message translates to:
  /// **'seconds'**
  String get seconds_plural;

  /// No description provided for @jan.
  ///
  /// In en, this message translates to:
  /// **'Jan'**
  String get jan;

  /// No description provided for @feb.
  ///
  /// In en, this message translates to:
  /// **'Feb'**
  String get feb;

  /// No description provided for @mar.
  ///
  /// In en, this message translates to:
  /// **'Mar'**
  String get mar;

  /// No description provided for @apr.
  ///
  /// In en, this message translates to:
  /// **'Apr'**
  String get apr;

  /// No description provided for @mayShort.
  ///
  /// In en, this message translates to:
  /// **'May'**
  String get mayShort;

  /// No description provided for @jun.
  ///
  /// In en, this message translates to:
  /// **'Jun'**
  String get jun;

  /// No description provided for @jul.
  ///
  /// In en, this message translates to:
  /// **'Jul'**
  String get jul;

  /// No description provided for @aug.
  ///
  /// In en, this message translates to:
  /// **'Aug'**
  String get aug;

  /// No description provided for @sep.
  ///
  /// In en, this message translates to:
  /// **'Sep'**
  String get sep;

  /// No description provided for @oct.
  ///
  /// In en, this message translates to:
  /// **'Oct'**
  String get oct;

  /// No description provided for @nov.
  ///
  /// In en, this message translates to:
  /// **'Nov'**
  String get nov;

  /// No description provided for @dec.
  ///
  /// In en, this message translates to:
  /// **'Dec'**
  String get dec;

  /// No description provided for @via.
  ///
  /// In en, this message translates to:
  /// **'via'**
  String get via;

  /// No description provided for @viaTimer.
  ///
  /// In en, this message translates to:
  /// **'via Timer'**
  String get viaTimer;

  /// No description provided for @viaStopwatch.
  ///
  /// In en, this message translates to:
  /// **'via Stopwatch'**
  String get viaStopwatch;

  /// No description provided for @viaPomodoro.
  ///
  /// In en, this message translates to:
  /// **'via Pomodoro'**
  String get viaPomodoro;

  /// No description provided for @viaManualRecording.
  ///
  /// In en, this message translates to:
  /// **'via manual recording'**
  String get viaManualRecording;

  /// No description provided for @startTime.
  ///
  /// In en, this message translates to:
  /// **'Start'**
  String get startTime;

  /// No description provided for @endTime.
  ///
  /// In en, this message translates to:
  /// **'End'**
  String get endTime;

  /// No description provided for @duration.
  ///
  /// In en, this message translates to:
  /// **'Duration'**
  String get duration;

  /// No description provided for @reflection.
  ///
  /// In en, this message translates to:
  /// **'Reflection'**
  String get reflection;

  /// No description provided for @overThis.
  ///
  /// In en, this message translates to:
  /// **'over this'**
  String get overThis;

  /// No description provided for @credits.
  ///
  /// In en, this message translates to:
  /// **'Credit'**
  String get credits;

  /// No description provided for @credits_plural.
  ///
  /// In en, this message translates to:
  /// **'Credits'**
  String get credits_plural;

  /// No description provided for @deleteSession.
  ///
  /// In en, this message translates to:
  /// **'Delete session?'**
  String get deleteSession;

  /// No description provided for @deleteSessionMessage.
  ///
  /// In en, this message translates to:
  /// **'This will remove the session from your history and statistics.'**
  String get deleteSessionMessage;

  /// No description provided for @sessionDeleted.
  ///
  /// In en, this message translates to:
  /// **'Session deleted'**
  String get sessionDeleted;

  /// No description provided for @leaveGroupTitle.
  ///
  /// In en, this message translates to:
  /// **'Leave group?'**
  String get leaveGroupTitle;

  /// No description provided for @leaveGroupMessage.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to leave this group?'**
  String get leaveGroupMessage;

  /// No description provided for @leave.
  ///
  /// In en, this message translates to:
  /// **'Leave'**
  String get leave;

  /// No description provided for @deleteGroupTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete group?'**
  String get deleteGroupTitle;

  /// No description provided for @deleteGroupMessage.
  ///
  /// In en, this message translates to:
  /// **'This will permanently delete the group for all members.'**
  String get deleteGroupMessage;

  /// No description provided for @manageGroup.
  ///
  /// In en, this message translates to:
  /// **'Manage group'**
  String get manageGroup;

  /// No description provided for @admin.
  ///
  /// In en, this message translates to:
  /// **'Admin'**
  String get admin;

  /// No description provided for @removeMember.
  ///
  /// In en, this message translates to:
  /// **'Remove member'**
  String get removeMember;

  /// No description provided for @makeAdmin.
  ///
  /// In en, this message translates to:
  /// **'Make admin'**
  String get makeAdmin;

  /// No description provided for @removeAdmin.
  ///
  /// In en, this message translates to:
  /// **'Remove admin'**
  String get removeAdmin;

  /// No description provided for @owner.
  ///
  /// In en, this message translates to:
  /// **'Owner'**
  String get owner;

  /// No description provided for @memberPromoted.
  ///
  /// In en, this message translates to:
  /// **'Member promoted to admin'**
  String get memberPromoted;

  /// No description provided for @adminDemoted.
  ///
  /// In en, this message translates to:
  /// **'Admin demoted to member'**
  String get adminDemoted;

  /// No description provided for @failedToPromote.
  ///
  /// In en, this message translates to:
  /// **'Failed to promote member'**
  String get failedToPromote;

  /// No description provided for @failedToDemote.
  ///
  /// In en, this message translates to:
  /// **'Failed to demote member'**
  String get failedToDemote;

  /// No description provided for @demoteTooltip.
  ///
  /// In en, this message translates to:
  /// **'Demote to member'**
  String get demoteTooltip;

  /// No description provided for @makeAdminTooltip.
  ///
  /// In en, this message translates to:
  /// **'Make admin'**
  String get makeAdminTooltip;

  /// No description provided for @cannotEnterFutureTime.
  ///
  /// In en, this message translates to:
  /// **'You cannot enter future time.'**
  String get cannotEnterFutureTime;

  /// No description provided for @startTimeLaterThanEndTime.
  ///
  /// In en, this message translates to:
  /// **'Start time can’t be later than end time.'**
  String get startTimeLaterThanEndTime;

  /// No description provided for @timeAddedToCourse.
  ///
  /// In en, this message translates to:
  /// **'Time added to {courseName}'**
  String timeAddedToCourse(String courseName);

  /// No description provided for @currentDay.
  ///
  /// In en, this message translates to:
  /// **'current day'**
  String get currentDay;

  /// No description provided for @thisWeekShort.
  ///
  /// In en, this message translates to:
  /// **'this week'**
  String get thisWeekShort;

  /// No description provided for @thisMonthShort.
  ///
  /// In en, this message translates to:
  /// **'this month'**
  String get thisMonthShort;

  /// No description provided for @thisYearShort.
  ///
  /// In en, this message translates to:
  /// **'this year'**
  String get thisYearShort;

  /// No description provided for @overall.
  ///
  /// In en, this message translates to:
  /// **'overall'**
  String get overall;

  /// No description provided for @dayGoalLabel.
  ///
  /// In en, this message translates to:
  /// **'day goal'**
  String get dayGoalLabel;

  /// No description provided for @weekGoalLabel.
  ///
  /// In en, this message translates to:
  /// **'week goal'**
  String get weekGoalLabel;

  /// No description provided for @on.
  ///
  /// In en, this message translates to:
  /// **'On'**
  String get on;

  /// No description provided for @off.
  ///
  /// In en, this message translates to:
  /// **'Off'**
  String get off;

  /// No description provided for @justSwipeIt.
  ///
  /// In en, this message translates to:
  /// **'Just swipe it'**
  String get justSwipeIt;

  /// No description provided for @customPhotosUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Custom photos are temporarily unavailable.'**
  String get customPhotosUnavailable;

  /// No description provided for @unableToPickImage.
  ///
  /// In en, this message translates to:
  /// **'Unable to pick that image.'**
  String get unableToPickImage;

  /// No description provided for @couldNotSaveProfile.
  ///
  /// In en, this message translates to:
  /// **'Could not save profile. Please try again.'**
  String get couldNotSaveProfile;

  /// No description provided for @yourName.
  ///
  /// In en, this message translates to:
  /// **'Your name'**
  String get yourName;

  /// No description provided for @addPersonalGoal.
  ///
  /// In en, this message translates to:
  /// **'Add a personal goal'**
  String get addPersonalGoal;

  /// No description provided for @nameLabel.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get nameLabel;

  /// No description provided for @nameRequired.
  ///
  /// In en, this message translates to:
  /// **'Name is required'**
  String get nameRequired;

  /// No description provided for @majorLabel.
  ///
  /// In en, this message translates to:
  /// **'Major'**
  String get majorLabel;

  /// No description provided for @majorRequired.
  ///
  /// In en, this message translates to:
  /// **'Major is required'**
  String get majorRequired;

  /// No description provided for @contactLabel.
  ///
  /// In en, this message translates to:
  /// **'How to contact you'**
  String get contactLabel;

  /// No description provided for @contactHint.
  ///
  /// In en, this message translates to:
  /// **'Phone number or tg username idk'**
  String get contactHint;

  /// No description provided for @personalGoalLabel.
  ///
  /// In en, this message translates to:
  /// **'Personal goal'**
  String get personalGoalLabel;

  /// No description provided for @personalGoalHint.
  ///
  /// In en, this message translates to:
  /// **'Become better'**
  String get personalGoalHint;

  /// No description provided for @chooseAvatar.
  ///
  /// In en, this message translates to:
  /// **'Choose an avatar'**
  String get chooseAvatar;

  /// No description provided for @photoLibraryUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Photo library unavailable'**
  String get photoLibraryUnavailable;

  /// No description provided for @iconColor.
  ///
  /// In en, this message translates to:
  /// **'Icon color'**
  String get iconColor;

  /// No description provided for @saved.
  ///
  /// In en, this message translates to:
  /// **'Saved'**
  String get saved;

  /// No description provided for @done.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get done;

  /// No description provided for @stay.
  ///
  /// In en, this message translates to:
  /// **'Stay'**
  String get stay;

  /// No description provided for @resetAndLeave.
  ///
  /// In en, this message translates to:
  /// **'Reset & Leave'**
  String get resetAndLeave;

  /// No description provided for @leavePomodoroTitle.
  ///
  /// In en, this message translates to:
  /// **'Leave pomodoro?'**
  String get leavePomodoroTitle;

  /// No description provided for @leavePomodoroMessage.
  ///
  /// In en, this message translates to:
  /// **'A Pomodoro cycle is running. Reset it before leaving this tab?'**
  String get leavePomodoroMessage;

  /// No description provided for @timeFormatHint.
  ///
  /// In en, this message translates to:
  /// **'HH:MM:SS'**
  String get timeFormatHint;

  /// No description provided for @addCourseFirst.
  ///
  /// In en, this message translates to:
  /// **'Add a course first'**
  String get addCourseFirst;

  /// No description provided for @invalidTimeFormat.
  ///
  /// In en, this message translates to:
  /// **'Enter times as {format}'**
  String invalidTimeFormat(String format);

  /// No description provided for @signIn.
  ///
  /// In en, this message translates to:
  /// **'Sign in'**
  String get signIn;

  /// No description provided for @register.
  ///
  /// In en, this message translates to:
  /// **'Register'**
  String get register;

  /// No description provided for @loginSubtitle.
  ///
  /// In en, this message translates to:
  /// **'We missed you pal'**
  String get loginSubtitle;

  /// No description provided for @registerSubtitle.
  ///
  /// In en, this message translates to:
  /// **'<3'**
  String get registerSubtitle;

  /// No description provided for @emailAddress.
  ///
  /// In en, this message translates to:
  /// **'Email address'**
  String get emailAddress;

  /// No description provided for @password.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get password;

  /// No description provided for @displayName.
  ///
  /// In en, this message translates to:
  /// **'Display name'**
  String get displayName;

  /// No description provided for @createAccount.
  ///
  /// In en, this message translates to:
  /// **'Create account'**
  String get createAccount;

  /// No description provided for @afterCreatingAccount.
  ///
  /// In en, this message translates to:
  /// **'After creating an account, you\'ll need to verify your email to start using the app.'**
  String get afterCreatingAccount;

  /// No description provided for @signedInSuccessfully.
  ///
  /// In en, this message translates to:
  /// **'Signed in successfully'**
  String get signedInSuccessfully;

  /// No description provided for @enterEmail.
  ///
  /// In en, this message translates to:
  /// **'Please enter your email address.'**
  String get enterEmail;

  /// No description provided for @invalidEmail.
  ///
  /// In en, this message translates to:
  /// **'Please enter a valid email address.'**
  String get invalidEmail;

  /// No description provided for @enterPassword.
  ///
  /// In en, this message translates to:
  /// **'Enter your password.'**
  String get enterPassword;

  /// No description provided for @displayNameLength.
  ///
  /// In en, this message translates to:
  /// **'Display name must be at least 2 characters.'**
  String get displayNameLength;

  /// No description provided for @passwordLength.
  ///
  /// In en, this message translates to:
  /// **'Password must be at least 8 characters.'**
  String get passwordLength;

  /// No description provided for @passwordInvalidChars.
  ///
  /// In en, this message translates to:
  /// **'Only A–Z, a–z, 0–9 and allowed symbols are supported.'**
  String get passwordInvalidChars;

  /// No description provided for @displayNameInvalidChars.
  ///
  /// In en, this message translates to:
  /// **'Display name can contain only letters and numbers.'**
  String get displayNameInvalidChars;

  /// No description provided for @min8Chars.
  ///
  /// In en, this message translates to:
  /// **'Minimum 8 characters.'**
  String get min8Chars;

  /// No description provided for @loadingProfile.
  ///
  /// In en, this message translates to:
  /// **'Loading your profile'**
  String get loadingProfile;

  /// No description provided for @loggingOut.
  ///
  /// In en, this message translates to:
  /// **'Logging out of account...'**
  String get loggingOut;

  /// No description provided for @forgotPassword.
  ///
  /// In en, this message translates to:
  /// **'Forgot password?'**
  String get forgotPassword;

  /// No description provided for @resetPasswordTitle.
  ///
  /// In en, this message translates to:
  /// **'Reset password'**
  String get resetPasswordTitle;

  /// No description provided for @resetPasswordSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Enter your email. We will send a 6-digit code.'**
  String get resetPasswordSubtitle;

  /// No description provided for @backToSignIn.
  ///
  /// In en, this message translates to:
  /// **'Back to sign in'**
  String get backToSignIn;

  /// No description provided for @invalidEmailFormat.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid email address.'**
  String get invalidEmailFormat;

  /// No description provided for @sessionNotes.
  ///
  /// In en, this message translates to:
  /// **'Session notes'**
  String get sessionNotes;

  /// No description provided for @sessionNotesHint.
  ///
  /// In en, this message translates to:
  /// **'Add notes for this session'**
  String get sessionNotesHint;

  /// No description provided for @sendNotes.
  ///
  /// In en, this message translates to:
  /// **'Send notes'**
  String get sendNotes;

  /// No description provided for @updateNotes.
  ///
  /// In en, this message translates to:
  /// **'Update notes'**
  String get updateNotes;

  /// No description provided for @notesSaved.
  ///
  /// In en, this message translates to:
  /// **'Notes saved'**
  String get notesSaved;

  /// No description provided for @failedToPrepareData.
  ///
  /// In en, this message translates to:
  /// **'Failed to prepare offline data.'**
  String get failedToPrepareData;

  /// No description provided for @sessionFinished.
  ///
  /// In en, this message translates to:
  /// **'Session finished: {duration}'**
  String sessionFinished(String duration);

  /// No description provided for @whatDidYouWorkOn.
  ///
  /// In en, this message translates to:
  /// **'What did you work on?'**
  String get whatDidYouWorkOn;

  /// No description provided for @failedToSaveReflection.
  ///
  /// In en, this message translates to:
  /// **'Failed to save reflection: {error}'**
  String failedToSaveReflection(String error);

  /// No description provided for @skip.
  ///
  /// In en, this message translates to:
  /// **'Skip'**
  String get skip;

  /// No description provided for @streakDays.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{{count} day streak} other{{count} days streak}}'**
  String streakDays(int count);

  /// No description provided for @noStreakYet.
  ///
  /// In en, this message translates to:
  /// **'No streak yet'**
  String get noStreakYet;

  /// No description provided for @nudgeWaitMinutes.
  ///
  /// In en, this message translates to:
  /// **'Please wait {minutes} {minutes, plural, one{minute} other{minutes}} before nudging again.'**
  String nudgeWaitMinutes(int minutes);

  /// No description provided for @nudgeWaitSeconds.
  ///
  /// In en, this message translates to:
  /// **'Please wait {seconds} {seconds, plural, one{second} other{seconds}} before nudging again.'**
  String nudgeWaitSeconds(int seconds);

  /// No description provided for @memberCannotReceiveNudges.
  ///
  /// In en, this message translates to:
  /// **'This member cannot receive nudges yet.'**
  String get memberCannotReceiveNudges;

  /// No description provided for @nudgeSent.
  ///
  /// In en, this message translates to:
  /// **'Nudge sent.'**
  String get nudgeSent;

  /// No description provided for @failedToSendNudge.
  ///
  /// In en, this message translates to:
  /// **'Failed to send nudge: {error}'**
  String failedToSendNudge(String error);

  /// No description provided for @cannotNudgeSelf.
  ///
  /// In en, this message translates to:
  /// **'You cannot nudge yourself.'**
  String get cannotNudgeSelf;

  /// No description provided for @userProhibitedNudge.
  ///
  /// In en, this message translates to:
  /// **'This user has disabled nudges.'**
  String get userProhibitedNudge;

  /// No description provided for @leaderboardHintMessage.
  ///
  /// In en, this message translates to:
  /// **'• You can tap any user in the leaderboard to view their study time.\n• Tap the hand icon next to a friend’s avatar to nudge him.'**
  String get leaderboardHintMessage;

  /// No description provided for @habitsNavLabel.
  ///
  /// In en, this message translates to:
  /// **'Habits'**
  String get habitsNavLabel;

  /// No description provided for @habitStatistics.
  ///
  /// In en, this message translates to:
  /// **'Habit statistics'**
  String get habitStatistics;

  /// No description provided for @habitsTabProgress.
  ///
  /// In en, this message translates to:
  /// **'Progress'**
  String get habitsTabProgress;

  /// No description provided for @habitsTabList.
  ///
  /// In en, this message translates to:
  /// **'My habits'**
  String get habitsTabList;

  /// No description provided for @habitsPleaseSignIn.
  ///
  /// In en, this message translates to:
  /// **'Please sign in'**
  String get habitsPleaseSignIn;

  /// No description provided for @habitsEmptyToday.
  ///
  /// In en, this message translates to:
  /// **'Nothing to do today. Cheers!'**
  String get habitsEmptyToday;

  /// No description provided for @habitsListError.
  ///
  /// In en, this message translates to:
  /// **'Error: {error}'**
  String habitsListError(String error);

  /// No description provided for @habitsEmptyListTitle.
  ///
  /// In en, this message translates to:
  /// **'No habits yet'**
  String get habitsEmptyListTitle;

  /// No description provided for @habitsEmptyListCta.
  ///
  /// In en, this message translates to:
  /// **'Create your first'**
  String get habitsEmptyListCta;

  /// No description provided for @habitRequirementMarkDone.
  ///
  /// In en, this message translates to:
  /// **'Mark as done'**
  String get habitRequirementMarkDone;

  /// No description provided for @habitRequirementToday.
  ///
  /// In en, this message translates to:
  /// **'{current} / {target} {unit} today'**
  String habitRequirementToday(String current, String target, String unit);

  /// No description provided for @habitRequirementTodayNoUnit.
  ///
  /// In en, this message translates to:
  /// **'{current} / {target} today'**
  String habitRequirementTodayNoUnit(String current, String target);

  /// No description provided for @habitFrequencyEveryDay.
  ///
  /// In en, this message translates to:
  /// **'Every day'**
  String get habitFrequencyEveryDay;

  /// No description provided for @habitFrequencySpecificMonth.
  ///
  /// In en, this message translates to:
  /// **'Specific days of month'**
  String get habitFrequencySpecificMonth;

  /// No description provided for @habitFrequencySpecificDates.
  ///
  /// In en, this message translates to:
  /// **'Specific dates'**
  String get habitFrequencySpecificDates;

  /// No description provided for @habitFrequencyDaysLabel.
  ///
  /// In en, this message translates to:
  /// **'Days: {days}'**
  String habitFrequencyDaysLabel(String days);

  /// No description provided for @habitFrequencyInterval.
  ///
  /// In en, this message translates to:
  /// **'Every {days} {days, plural, one{day} other{days}}'**
  String habitFrequencyInterval(int days);

  /// No description provided for @habitFrequencyTimesPerPeriod.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{{count} time per {period}} other{{count} times per {period}}}'**
  String habitFrequencyTimesPerPeriod(int count, String period);

  /// No description provided for @habitPeriodWeek.
  ///
  /// In en, this message translates to:
  /// **'Week'**
  String get habitPeriodWeek;

  /// No description provided for @habitPeriodMonth.
  ///
  /// In en, this message translates to:
  /// **'Month'**
  String get habitPeriodMonth;

  /// No description provided for @habitPeriodYear.
  ///
  /// In en, this message translates to:
  /// **'Year'**
  String get habitPeriodYear;

  /// No description provided for @habitDailyOverview.
  ///
  /// In en, this message translates to:
  /// **'Daily overview'**
  String get habitDailyOverview;

  /// No description provided for @habitNoHabitsThisDay.
  ///
  /// In en, this message translates to:
  /// **'No habits completed on this day.'**
  String get habitNoHabitsThisDay;

  /// No description provided for @habitMinutesShort.
  ///
  /// In en, this message translates to:
  /// **'min'**
  String get habitMinutesShort;

  /// No description provided for @habitLogSetTotal.
  ///
  /// In en, this message translates to:
  /// **'Set total'**
  String get habitLogSetTotal;

  /// No description provided for @habitLogAddMore.
  ///
  /// In en, this message translates to:
  /// **'Add more'**
  String get habitLogAddMore;

  /// No description provided for @habitUpdateProgress.
  ///
  /// In en, this message translates to:
  /// **'Update progress'**
  String get habitUpdateProgress;

  /// No description provided for @habitLogSetValueTitle.
  ///
  /// In en, this message translates to:
  /// **'Set value'**
  String get habitLogSetValueTitle;

  /// No description provided for @habitClearTime.
  ///
  /// In en, this message translates to:
  /// **'Clear time'**
  String get habitClearTime;

  /// No description provided for @habitProgressLabel.
  ///
  /// In en, this message translates to:
  /// **'Progress, {date}'**
  String habitProgressLabel(String date);

  /// No description provided for @habitLogSettingTotal.
  ///
  /// In en, this message translates to:
  /// **'Setting total to {total}'**
  String habitLogSettingTotal(String total);

  /// No description provided for @habitLogAdding.
  ///
  /// In en, this message translates to:
  /// **'Adding {value} to {existing}'**
  String habitLogAdding(String value, String existing);

  /// No description provided for @habitGoalLabel.
  ///
  /// In en, this message translates to:
  /// **'Goal: {goal}'**
  String habitGoalLabel(String goal);

  /// No description provided for @habitCreateTitle.
  ///
  /// In en, this message translates to:
  /// **'Create new habit'**
  String get habitCreateTitle;

  /// No description provided for @habitTrackingTitle.
  ///
  /// In en, this message translates to:
  /// **'Tracking type'**
  String get habitTrackingTitle;

  /// No description provided for @habitExplainHabit.
  ///
  /// In en, this message translates to:
  /// **'Explain your habit'**
  String get habitExplainHabit;

  /// No description provided for @habitNameLabel.
  ///
  /// In en, this message translates to:
  /// **'Habit name'**
  String get habitNameLabel;

  /// No description provided for @habitNameHint.
  ///
  /// In en, this message translates to:
  /// **''**
  String get habitNameHint;

  /// No description provided for @habitCategoryLabel.
  ///
  /// In en, this message translates to:
  /// **'Category'**
  String get habitCategoryLabel;

  /// No description provided for @habitCategoryNew.
  ///
  /// In en, this message translates to:
  /// **'New category'**
  String get habitCategoryNew;

  /// No description provided for @habitCategoryNameLabel.
  ///
  /// In en, this message translates to:
  /// **'Category name'**
  String get habitCategoryNameLabel;

  /// No description provided for @habitCategoryNameHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. reading'**
  String get habitCategoryNameHint;

  /// No description provided for @habitCategoryDeleteTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete category'**
  String get habitCategoryDeleteTitle;

  /// No description provided for @habitCategoryDeleteMessage.
  ///
  /// In en, this message translates to:
  /// **'Delete \"{name}\"? This cannot be undone.'**
  String habitCategoryDeleteMessage(String name);

  /// No description provided for @habitCategoryCreateAction.
  ///
  /// In en, this message translates to:
  /// **'Create custom'**
  String get habitCategoryCreateAction;

  /// No description provided for @habitBack.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get habitBack;

  /// No description provided for @habitNext.
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get habitNext;

  /// No description provided for @habitYesNo.
  ///
  /// In en, this message translates to:
  /// **'Yes / No'**
  String get habitYesNo;

  /// No description provided for @habitNumeric.
  ///
  /// In en, this message translates to:
  /// **'Numeric'**
  String get habitNumeric;

  /// No description provided for @habitTime.
  ///
  /// In en, this message translates to:
  /// **'Time'**
  String get habitTime;

  /// No description provided for @habitTrackingYesNoDescription.
  ///
  /// In en, this message translates to:
  /// **'Mark whether you completed the habit or not.'**
  String get habitTrackingYesNoDescription;

  /// No description provided for @habitTrackingNumericDescription.
  ///
  /// In en, this message translates to:
  /// **'Set a specific number to reach each day.'**
  String get habitTrackingNumericDescription;

  /// No description provided for @habitTrackingTimeDescription.
  ///
  /// In en, this message translates to:
  /// **'Set a time duration as your daily goal.'**
  String get habitTrackingTimeDescription;

  /// No description provided for @habitComparatorAtLeast.
  ///
  /// In en, this message translates to:
  /// **'At least'**
  String get habitComparatorAtLeast;

  /// No description provided for @habitComparatorLessThan.
  ///
  /// In en, this message translates to:
  /// **'Less than'**
  String get habitComparatorLessThan;

  /// No description provided for @habitComparatorExactly.
  ///
  /// In en, this message translates to:
  /// **'Exactly'**
  String get habitComparatorExactly;

  /// No description provided for @habitComparatorAny.
  ///
  /// In en, this message translates to:
  /// **'Any value'**
  String get habitComparatorAny;

  /// No description provided for @habitValueLabel.
  ///
  /// In en, this message translates to:
  /// **'Value'**
  String get habitValueLabel;

  /// No description provided for @habitUnitLabel.
  ///
  /// In en, this message translates to:
  /// **'Unit'**
  String get habitUnitLabel;

  /// No description provided for @habitUnitHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. pages'**
  String get habitUnitHint;

  /// No description provided for @habitPerDay.
  ///
  /// In en, this message translates to:
  /// **'per day'**
  String get habitPerDay;

  /// No description provided for @habitTimeLabel.
  ///
  /// In en, this message translates to:
  /// **'hours : minutes : seconds'**
  String get habitTimeLabel;

  /// No description provided for @habitTimePlaceholder.
  ///
  /// In en, this message translates to:
  /// **'00:00:00'**
  String get habitTimePlaceholder;

  /// No description provided for @habitFrequencyPrompt.
  ///
  /// In en, this message translates to:
  /// **'Choose how often the habit should repeat'**
  String get habitFrequencyPrompt;

  /// No description provided for @habitFrequencySpecificTitle.
  ///
  /// In en, this message translates to:
  /// **'Specific days'**
  String get habitFrequencySpecificTitle;

  /// No description provided for @habitFrequencyDailyDescription.
  ///
  /// In en, this message translates to:
  /// **'Do the habit daily without skipping.'**
  String get habitFrequencyDailyDescription;

  /// No description provided for @habitFrequencySpecificDescription.
  ///
  /// In en, this message translates to:
  /// **'Choose exact weekdays or dates.'**
  String get habitFrequencySpecificDescription;

  /// No description provided for @habitFrequencyPeriodWeekLabel.
  ///
  /// In en, this message translates to:
  /// **'Week'**
  String get habitFrequencyPeriodWeekLabel;

  /// No description provided for @habitFrequencyPeriodMonthLabel.
  ///
  /// In en, this message translates to:
  /// **'Month'**
  String get habitFrequencyPeriodMonthLabel;

  /// No description provided for @habitFrequencyPeriodYearLabel.
  ///
  /// In en, this message translates to:
  /// **'Year'**
  String get habitFrequencyPeriodYearLabel;

  /// No description provided for @habitFrequencyTimesPerPeriodTitle.
  ///
  /// In en, this message translates to:
  /// **'Days per period'**
  String get habitFrequencyTimesPerPeriodTitle;

  /// No description provided for @habitFrequencyTimesPerPeriodDescription.
  ///
  /// In en, this message translates to:
  /// **'Set how many days within a week, month, or year.'**
  String get habitFrequencyTimesPerPeriodDescription;

  /// No description provided for @habitTimesPerLabel.
  ///
  /// In en, this message translates to:
  /// **'times per'**
  String get habitTimesPerLabel;

  /// No description provided for @habitFrequencyWorkRestTitle.
  ///
  /// In en, this message translates to:
  /// **'Work / Rest'**
  String get habitFrequencyWorkRestTitle;

  /// No description provided for @habitFrequencyWorkRestDescription.
  ///
  /// In en, this message translates to:
  /// **'Set a repeating cycle for the habit. Work — days when you do the habit. Rest — days off.'**
  String get habitFrequencyWorkRestDescription;

  /// No description provided for @habitWorkLabel.
  ///
  /// In en, this message translates to:
  /// **'Work'**
  String get habitWorkLabel;

  /// No description provided for @habitRestLabel.
  ///
  /// In en, this message translates to:
  /// **'Rest'**
  String get habitRestLabel;

  /// No description provided for @habitChooseTimeRangeTitle.
  ///
  /// In en, this message translates to:
  /// **'Choose the time range when you want to start'**
  String get habitChooseTimeRangeTitle;

  /// No description provided for @habitSchedulingTitle.
  ///
  /// In en, this message translates to:
  /// **'Scheduling'**
  String get habitSchedulingTitle;

  /// No description provided for @habitStartDateLabel.
  ///
  /// In en, this message translates to:
  /// **'Start date'**
  String get habitStartDateLabel;

  /// No description provided for @habitEndDateLabel.
  ///
  /// In en, this message translates to:
  /// **'End date (optional)'**
  String get habitEndDateLabel;

  /// No description provided for @habitNoEndDate.
  ///
  /// In en, this message translates to:
  /// **'No end date'**
  String get habitNoEndDate;

  /// No description provided for @habitCreateAction.
  ///
  /// In en, this message translates to:
  /// **'Create habit'**
  String get habitCreateAction;

  /// No description provided for @habitForever.
  ///
  /// In en, this message translates to:
  /// **'Forever'**
  String get habitForever;

  /// No description provided for @habitAddDateAction.
  ///
  /// In en, this message translates to:
  /// **'Add date'**
  String get habitAddDateAction;

  /// No description provided for @habitScheduleTitle.
  ///
  /// In en, this message translates to:
  /// **'Schedule'**
  String get habitScheduleTitle;

  /// No description provided for @habitFrequencySectionTitle.
  ///
  /// In en, this message translates to:
  /// **'Frequency'**
  String get habitFrequencySectionTitle;

  /// No description provided for @habitSelectDatePlaceholder.
  ///
  /// In en, this message translates to:
  /// **'Select'**
  String get habitSelectDatePlaceholder;

  /// No description provided for @habitDeleteTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete habit?'**
  String get habitDeleteTitle;

  /// No description provided for @habitDeleteMessage.
  ///
  /// In en, this message translates to:
  /// **'This action cannot be undone.'**
  String get habitDeleteMessage;

  /// No description provided for @habitEditTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit habit'**
  String get habitEditTitle;

  /// No description provided for @habitGeneralSection.
  ///
  /// In en, this message translates to:
  /// **'General'**
  String get habitGeneralSection;

  /// No description provided for @habitAdvancedSection.
  ///
  /// In en, this message translates to:
  /// **'Advanced'**
  String get habitAdvancedSection;

  /// No description provided for @habitConnectCourse.
  ///
  /// In en, this message translates to:
  /// **'Connect course'**
  String get habitConnectCourse;

  /// No description provided for @habitCourseSyncHint.
  ///
  /// In en, this message translates to:
  /// **'Syncs progress when you study for these courses.'**
  String get habitCourseSyncHint;

  /// No description provided for @habitCourseNumericWarning.
  ///
  /// In en, this message translates to:
  /// **'Switch to Yes/No or Time to connect courses.'**
  String get habitCourseNumericWarning;

  /// No description provided for @habitReminderDisabledTitle.
  ///
  /// In en, this message translates to:
  /// **'Remind me'**
  String get habitReminderDisabledTitle;

  /// No description provided for @habitReminderDisabledSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Coming soon'**
  String get habitReminderDisabledSubtitle;

  /// No description provided for @habitArchiveTitle.
  ///
  /// In en, this message translates to:
  /// **'Archive habit'**
  String get habitArchiveTitle;

  /// No description provided for @habitArchivedLabel.
  ///
  /// In en, this message translates to:
  /// **'Archived'**
  String get habitArchivedLabel;

  /// No description provided for @habitResetProgressTitle.
  ///
  /// In en, this message translates to:
  /// **'Reset habit progress'**
  String get habitResetProgressTitle;

  /// No description provided for @habitResetProgressSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Clears all history'**
  String get habitResetProgressSubtitle;

  /// No description provided for @habitResetProgressConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Reset habit progress?'**
  String get habitResetProgressConfirmTitle;

  /// No description provided for @habitResetProgressConfirmMessage.
  ///
  /// In en, this message translates to:
  /// **'This will delete all completion history for this habit. It cannot be undone.'**
  String get habitResetProgressConfirmMessage;

  /// No description provided for @habitUnarchived.
  ///
  /// In en, this message translates to:
  /// **'Habit unarchived'**
  String get habitUnarchived;

  /// No description provided for @connectionsTabLabel.
  ///
  /// In en, this message translates to:
  /// **'People'**
  String get connectionsTabLabel;

  /// No description provided for @addPersonTitle.
  ///
  /// In en, this message translates to:
  /// **'Add Person'**
  String get addPersonTitle;

  /// No description provided for @editPersonTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit Person'**
  String get editPersonTitle;

  /// No description provided for @personNameLabel.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get personNameLabel;

  /// No description provided for @personNameHint.
  ///
  /// In en, this message translates to:
  /// **'Enter full name'**
  String get personNameHint;

  /// No description provided for @groupsLabel.
  ///
  /// In en, this message translates to:
  /// **'Groups'**
  String get groupsLabel;

  /// No description provided for @tagsLabel.
  ///
  /// In en, this message translates to:
  /// **'Tags'**
  String get tagsLabel;

  /// No description provided for @phoneLabel.
  ///
  /// In en, this message translates to:
  /// **'Phone'**
  String get phoneLabel;

  /// No description provided for @emailLabel.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get emailLabel;

  /// No description provided for @notesLabel.
  ///
  /// In en, this message translates to:
  /// **'Notes'**
  String get notesLabel;

  /// No description provided for @lastContactedLabel.
  ///
  /// In en, this message translates to:
  /// **'Last contacted'**
  String get lastContactedLabel;

  /// No description provided for @remindMeLabel.
  ///
  /// In en, this message translates to:
  /// **'Remind me to reach out'**
  String get remindMeLabel;

  /// No description provided for @manageGroupsTitle.
  ///
  /// In en, this message translates to:
  /// **'Manage Groups'**
  String get manageGroupsTitle;

  /// No description provided for @interactionLogTitle.
  ///
  /// In en, this message translates to:
  /// **'Interaction Log'**
  String get interactionLogTitle;

  /// No description provided for @markContactedToday.
  ///
  /// In en, this message translates to:
  /// **'Mark contacted today'**
  String get markContactedToday;

  /// No description provided for @noConnectionsPlaceholder.
  ///
  /// In en, this message translates to:
  /// **'No people yet'**
  String get noConnectionsPlaceholder;

  /// No description provided for @searchConnectionsHint.
  ///
  /// In en, this message translates to:
  /// **'Search people...'**
  String get searchConnectionsHint;

  /// No description provided for @filterAll.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get filterAll;

  /// No description provided for @sortByRecent.
  ///
  /// In en, this message translates to:
  /// **'Recent'**
  String get sortByRecent;

  /// No description provided for @sortByName.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get sortByName;

  /// No description provided for @sortByPriority.
  ///
  /// In en, this message translates to:
  /// **'Priority'**
  String get sortByPriority;

  /// No description provided for @deleteContactTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete Contact?'**
  String get deleteContactTitle;

  /// No description provided for @deleteContactMessage.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete \"{name}\"?'**
  String deleteContactMessage(String name);

  /// No description provided for @deleteConnectionGroupTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete Group?'**
  String get deleteConnectionGroupTitle;

  /// No description provided for @deleteConnectionGroupMessage.
  ///
  /// In en, this message translates to:
  /// **'This will remove \"{name}\" from all contacts. This action cannot be undone.'**
  String deleteConnectionGroupMessage(String name);

  /// No description provided for @renameGroup.
  ///
  /// In en, this message translates to:
  /// **'Rename'**
  String get renameGroup;

  /// No description provided for @newGroup.
  ///
  /// In en, this message translates to:
  /// **'New Group'**
  String get newGroup;

  /// No description provided for @editGroup.
  ///
  /// In en, this message translates to:
  /// **'Edit Group'**
  String get editGroup;

  /// No description provided for @groupNameLabel.
  ///
  /// In en, this message translates to:
  /// **'Group name'**
  String get groupNameLabel;

  /// No description provided for @noInteractionsYet.
  ///
  /// In en, this message translates to:
  /// **'No interactions recorded yet'**
  String get noInteractionsYet;

  /// No description provided for @addInteractionHint.
  ///
  /// In en, this message translates to:
  /// **'What did you discuss?'**
  String get addInteractionHint;

  /// No description provided for @habitUnarchiveAction.
  ///
  /// In en, this message translates to:
  /// **'Unarchive'**
  String get habitUnarchiveAction;

  /// No description provided for @archivedHabitsTitle.
  ///
  /// In en, this message translates to:
  /// **'Archived habits'**
  String get archivedHabitsTitle;

  /// No description provided for @archivedHabitsEmpty.
  ///
  /// In en, this message translates to:
  /// **'No archived habits'**
  String get archivedHabitsEmpty;

  /// No description provided for @habitsCalendarTitle.
  ///
  /// In en, this message translates to:
  /// **'Calendar'**
  String get habitsCalendarTitle;

  /// No description provided for @habitTimeHourShort.
  ///
  /// In en, this message translates to:
  /// **'H'**
  String get habitTimeHourShort;

  /// No description provided for @habitTimeMinuteShort.
  ///
  /// In en, this message translates to:
  /// **'M'**
  String get habitTimeMinuteShort;

  /// No description provided for @habitTimeSecondShort.
  ///
  /// In en, this message translates to:
  /// **'S'**
  String get habitTimeSecondShort;

  /// No description provided for @habitCategoryStudy.
  ///
  /// In en, this message translates to:
  /// **'Study'**
  String get habitCategoryStudy;

  /// No description provided for @habitCategorySports.
  ///
  /// In en, this message translates to:
  /// **'Sports'**
  String get habitCategorySports;

  /// No description provided for @habitCategoryQuitBadHabit.
  ///
  /// In en, this message translates to:
  /// **'Quit a bad habit'**
  String get habitCategoryQuitBadHabit;

  /// No description provided for @habitCategoryHome.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get habitCategoryHome;

  /// No description provided for @habitCategoryHealth.
  ///
  /// In en, this message translates to:
  /// **'Health'**
  String get habitCategoryHealth;

  /// No description provided for @habitCategoryWork.
  ///
  /// In en, this message translates to:
  /// **'Work'**
  String get habitCategoryWork;

  /// No description provided for @habitResetProgressMessage.
  ///
  /// In en, this message translates to:
  /// **'All progress history for this habit will be deleted. This cannot be undone.'**
  String get habitResetProgressMessage;

  /// No description provided for @habitResetProgressAction.
  ///
  /// In en, this message translates to:
  /// **'Reset'**
  String get habitResetProgressAction;

  /// No description provided for @habitFrequencyRepeatsTitle.
  ///
  /// In en, this message translates to:
  /// **'Repeats'**
  String get habitFrequencyRepeatsTitle;

  /// No description provided for @habitFrequencyEveryXDays.
  ///
  /// In en, this message translates to:
  /// **'Every {count} days'**
  String habitFrequencyEveryXDays(int count);

  /// No description provided for @habitDragToCategorize.
  ///
  /// In en, this message translates to:
  /// **'Drag to categorize'**
  String get habitDragToCategorize;

  /// No description provided for @habitStatsEmptyState.
  ///
  /// In en, this message translates to:
  /// **'No habits found. Add a habit to start tracking your progress. It is cool trust me!'**
  String get habitStatsEmptyState;

  /// No description provided for @habitStatsCompletionRate.
  ///
  /// In en, this message translates to:
  /// **'Completion rate'**
  String get habitStatsCompletionRate;

  /// No description provided for @habitStatsCompleted.
  ///
  /// In en, this message translates to:
  /// **'Completed'**
  String get habitStatsCompleted;

  /// No description provided for @habitStatsMissed.
  ///
  /// In en, this message translates to:
  /// **'Missed'**
  String get habitStatsMissed;

  /// No description provided for @habitReportDownload.
  ///
  /// In en, this message translates to:
  /// **'Download Report'**
  String get habitReportDownload;

  /// No description provided for @habitReportTitle.
  ///
  /// In en, this message translates to:
  /// **'Download report'**
  String get habitReportTitle;

  /// No description provided for @habitReportDownloadAction.
  ///
  /// In en, this message translates to:
  /// **'Download'**
  String get habitReportDownloadAction;

  /// No description provided for @shareFile.
  ///
  /// In en, this message translates to:
  /// **'Share file'**
  String get shareFile;

  /// No description provided for @habitReportSaved.
  ///
  /// In en, this message translates to:
  /// **'Saved to: {path}'**
  String habitReportSaved(String path);

  /// No description provided for @habitReportFileName.
  ///
  /// In en, this message translates to:
  /// **'habits_{month}_{year}'**
  String habitReportFileName(String month, int year);

  /// No description provided for @habitReportFailed.
  ///
  /// In en, this message translates to:
  /// **'Export failed: {error}'**
  String habitReportFailed(String error);

  /// No description provided for @csvDay.
  ///
  /// In en, this message translates to:
  /// **'Day'**
  String get csvDay;

  /// No description provided for @csvTotalCompleted.
  ///
  /// In en, this message translates to:
  /// **'Total completed'**
  String get csvTotalCompleted;

  /// No description provided for @csvTarget.
  ///
  /// In en, this message translates to:
  /// **'Target'**
  String get csvTarget;

  /// No description provided for @csvRate.
  ///
  /// In en, this message translates to:
  /// **'Rate'**
  String get csvRate;

  /// No description provided for @exportFormat.
  ///
  /// In en, this message translates to:
  /// **'Export format'**
  String get exportFormat;

  /// No description provided for @exportFormatCSV.
  ///
  /// In en, this message translates to:
  /// **'CSV'**
  String get exportFormatCSV;

  /// No description provided for @exportFormatExcel.
  ///
  /// In en, this message translates to:
  /// **'Excel'**
  String get exportFormatExcel;

  /// No description provided for @exportSuccess.
  ///
  /// In en, this message translates to:
  /// **'Export successful'**
  String get exportSuccess;

  /// No description provided for @exportSuccessMessage.
  ///
  /// In en, this message translates to:
  /// **'Your file has been saved successfully'**
  String get exportSuccessMessage;

  /// No description provided for @openFile.
  ///
  /// In en, this message translates to:
  /// **'Open file'**
  String get openFile;

  /// No description provided for @close.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get close;

  /// No description provided for @interactionCalendarTitle.
  ///
  /// In en, this message translates to:
  /// **'Interaction Calendar'**
  String get interactionCalendarTitle;

  /// No description provided for @signInToViewConnections.
  ///
  /// In en, this message translates to:
  /// **'Please sign in to view your people.'**
  String get signInToViewConnections;

  /// No description provided for @personNotFound.
  ///
  /// In en, this message translates to:
  /// **'Person not found'**
  String get personNotFound;

  /// No description provided for @errorSaving.
  ///
  /// In en, this message translates to:
  /// **'Error saving: {error}'**
  String errorSaving(String error);

  /// No description provided for @add.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get add;

  /// No description provided for @habitWeekNext.
  ///
  /// In en, this message translates to:
  /// **'Next week'**
  String get habitWeekNext;

  /// No description provided for @habitWeekLast.
  ///
  /// In en, this message translates to:
  /// **'Last week'**
  String get habitWeekLast;

  /// No description provided for @habitWeeksAgo.
  ///
  /// In en, this message translates to:
  /// **'weeks ago'**
  String get habitWeeksAgo;

  /// No description provided for @habitWeekCurrent.
  ///
  /// In en, this message translates to:
  /// **'This week'**
  String get habitWeekCurrent;

  /// No description provided for @copiedToClipboard.
  ///
  /// In en, this message translates to:
  /// **'Copied to clipboard'**
  String get copiedToClipboard;

  /// No description provided for @sessionNotificationTitle.
  ///
  /// In en, this message translates to:
  /// **'Session reminder'**
  String get sessionNotificationTitle;

  /// No description provided for @sessionNotificationBody.
  ///
  /// In en, this message translates to:
  /// **'It is time for your {name} session.'**
  String sessionNotificationBody(String name);

  /// No description provided for @memberFallbackName.
  ///
  /// In en, this message translates to:
  /// **'Member'**
  String get memberFallbackName;

  /// No description provided for @joinCodeTooShort.
  ///
  /// In en, this message translates to:
  /// **'Use at least 8 characters.'**
  String get joinCodeTooShort;

  /// No description provided for @sessionNotificationAction.
  ///
  /// In en, this message translates to:
  /// **'Start session'**
  String get sessionNotificationAction;

  /// No description provided for @updateRequiredTitle.
  ///
  /// In en, this message translates to:
  /// **'Update NUmer'**
  String get updateRequiredTitle;

  /// No description provided for @updateRequiredBody.
  ///
  /// In en, this message translates to:
  /// **'This version is no longer supported. Install the latest version to continue.'**
  String get updateRequiredBody;

  /// No description provided for @updateRequiredAction.
  ///
  /// In en, this message translates to:
  /// **'Update'**
  String get updateRequiredAction;

  /// No description provided for @codeScreenTitle.
  ///
  /// In en, this message translates to:
  /// **'Enter the code'**
  String get codeScreenTitle;

  /// No description provided for @codeScreenSubtitle.
  ///
  /// In en, this message translates to:
  /// **'We sent a 6-digit code to {email}'**
  String codeScreenSubtitle(String email);

  /// No description provided for @codeFieldLabel.
  ///
  /// In en, this message translates to:
  /// **'6-digit code'**
  String get codeFieldLabel;

  /// No description provided for @verifyCodeButton.
  ///
  /// In en, this message translates to:
  /// **'Verify'**
  String get verifyCodeButton;

  /// No description provided for @resendCode.
  ///
  /// In en, this message translates to:
  /// **'Resend code'**
  String get resendCode;

  /// No description provided for @resendCodeIn.
  ///
  /// In en, this message translates to:
  /// **'Resend code in {seconds} s'**
  String resendCodeIn(int seconds);

  /// No description provided for @newCodeSent.
  ///
  /// In en, this message translates to:
  /// **'New code sent.'**
  String get newCodeSent;

  /// No description provided for @codeInvalid.
  ///
  /// In en, this message translates to:
  /// **'Wrong code. {count, plural, one{1 attempt left.} other{{count} attempts left.}}'**
  String codeInvalid(int count);

  /// No description provided for @codeInvalidOrExpired.
  ///
  /// In en, this message translates to:
  /// **'Wrong or expired code. Request a new one.'**
  String get codeInvalidOrExpired;

  /// No description provided for @codeExpired.
  ///
  /// In en, this message translates to:
  /// **'Code expired. Request a new one.'**
  String get codeExpired;

  /// No description provided for @codeTooManyAttempts.
  ///
  /// In en, this message translates to:
  /// **'Too many wrong attempts. Request a new code.'**
  String get codeTooManyAttempts;

  /// No description provided for @codeRateLimited.
  ///
  /// In en, this message translates to:
  /// **'Too many requests. Try again in {seconds} s.'**
  String codeRateLimited(int seconds);

  /// No description provided for @codeDeliveryFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not send the email. Try again.'**
  String get codeDeliveryFailed;

  /// No description provided for @codeCheckFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not check the code. Try again.'**
  String get codeCheckFailed;

  /// No description provided for @codeOffline.
  ///
  /// In en, this message translates to:
  /// **'No connection. Check the network and try again.'**
  String get codeOffline;

  /// No description provided for @emailVerifiedMessage.
  ///
  /// In en, this message translates to:
  /// **'Email verified.'**
  String get emailVerifiedMessage;

  /// No description provided for @sendResetCode.
  ///
  /// In en, this message translates to:
  /// **'Send code'**
  String get sendResetCode;

  /// No description provided for @resetCodeSentGeneric.
  ///
  /// In en, this message translates to:
  /// **'If an account exists for {email}, a code is on its way.'**
  String resetCodeSentGeneric(String email);

  /// No description provided for @newPasswordTitle.
  ///
  /// In en, this message translates to:
  /// **'Set a new password'**
  String get newPasswordTitle;

  /// No description provided for @newPasswordLabel.
  ///
  /// In en, this message translates to:
  /// **'New password'**
  String get newPasswordLabel;

  /// No description provided for @confirmPasswordLabel.
  ///
  /// In en, this message translates to:
  /// **'Repeat the password'**
  String get confirmPasswordLabel;

  /// No description provided for @passwordsDontMatch.
  ///
  /// In en, this message translates to:
  /// **'The passwords do not match.'**
  String get passwordsDontMatch;

  /// No description provided for @savePasswordButton.
  ///
  /// In en, this message translates to:
  /// **'Save password'**
  String get savePasswordButton;

  /// No description provided for @passwordResetSuccess.
  ///
  /// In en, this message translates to:
  /// **'Password changed. Sign in with the new password.'**
  String get passwordResetSuccess;

  /// No description provided for @passwordResetUnconfirmed.
  ///
  /// In en, this message translates to:
  /// **'Sign in with the new password. If that fails, reset it again.'**
  String get passwordResetUnconfirmed;

  /// No description provided for @resetSessionExpired.
  ///
  /// In en, this message translates to:
  /// **'This reset expired. Start again.'**
  String get resetSessionExpired;

  /// No description provided for @resetStartOver.
  ///
  /// In en, this message translates to:
  /// **'Start again'**
  String get resetStartOver;

  /// No description provided for @resetRequestFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not send the request. Try again.'**
  String get resetRequestFailed;

  /// No description provided for @passwordSaveFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not save the password. Try again.'**
  String get passwordSaveFailed;

  /// No description provided for @loadingHint.
  ///
  /// In en, this message translates to:
  /// **'Loading'**
  String get loadingHint;

  /// No description provided for @emailInUseHint.
  ///
  /// In en, this message translates to:
  /// **'This email already has an account. Sign in or reset the password.'**
  String get emailInUseHint;

  /// No description provided for @authWrongCredentials.
  ///
  /// In en, this message translates to:
  /// **'Wrong email or password. Try again.'**
  String get authWrongCredentials;

  /// No description provided for @authAccountDisabled.
  ///
  /// In en, this message translates to:
  /// **'This account is disabled. Use a different account.'**
  String get authAccountDisabled;

  /// No description provided for @authTooManyAttempts.
  ///
  /// In en, this message translates to:
  /// **'Too many attempts. Wait a moment and try again.'**
  String get authTooManyAttempts;

  /// No description provided for @authSignInFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not sign in. Try again.'**
  String get authSignInFailed;

  /// No description provided for @authAccountCreationFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not create the account. Try again.'**
  String get authAccountCreationFailed;

  /// No description provided for @authNotSignedIn.
  ///
  /// In en, this message translates to:
  /// **'You are signed out. Sign in and try again.'**
  String get authNotSignedIn;

  /// No description provided for @authEmailNotVerified.
  ///
  /// In en, this message translates to:
  /// **'Email not verified yet. Enter the code we sent.'**
  String get authEmailNotVerified;

  /// No description provided for @authVerificationCheckFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not check verification. Try again.'**
  String get authVerificationCheckFailed;

  /// No description provided for @authDataDownloadFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not download your data. Check the connection and try again.'**
  String get authDataDownloadFailed;

  /// No description provided for @completeProfileTitle.
  ///
  /// In en, this message translates to:
  /// **'Complete your profile'**
  String get completeProfileTitle;

  /// No description provided for @completeSetupButton.
  ///
  /// In en, this message translates to:
  /// **'Finish setup'**
  String get completeSetupButton;

  /// No description provided for @nudgeNotificationTitle.
  ///
  /// In en, this message translates to:
  /// **'Nudge'**
  String get nudgeNotificationTitle;

  /// No description provided for @navStudy.
  ///
  /// In en, this message translates to:
  /// **'Study'**
  String get navStudy;

  /// No description provided for @navCampus.
  ///
  /// In en, this message translates to:
  /// **'Campus'**
  String get navCampus;

  /// No description provided for @settingsTooltip.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settingsTooltip;

  /// No description provided for @aboutTitle.
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get aboutTitle;

  /// No description provided for @privacyPolicy.
  ///
  /// In en, this message translates to:
  /// **'Privacy policy'**
  String get privacyPolicy;

  /// No description provided for @contactSupport.
  ///
  /// In en, this message translates to:
  /// **'Contact support'**
  String get contactSupport;

  /// No description provided for @appVersion.
  ///
  /// In en, this message translates to:
  /// **'Version'**
  String get appVersion;

  /// No description provided for @linkOpenFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not open the link.'**
  String get linkOpenFailed;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'kk', 'ru'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'kk':
      return AppLocalizationsKk();
    case 'ru':
      return AppLocalizationsRu();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
