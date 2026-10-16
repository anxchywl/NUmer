// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Kazakh (`kk`).
class AppLocalizationsKk extends AppLocalizations {
  AppLocalizationsKk([String locale = 'kk']) : super(locale);

  @override
  String get habitTypeLockedHint =>
      'Әдет түрін жасалғаннан кейін өзгерту мүмкін емес';

  @override
  String get settingsTitle => 'Есептік жазба және баптаулар';

  @override
  String get account => 'Аккаунт';

  @override
  String get profile => 'Профиль';

  @override
  String get appearance => 'Сыртқы түрі';

  @override
  String get system => 'Жүйелік';

  @override
  String get light => 'Ашық';

  @override
  String get dark => 'Түн';

  @override
  String get language => 'Тіл';

  @override
  String get english => 'Ағылшын';

  @override
  String get russian => 'Орыс';

  @override
  String get kazakh => 'Қазақ';

  @override
  String get accentColor => 'Акцент түсі';

  @override
  String get buttonPreview => 'Түйме';

  @override
  String get accentColorDescription => 'Негізгі түсіңізді реттеңіз';

  @override
  String get preview => 'Алдын ала қарау';

  @override
  String get textExample => 'Мәтін үлгісі';

  @override
  String get customColor => 'Өз түсіңіз';

  @override
  String get hue => 'Түс реңі';

  @override
  String get saturation => 'Қанықтылық';

  @override
  String get lightness => 'Жарықтық';

  @override
  String get presets => 'Пресеттер';

  @override
  String get defaultPreset => 'Әдепкі';

  @override
  String get rosePreset => 'Алқызыл';

  @override
  String get emeraldPreset => 'Изумруд';

  @override
  String get indigoPreset => 'Индиго';

  @override
  String get coralPreset => 'Коралл';

  @override
  String get createPreset => 'Пресет құру';

  @override
  String get presetName => 'Пресет атауы';

  @override
  String get lettersOnly => 'Әріптер мен бос орындар';

  @override
  String get max16Symbols => 'Макс. 16 таңба';

  @override
  String get deletePreset => 'Пресетті жою';

  @override
  String get presetLimitReached => 'Пресеттер саны шегіне жетті (22)';

  @override
  String get weekStartsOn => 'Апта басталуы';

  @override
  String get displayTotalStudyTime => 'Курс бойынша жалпы оқу уақытын көрсету';

  @override
  String get displayProgressBar => 'Прогресс жолағын көрсету';

  @override
  String get quickNotes => 'Жылдам жазбалар';

  @override
  String get wantToReceiveNudges => 'Ньюдж ескертулерін алғыңыз келе ме?';

  @override
  String get eisenhowerMatrix => 'Эйзенхауэр матрицасы';

  @override
  String get quickNotesDescription =>
      'Бар жазбалар сақталады, бірақ сессиядан кейін жаңа жазба терезелері көрсетілмейді.';

  @override
  String get wantToReceiveNudgesDescription =>
      'Топ мүшелеріне сізге жұмсақ еске салулар жіберуге рұқсат беру.';

  @override
  String get eisenhowerMatrixDescription =>
      'Әдеттерді маңыздылығы мен шұғылдығына қарай реттеу үшін Эйзенхауэр матрицасын қолданыңыз.';

  @override
  String get sessionNotification => 'Сессия туралы хабарлама';

  @override
  String get sessionNotificationDescription =>
      'Жазу кезінде хабарландыру тақтасында сессияны басқару элементтерін көрсету.';

  @override
  String get eisenhowerQuadrant1 => 'Шұғыл және маңызды';

  @override
  String get eisenhowerQuadrant2 => 'Шұғыл емес, бірақ маңызды';

  @override
  String get eisenhowerQuadrant3 => 'Шұғыл, бірақ маңызды емес';

  @override
  String get eisenhowerQuadrant4 => 'Шұғыл емес және маңызды емес';

  @override
  String get eisenhowerHint => 'Әдеттерді ұйымдастыру үшін матрицаға сүйреңіз';

  @override
  String get yes => 'Иә';

  @override
  String get no => 'Жоқ';

  @override
  String get data => 'Деректер';

  @override
  String get exportToCalendar => 'Күнтізбеге экспорттау';

  @override
  String exportWillStartIn(int seconds) {
    return 'Экспорт $seconds секундтан кейін басталады';
  }

  @override
  String get exportToCalendarSubtitle =>
      'Сеанстарыңызды күнтізбе оқиғалары ретінде сақтаңыз';

  @override
  String get allCourses => 'Барлық курстар';

  @override
  String get courseFallback => 'Курс';

  @override
  String get export => 'Экспорттау';

  @override
  String get exporting => 'Экспортталуда...';

  @override
  String exportFailedMessage(String error) {
    return 'Экспорттау сәтсіз аяқталды: $error';
  }

  @override
  String sessionsFound(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count сессия табылды',
      zero: 'Сессия табылмады',
    );
    return '$_temp0';
  }

  @override
  String habitReportDownloadCountdown(int seconds) {
    return 'Есепті дайындау $seconds секундтан кейін басталады';
  }

  @override
  String get fileSavedSuccessfully => 'Файл сәтті жасалды';

  @override
  String get fileSavedAt => 'Файл келесі жерде сақталды:';

  @override
  String get unknownPath => 'Белгісіз жол';

  @override
  String get nextSteps => 'Келесі қадамдар:';

  @override
  String get exportCalendarNextStepsBody =>
      '• Осы файлды ашып, оны күнтізбе қолданбаңызға импорттаңыз,\n• НЕМЕСЕ күнтізбе қолданбасының баптауларын ашып, файлды қолмен импорттаңыз.';

  @override
  String get deleteAccount => 'Есептік жазбаны жою';

  @override
  String get deleteAccountSubtitle =>
      'Есептік жазбаны және барлық деректерді біржола жою';

  @override
  String get deleteAccountHoldConfirmDetail =>
      'Түймені 5 секунд басып тұрсаңыз, есептік жазба мәңгіге жойылады';

  @override
  String get deletingAccount => 'Есептік жазба жойылуда...';

  @override
  String get accountDeleted => 'Есептік жазба жойылды';

  @override
  String get pleaseSignInToViewAccount =>
      'Есептік жазбаңызды көру үшін кіріңіз.';

  @override
  String get signOut => 'Шығу';

  @override
  String get syncNow => 'Қазір синхрондау';

  @override
  String get syncing => 'Синхрондалуда';

  @override
  String get home => 'Басты бет';

  @override
  String get statistics => 'Статистика';

  @override
  String get groups => 'Топтар';

  @override
  String get addCourse => 'Курсты қосу';

  @override
  String get addTime => 'Уақыт қосу';

  @override
  String get courseName => 'Курс атауы';

  @override
  String get courseNameHint => '';

  @override
  String get required => 'Міндетті';

  @override
  String get color => 'Түс';

  @override
  String get creditsOptional => 'Кредиттер (міндетті емес)';

  @override
  String get creditsHint => 'мысалы, 6 немесе 7';

  @override
  String get creditsHelper =>
      'Өзіндік оқу мақсаттарын қосу үшін кредиттерді енгізіңіз';

  @override
  String get experienceLevel => 'Тәжірибе деңгейі';

  @override
  String get save => 'Сақтау';

  @override
  String get cancel => 'Бас тарту';

  @override
  String get delete => 'Жою';

  @override
  String get deleteCourseTitle => 'Курсты жою';

  @override
  String get deleteCourseMessage =>
      'Сенімдісіз бе? Бұл курстың барлық деректері жойылады.';

  @override
  String timeSavedMessage(String courseName) {
    return '\"$courseName\" үшін уақыт сақталды';
  }

  @override
  String get aiAnalysisComingSoon => 'Курс талдауы жақында пайда болады.';

  @override
  String get courseAnalysis => 'Курс талдауы';

  @override
  String get noCoursesAvailable => 'Курстар жоқ.';

  @override
  String get selectCourse => 'Курсты таңдаңыз';

  @override
  String get sixMonths => '6 ай';

  @override
  String get analysisUpdatesEveryPeriod =>
      'Талдау әр жаңа кезеңде жаңартылады.';

  @override
  String get analysisAlreadyGenerated =>
      'Бұл кезең үшін талдау бұрын жасалған.';

  @override
  String get dayStatsTipLine1 =>
      '• Күнтізбе оқу белсенділігін көрсетеді. Күн неғұрлым жасыл болса, соғұрлым көп оқыдыңыз.';

  @override
  String get dayStatsTipLine2 =>
      '• Сессия уақытын және жазбаларды Тарих бөлімінде өңдей аласыз.';

  @override
  String get dayStatsTipLine3 =>
      '• Кез келген курсты түртсеңіз, тарих экранында тек сол курстың сессиялары көрсетіледі.';

  @override
  String get syncOffline => 'Офлайн';

  @override
  String get syncSyncing => 'Синхрондалып жатыр…';

  @override
  String get syncUpToDate => 'Жаңартылған';

  @override
  String get setGoals => 'Мақсат қою';

  @override
  String get daily => 'Күндік';

  @override
  String get weekly => 'Апталық';

  @override
  String get studyTimer => 'Оқу таймері';

  @override
  String get noCoursesYet => 'Әлі курс жоқ. Басты беттен курс қосыңыз.';

  @override
  String get chooseACourse => 'Курсты таңдаңыз';

  @override
  String get start => 'Бастау';

  @override
  String get stop => 'Тоқтату';

  @override
  String get reset => 'Қалпына\nкелтіру';

  @override
  String get ok => 'ОК';

  @override
  String get timerStoppedAndSaved => 'Таймер тоқтатылып, сақталды.';

  @override
  String get nothingToReset => 'Қалпына келтіретін ештеңе жоқ.';

  @override
  String anotherSessionRunning(String sessionType) {
    return 'Басқа $sessionType қазірдің өзінде жұмыс істеп тұр. Алдымен оны тоқтатыңыз.';
  }

  @override
  String anotherSessionRunningOn(String sessionType, String courseName) {
    return 'Басқа $sessionType \"$courseName\" бойынша жұмыс істеп тұр. Алдымен оны тоқтатыңыз.';
  }

  @override
  String anotherSessionRunningSilly(String sessionType) {
    return 'Тағы бір $sessionType қазір жұмыс істеп тұр, silly.';
  }

  @override
  String get alreadyStudiedThisPeriod =>
      'Сіз бұл уақыт аралығында бұрыннан оқығансыз.';

  @override
  String get friendJoinPrompt =>
      'Досыңыз іздеу жолағына тобыңыздың атын теру арқылы қосыла алады.';

  @override
  String get enterTimeFirst => 'Алдымен уақытты енгізіңіз';

  @override
  String get nothingToSave => 'Сақтайтын ештеңе жоқ';

  @override
  String get maxTimeCapped => 'Максимум 3:00:00 — шектелген';

  @override
  String get studiedLabel => 'Оқылды';

  @override
  String get goalsUpdated => 'Мақсаттар жаңартылды';

  @override
  String get studiedToday => 'Бүгін оқылды';

  @override
  String get studiedThisWeek => 'Осы аптада оқылды';

  @override
  String get studiedThisMonth => 'Осы айда оқылды';

  @override
  String get studiedThisYear => 'Осы жылы оқылды';

  @override
  String get studiedOverall => 'Жалпы оқылды';

  @override
  String get timer => 'таймер';

  @override
  String get stopwatch => 'секундомер';

  @override
  String get pomodoro => 'помодоро';

  @override
  String get session => 'сеанс';

  @override
  String get editCourse => 'Курсты өңдеу';

  @override
  String get today => 'Бүгін';

  @override
  String get edit => 'Өңдеу';

  @override
  String get timerTab => 'Таймер';

  @override
  String get stopwatchTab => 'Секундомер';

  @override
  String get pomodoroTab => 'Помодоро';

  @override
  String get typeTimeToStudy => 'Оқу үшін қажет уақытты осында енгізіңіз';

  @override
  String get maxTime => 'Макс: 3:00:00';

  @override
  String get elapsed => 'өткен';

  @override
  String completedPomodoros(int completed) {
    return 'Аяқталған помодоро: $completed / 4';
  }

  @override
  String longBreakLength(int minutes) {
    return 'Ұзын үзіліс ұзақтығы ($minutes мин)';
  }

  @override
  String get work => 'Жұмыс';

  @override
  String get shortBreak => 'Қысқа үзіліс';

  @override
  String get longBreak => 'Ұзын үзіліс';

  @override
  String get paused => 'кідіртілді';

  @override
  String get resume => 'Жалғастыру';

  @override
  String get pause => 'Кідірту';

  @override
  String get skipBreak => 'Үзілісті өткізіп жіберу';

  @override
  String get pomodoroExitWarning => 'Помодоро сеансы жүріп жатыр. Шығасыз ба?';

  @override
  String get exitAnyway => 'Қалай болғанда да шығу';

  @override
  String get expLevel1 => 'Мүлде бастаушы';

  @override
  String get expLevel2 => 'Негіздерін білемін';

  @override
  String get expLevel3 => 'Пәнді сенімді білемін';

  @override
  String get expLevel4 => 'Жоғары деңгейдегі білім';

  @override
  String get expLevel5 => 'Кең тәжірибе';

  @override
  String get expLevelDefault => 'Сенімді';

  @override
  String get dayStatistics => 'Күндік статистика';

  @override
  String get periodStatistics => 'Кезең статистикасы';

  @override
  String get tip => 'Кеңес';

  @override
  String get chartTip =>
      '• Графикте саусағыңызды ұстап тұрып, күндер немесе айлар арасында ауысу үшін солға немесе оңға сырғытыңыз.';

  @override
  String get courseStatistics => 'Курс статистикасы';

  @override
  String get previousDay => 'Алдыңғы күн';

  @override
  String get nextDay => 'Келесі күн';

  @override
  String get history => 'Тарих';

  @override
  String get week => 'Апта';

  @override
  String get month => 'Ай';

  @override
  String get year => 'Жыл';

  @override
  String get previousWeek => 'алдыңғы апта';

  @override
  String get previousMonth => 'алдыңғы ай';

  @override
  String get previousYear => 'алдыңғы жыл';

  @override
  String get nextWeek => 'келесі апта';

  @override
  String get nextMonth => 'келесі ай';

  @override
  String get nextYear => 'келесі жыл';

  @override
  String get noData => 'Дерек жоқ';

  @override
  String get hours => 'Сағат';

  @override
  String get minutes => 'Минут';

  @override
  String totalThisPeriod(String period) {
    return 'Осы $period ішінде барлығы';
  }

  @override
  String get avgPerDay => 'Күніне орташа';

  @override
  String get mostStudied => 'Ең көп';

  @override
  String get leastStudied => 'Ең аз';

  @override
  String get adjustWeeklyGoal => 'Апталық мақсатты түзету';

  @override
  String get targetPerWeek => 'Апталық мақсат';

  @override
  String get targetPerDay => 'Күндік мақсат';

  @override
  String semester(int weeks) {
    return 'Семестр (~$weeks апта)';
  }

  @override
  String hPerWeek(String hours) {
    return '$hours сағ/апта';
  }

  @override
  String get createGroup => 'Топ құру';

  @override
  String get joinGroup => 'Топқа қосылу';

  @override
  String get groupName => 'Топ атауы';

  @override
  String get description => 'Сипаттама';

  @override
  String get privacy => 'Құпиялылық';

  @override
  String get public => 'Ашық';

  @override
  String get private => 'Жабық';

  @override
  String get accessCode => 'Қолжеткізу коды';

  @override
  String get members => 'Қатысушылар';

  @override
  String get leaveGroup => 'Топтан шығу';

  @override
  String get deleteGroup => 'Топты жою';

  @override
  String get groupSettings => 'Топ баптаулары';

  @override
  String get noGroupsYet => 'Сіз әлі бірде-бір топқа кірмедіңіз';

  @override
  String get noSearchResults => 'Бізде мұндай жоқ';

  @override
  String get createOrJoinPrompt =>
      'Жаңа топ құрыңыз немесе бар топқа қосылып, басқалармен бірлесе жұмыс істеңіз';

  @override
  String get signInPrompt => 'Топтарды көру үшін кіріңіз.';

  @override
  String errorLoadingMemberships(String error) {
    return 'Мүшелік жүктелмеді: $error';
  }

  @override
  String get findPublicGroupHint => 'Топты табу...';

  @override
  String get searchResults => 'Іздеу нәтижелері';

  @override
  String errorLoadingGroups(String error) {
    return 'Топтарды жүктеу қатесі: $error';
  }

  @override
  String get joinedSuccessfully => 'Топқа сәтті қосылдыңыз';

  @override
  String get joinedPrivateSuccessfully => 'Жабық топқа сәтті қосылдыңыз';

  @override
  String joinGroupDialogTitle(String groupName) {
    return '$groupName тобына қосылу';
  }

  @override
  String get joinGroupDialogMessage =>
      'Осы жабық топқа кіру үшін қосылу кодын енгізіңіз.';

  @override
  String get joinCodeHint => 'мысалы, ABC123';

  @override
  String get publicGroups => 'Ашық топтар';

  @override
  String joinError(String error) {
    return 'Топқа қосылу мүмкін болмады: $error';
  }

  @override
  String get noDescription => 'Сипаттама жоқ.';

  @override
  String membersCount(int count) {
    return '$count қатысушы';
  }

  @override
  String get yourGroup => 'Сіздің тобыңыз';

  @override
  String get findStudyGroup => 'Оқу тобыңызды табыңыз';

  @override
  String get joinCommunityPrompt =>
      'Қауымдастыққа қосылып, прогресті бақылап, көшбасшылар тақтасында жарысып, мотивацияны бірге сақтаңыз.';

  @override
  String get administrator => 'Админ';

  @override
  String get memberLabel => 'Қатысушы';

  @override
  String get unableToLoadGroup => 'Топ деректерін жүктеу мүмкін болмады';

  @override
  String get checkConnection => 'Интернет байланысын тексеріңіз';

  @override
  String get retry => 'Қайталау';

  @override
  String get groupNotFound => 'Топ табылмады немесе жойылды.';

  @override
  String get signInToManage => 'Бұл топты басқару үшін жүйеге кіру керек.';

  @override
  String get noLongerMember => 'Сіз бұл топтың мүшесі емессіз.';

  @override
  String get groupNameHint => 'Топ атауын енгізіңіз';

  @override
  String get visibility => 'Көрінуі';

  @override
  String get descriptionHint => 'Тобыңызды бірнеше сөзбен сипаттаңыз';

  @override
  String get codeRequired => 'Код міндетті';

  @override
  String get codeJoinPrompt => 'Бұл код жаңа мүшелердің қосылуы үшін қажет.';

  @override
  String get onlyAdminVisibility =>
      'Тек әкімшілер параметрлерін өзгерте алады.';

  @override
  String get saving => 'Сақталуда...';

  @override
  String get saveChanges => 'Өзгерістерді сақтау';

  @override
  String get membersTitle => 'Қатысушылар';

  @override
  String get unableToLoadMembers => 'Қатысушылар тізімін жүктеу мүмкін болмады';

  @override
  String get checkConnectionTryAgain => 'Байланысты тексеріп, қайта көріңіз';

  @override
  String get noMembersYetLabel => 'Әлі қатысушы жоқ.';

  @override
  String get youAdmin => 'Сіз (админ)';

  @override
  String get youMember => 'Сіз';

  @override
  String get youOwner => 'Сіз (иесі)';

  @override
  String get removeMemberTitle => 'Қатысушыны жою керек пе?';

  @override
  String get removeMemberMessage =>
      'Осы қатысушыны топтан жою керек пе? Ол бірден қолжетімділіктен айырылады.';

  @override
  String get memberRemoved => 'Қатысушы жойылды';

  @override
  String get groupUpdated => 'Топ жаңартылды';

  @override
  String failedToUpdateGroup(String error) {
    return 'Топты жаңарту мүмкін болмады: $error';
  }

  @override
  String failedToDeleteGroup(String error) {
    return 'Топты жою мүмкін болмады: $error';
  }

  @override
  String failedToLeaveGroup(String error) {
    return 'Топтан шығу мүмкін болмады: $error';
  }

  @override
  String failedToRemoveMember(String error) {
    return 'Қатысушыны жою мүмкін болмады: $error';
  }

  @override
  String get groupCodeLabel => 'Топ коды';

  @override
  String get dailyGoal => 'Күндік';

  @override
  String get weeklyGoal => 'Апталық';

  @override
  String get hUnit => 'сағ';

  @override
  String get mUnit => 'мин';

  @override
  String get sUnit => 'с';

  @override
  String errorLoadingLeaderboard(String error) {
    return 'Көшбасшылар тақтасын жүктеу қатесі: $error';
  }

  @override
  String get courseHiddenFromLeaderboard =>
      'Курс көшбасшылар тақтасынан жасырылды';

  @override
  String get courseVisibleInLeaderboard =>
      'Курс көшбасшылар тақтасында көрінеді';

  @override
  String get hideFromLeaderboard => 'Көшбасшылар тақтасынан жасыру';

  @override
  String get unhideFromLeaderboard => 'Көшбасшылар тақтасында көрсету';

  @override
  String get noDataAvailable => 'Бұл кезеңге дерек жоқ';

  @override
  String get groupLeaderboard => 'Көшбасшылар тақтасы';

  @override
  String rankLabel(int rank) {
    return '#$rank';
  }

  @override
  String failedToLoadUserData(String error) {
    return 'Пайдаланушы деректерін жүктеу қатесі: $error';
  }

  @override
  String get sun => 'Жс';

  @override
  String get mon => 'Дс';

  @override
  String get tue => 'Сс';

  @override
  String get wed => 'Ср';

  @override
  String get thu => 'Бс';

  @override
  String get fri => 'Жм';

  @override
  String get sat => 'Сн';

  @override
  String get sunday => 'Жексенбі';

  @override
  String get monday => 'Дүйсенбі';

  @override
  String get tuesday => 'Сейсенбі';

  @override
  String get wednesday => 'Сәрсенбі';

  @override
  String get thursday => 'Бейсенбі';

  @override
  String get friday => 'Жұма';

  @override
  String get saturday => 'Сенбі';

  @override
  String get january => 'Қаңтар';

  @override
  String get february => 'Ақпан';

  @override
  String get march => 'Наурыз';

  @override
  String get april => 'Сәуір';

  @override
  String get may => 'Мамыр';

  @override
  String get june => 'Маусым';

  @override
  String get july => 'Шілде';

  @override
  String get august => 'Тамыз';

  @override
  String get september => 'Қыркүйек';

  @override
  String get october => 'Қазан';

  @override
  String get november => 'Қараша';

  @override
  String get december => 'Желтоқсан';

  @override
  String get total => 'Барлығы';

  @override
  String get groupSummary => 'Топ қорытындысы';

  @override
  String get average => 'Орташа';

  @override
  String get leader => 'Көшбасшы';

  @override
  String get lowest => 'Ең төмен';

  @override
  String get vsAverage => 'орташамен салыстырғанда';

  @override
  String get studyTimeComparison => 'Оқу уақытының салыстыруы';

  @override
  String get performanceVsGroup => 'Топқа қатысты көрсеткіш';

  @override
  String get ofAverage => 'орташаның';

  @override
  String get studyTimeByDay => 'Күндер бойынша оқу уақыты';

  @override
  String get bestDay => 'Ең жақсы күн';

  @override
  String get avgDay => 'Күніне орташа';

  @override
  String get member => 'Қатысушы';

  @override
  String get todayDataTable => 'Бүгін';

  @override
  String get monthDataTable => 'Ай';

  @override
  String get overThisWeek => 'осы аптада';

  @override
  String get overThisMonth => 'осы айда';

  @override
  String get overThisYear => 'осы жылы';

  @override
  String get hour => 'сағат';

  @override
  String get hours_plural => 'сағат';

  @override
  String get minute => 'минут';

  @override
  String get minutes_plural => 'минут';

  @override
  String get second => 'секунд';

  @override
  String get seconds_plural => 'секунд';

  @override
  String get jan => 'Қаң';

  @override
  String get feb => 'Ақп';

  @override
  String get mar => 'Нау';

  @override
  String get apr => 'Сәу';

  @override
  String get mayShort => 'Мам';

  @override
  String get jun => 'Мау';

  @override
  String get jul => 'Шіл';

  @override
  String get aug => 'Там';

  @override
  String get sep => 'Қыр';

  @override
  String get oct => 'Қаз';

  @override
  String get nov => 'Қар';

  @override
  String get dec => 'Жел';

  @override
  String get via => 'арқылы';

  @override
  String get viaTimer => 'Таймер арқылы';

  @override
  String get viaStopwatch => 'Секундомер арқылы';

  @override
  String get viaPomodoro => 'Помодоро арқылы';

  @override
  String get viaManualRecording => 'қолмен жазу арқылы';

  @override
  String get startTime => 'Бастау';

  @override
  String get endTime => 'Аяқтау';

  @override
  String get duration => 'Ұзақтығы';

  @override
  String get reflection => 'Ескертпе';

  @override
  String get overThis => 'осы';

  @override
  String get credits => 'Кредит';

  @override
  String get credits_plural => 'Кредиттер';

  @override
  String get deleteSession => 'Сеансты жою керек пе?';

  @override
  String get deleteSessionMessage =>
      'Бұл сеансты тарих пен статистикадан алып тастайды.';

  @override
  String get sessionDeleted => 'Сеанс жойылды';

  @override
  String get leaveGroupTitle => 'Топтан шығасыз ба?';

  @override
  String get leaveGroupMessage => 'Бұл топтан шығуды қалайсыз ба?';

  @override
  String get leave => 'Шығу';

  @override
  String get deleteGroupTitle => 'Топты жою керек пе?';

  @override
  String get deleteGroupMessage =>
      'Бұл топты барлық мүшелер үшін біржола жояды.';

  @override
  String get manageGroup => 'Топты басқару';

  @override
  String get admin => 'Админ';

  @override
  String get removeMember => 'Қатысушыны жою';

  @override
  String get makeAdmin => 'Әкімші ету';

  @override
  String get removeAdmin => 'Әкімшіден алу';

  @override
  String get owner => 'Иесі';

  @override
  String get memberPromoted => 'Қатысушы әкімші болып тағайындалды';

  @override
  String get adminDemoted => 'Әкімші қатысушы деңгейіне түсірілді';

  @override
  String get failedToPromote => 'Әкімші етіп тағайындау мүмкін болмады';

  @override
  String get failedToDemote => 'Әкімші деңгейін түсіру мүмкін болмады';

  @override
  String get demoteTooltip => 'Қатысушы деңгейіне түсіру';

  @override
  String get makeAdminTooltip => 'Әкімші ету';

  @override
  String get cannotEnterFutureTime => 'Болашақ уақытты енгізе алмайсыз.';

  @override
  String get startTimeLaterThanEndTime =>
      'Басталу уақыты аяқталу уақытынан кеш болмауы керек.';

  @override
  String timeAddedToCourse(String courseName) {
    return 'Уақыт $courseName курсына қосылды';
  }

  @override
  String get currentDay => 'ағымдағы күн';

  @override
  String get thisWeekShort => 'осы апта';

  @override
  String get thisMonthShort => 'осы ай';

  @override
  String get thisYearShort => 'осы жыл';

  @override
  String get overall => 'жалпы';

  @override
  String get dayGoalLabel => 'күндік мақсат';

  @override
  String get weekGoalLabel => 'апталық мақсат';

  @override
  String get on => 'қосулы';

  @override
  String get off => 'сөндірулі';

  @override
  String get justSwipeIt => 'Жай ғана сырғытыңыз';

  @override
  String get customPhotosUnavailable =>
      'Пайдаланушы фотолары уақытша қолжетімсіз.';

  @override
  String get unableToPickImage => 'Сол суретті таңдау мүмкін болмады.';

  @override
  String get couldNotSaveProfile =>
      'Профильді сақтау мүмкін болмады. Қайталап көріңіз.';

  @override
  String get yourName => 'Атыңыз';

  @override
  String get addPersonalGoal => 'Жеке мақсат қосу';

  @override
  String get nameLabel => 'Аты';

  @override
  String get nameRequired => 'Аты міндетті';

  @override
  String get majorLabel => 'Мамандығы';

  @override
  String get majorRequired => 'Мамандық міндетті';

  @override
  String get contactLabel => 'Қалай байланысуға болады';

  @override
  String get contactHint => 'мысалы, телефон не tg никі';

  @override
  String get personalGoalLabel => 'Жеке мақсат';

  @override
  String get personalGoalHint => 'мысалы, Жақсырақ болу';

  @override
  String get chooseAvatar => 'Аватарды таңдаңыз';

  @override
  String get photoLibraryUnavailable => 'Фотокітапхана қолжетімсіз';

  @override
  String get iconColor => 'Белгіше түсі';

  @override
  String get saved => 'Сақталды';

  @override
  String get done => 'Дайын';

  @override
  String get stay => 'Қалу';

  @override
  String get resetAndLeave => 'Қалпына келтіру және шығу';

  @override
  String get leavePomodoroTitle => 'Помодородан шығу керек пе?';

  @override
  String get leavePomodoroMessage =>
      'Помодоро циклі жүріп жатыр. Осы қойындыдан шығар алдында оны қалпына келтіресіз бе?';

  @override
  String get timeFormatHint => 'HH:MM:SS';

  @override
  String get addCourseFirst => 'Алдымен курс қосыңыз';

  @override
  String invalidTimeFormat(String format) {
    return 'Уақытты $format түрінде енгізіңіз';
  }

  @override
  String get signIn => 'Кіру';

  @override
  String get register => 'Тіркелу';

  @override
  String get loginSubtitle => 'Сізді сағындық';

  @override
  String get registerSubtitle => '<3';

  @override
  String get emailAddress => 'Эл. пошта';

  @override
  String get password => 'Құпиясөз';

  @override
  String get displayName => 'Көрсетілетін ат';

  @override
  String get createAccount => 'Есептік жазба жасау';

  @override
  String get afterCreatingAccount =>
      'Есептік жазба жасағаннан кейін қолданбаны пайдалану үшін эл. поштаны растау қажет болады.';

  @override
  String get verificationEmailSent => 'Растау хаты жіберілді!';

  @override
  String get signedInSuccessfully => 'Сәтті кірдіңіз';

  @override
  String get resendEmail => 'Қайта жіберу';

  @override
  String get enterEmail => 'Эл. поштаңызды енгізіңіз.';

  @override
  String get invalidEmail => 'Дұрыс эл. пошта мекенжайын енгізіңіз.';

  @override
  String get enterPassword => 'Құпиясөзді енгізіңіз.';

  @override
  String get displayNameLength =>
      'Көрсетілетін ат кемінде 2 таңба болуы керек.';

  @override
  String get passwordLength => 'Құпиясөз кемінде 8 таңба болуы керек.';

  @override
  String get passwordInvalidChars =>
      'Тек A–Z, a–z, 0–9 және рұқсат етілген белгілерге қолдау көрсетіледі.';

  @override
  String get displayNameInvalidChars =>
      'Көрсетілетін ат тек әріптер мен сандардан тұруы мүмкін.';

  @override
  String get min8Chars => 'Кемінде 8 таңба.';

  @override
  String get loadingProfile => 'Профиль жүктелуде';

  @override
  String get loggingOut => 'Аккаунттан шығу...';

  @override
  String get forgotPassword => 'Құпиясөзді ұмыттыңыз ба?';

  @override
  String get resetPasswordTitle => 'Құпиясөзді қалпына келтіру';

  @override
  String get resetPasswordSubtitle =>
      'Аккаунт поштасын енгізіңіз. Біз сілтемені жібереміз.';

  @override
  String get sendResetLink => 'Сілтемені жіберу';

  @override
  String get resetLinkSent => 'Бұл поштаға аккаунт болса, сілтеме жіберілді.';

  @override
  String get backToSignIn => 'Кіру бетіне оралу';

  @override
  String get verifyEmailFirst =>
      'Алдымен поштаны растаңыз. Растау хатын жібердік.';

  @override
  String get resendVerificationEmail => 'Растау хатын қайта жіберу';

  @override
  String get invalidEmailFormat => 'Дұрыс email енгізіңіз.';

  @override
  String get resetRateLimited => 'Келесі әрекетке дейін сәл күтіңіз.';

  @override
  String get networkRequestFailed =>
      'Желі қатесі. Байланысты тексеріп, қайталап көріңіз.';

  @override
  String get signInToResend => 'Қайта жіберу үшін жүйеге кіріңіз.';

  @override
  String tryAgainInSeconds(int seconds) {
    return '$seconds с кейін қайталап көріңіз';
  }

  @override
  String get sessionNotes => 'Сессия жазбалары';

  @override
  String get sessionNotesHint => 'Осы сессияға жазба қосыңыз';

  @override
  String get sendNotes => 'Жазбаларды жіберу';

  @override
  String get updateNotes => 'Жазбаларды жаңарту';

  @override
  String get notesSaved => 'Жазбалар сақталды';

  @override
  String get failedToPrepareData => 'Деректерді дайындау мүмкін болмады.';

  @override
  String sessionFinished(String duration) {
    return 'Сабақ аяқталды: $duration';
  }

  @override
  String get whatDidYouWorkOn => 'Сіз немен айналыстыңыз?';

  @override
  String failedToSaveReflection(String error) {
    return 'Жазбаны сақтау мүмкін болмады: $error';
  }

  @override
  String get skip => 'Өткізіп жіберу';

  @override
  String streakDays(int count) {
    return '$count күндік серия';
  }

  @override
  String get noStreakYet => 'Серия жоқ';

  @override
  String nudgeWaitMinutes(int minutes) {
    return 'Қайта түртпес бұрын $minutes минут күте тұрыңыз.';
  }

  @override
  String nudgeWaitSeconds(int seconds) {
    return 'Қайта түртпес бұрын $seconds секунд күте тұрыңыз.';
  }

  @override
  String get memberCannotReceiveNudges =>
      'Бұл мүше әлі түртпелерді ала алмайды.';

  @override
  String get nudgeSent => 'Түртпе жіберілді.';

  @override
  String failedToSendNudge(String error) {
    return 'Түртпе жіберу сәтсіз аяқталды: $error';
  }

  @override
  String get cannotNudgeSelf => 'Өзіңізді түртпелей алмайсыз.';

  @override
  String get userProhibitedNudge =>
      'Бұл пайдаланушы түртпелерді өшіріп тастаған.';

  @override
  String get leaderboardHintMessage =>
      '• Оқу уақытын көру үшін көшбасшылар тақтасындағы кез келген пайдаланушыны басуға болады.\n• Мүшені түрту үшін оның аватарының жанындағы қол белгішесін басыңыз.';

  @override
  String get habitsNavLabel => 'Әдеттер';

  @override
  String get habitStatistics => 'Әдеттер статистикасы';

  @override
  String get habitsTabProgress => 'Прогресс';

  @override
  String get habitsTabList => 'Менің әдеттерім';

  @override
  String get habitsPleaseSignIn => 'Кіру қажет';

  @override
  String get habitsEmptyToday => 'Бүгін жоспар жоқ. Керемет!';

  @override
  String habitsListError(String error) {
    return 'Қате: $error';
  }

  @override
  String get habitsEmptyListTitle => 'Әзірге әдеттер жоқ';

  @override
  String get habitsEmptyListCta => 'Алғашқысын құру';

  @override
  String get habitRequirementMarkDone => 'Орындалды деп белгілеу';

  @override
  String habitRequirementToday(String current, String target, String unit) {
    return '$current / $target $unit бүгін';
  }

  @override
  String habitRequirementTodayNoUnit(String current, String target) {
    return '$current / $target бүгін';
  }

  @override
  String get habitFrequencyEveryDay => 'Күн сайын';

  @override
  String get habitFrequencySpecificMonth => 'Айдың нақты күндері';

  @override
  String get habitFrequencySpecificDates => 'Белгілі күндер';

  @override
  String habitFrequencyDaysLabel(String days) {
    return 'Күндер: $days';
  }

  @override
  String habitFrequencyInterval(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: 'күн',
      one: 'күн',
    );
    return 'Әр $days $_temp0';
  }

  @override
  String habitFrequencyTimesPerPeriod(int count, String period) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count рет $period ішінде',
      one: '$count рет $period ішінде',
    );
    return '$_temp0';
  }

  @override
  String get habitPeriodWeek => 'Апта';

  @override
  String get habitPeriodMonth => 'Ай';

  @override
  String get habitPeriodYear => 'Жыл';

  @override
  String get habitDailyOverview => 'Күндік шолу';

  @override
  String get habitNoHabitsThisDay => 'Бұл күні әдеттер орындалмады.';

  @override
  String get habitMinutesShort => 'мин';

  @override
  String get habitLogSetTotal => 'Барлығын орнату';

  @override
  String get habitLogAddMore => 'Қосу';

  @override
  String get habitUpdateProgress => 'Прогресті жаңарту';

  @override
  String get habitLogSetValueTitle => 'Мәнін орнату';

  @override
  String get habitClearTime => 'Уақытты тазарту';

  @override
  String habitProgressLabel(String date) {
    return 'Прогресс, $date';
  }

  @override
  String habitLogSettingTotal(String total) {
    return '$total ретінде орнату';
  }

  @override
  String habitLogAdding(String value, String existing) {
    return '$value мәнін $existing үстіне қосу';
  }

  @override
  String habitGoalLabel(String goal) {
    return 'Мақсат: $goal';
  }

  @override
  String get habitCreateTitle => 'Жаңа әдет құру';

  @override
  String get habitTrackingTitle => 'Бақылау түрі';

  @override
  String get habitExplainHabit => 'Әдетті сипаттаңыз';

  @override
  String get habitNameLabel => 'Әдет атауы';

  @override
  String get habitNameHint => '';

  @override
  String get habitCategoryLabel => 'Санат';

  @override
  String get habitCategoryNew => 'Жаңа санат';

  @override
  String get habitCategoryNameLabel => 'Санат атауы';

  @override
  String get habitCategoryNameHint => 'мысалы, оқу';

  @override
  String get habitCategoryDeleteTitle => 'Санатты жою';

  @override
  String habitCategoryDeleteMessage(String name) {
    return '\"$name\" жойылсын ба? Бұны қайтару мүмкін емес.';
  }

  @override
  String get habitCategoryCreateAction => 'Өзгеше жасау';

  @override
  String get habitBack => 'Артқа';

  @override
  String get habitNext => 'Әрі қарай';

  @override
  String get habitYesNo => 'Иә / Жоқ';

  @override
  String get habitNumeric => 'Сандық';

  @override
  String get habitTime => 'Уақыт';

  @override
  String get habitTrackingYesNoDescription =>
      'Әдеттің орындалғанын белгілеңіз.';

  @override
  String get habitTrackingNumericDescription =>
      'Күн сайынғы нақты санды қойыңыз.';

  @override
  String get habitTrackingTimeDescription =>
      'Күндік мақсат ретінде уақыт мөлшерін қойыңыз.';

  @override
  String get habitComparatorAtLeast => 'Кемінде';

  @override
  String get habitComparatorLessThan => 'Аз';

  @override
  String get habitComparatorExactly => 'Дәл';

  @override
  String get habitComparatorAny => 'Кез келген мән';

  @override
  String get habitValueLabel => 'Мән';

  @override
  String get habitUnitLabel => 'Бірлік';

  @override
  String get habitUnitHint => 'мысалы, бет';

  @override
  String get habitPerDay => 'күніне';

  @override
  String get habitTimeLabel => 'сағат : минут : секунд';

  @override
  String get habitTimePlaceholder => '00:00:00';

  @override
  String get habitFrequencyPrompt =>
      'Әдет қаншалықты жиі қайталанатынын таңдаңыз';

  @override
  String get habitFrequencySpecificTitle => 'Нақты күндер';

  @override
  String get habitFrequencyDailyDescription =>
      'Әдетті күн сайын үзіліссіз орындаңыз.';

  @override
  String get habitFrequencySpecificDescription =>
      'Апта күндерін немесе нақты күндерді таңдаңыз.';

  @override
  String get habitFrequencyPeriodWeekLabel => 'Апта';

  @override
  String get habitFrequencyPeriodMonthLabel => 'Ай';

  @override
  String get habitFrequencyPeriodYearLabel => 'Жыл';

  @override
  String get habitFrequencyTimesPerPeriodTitle => 'Периодтағы күндер';

  @override
  String get habitFrequencyTimesPerPeriodDescription =>
      'Апта, ай немесе жыл ішінде қанша күн орындау керегін қойыңыз.';

  @override
  String get habitTimesPerLabel => 'рет';

  @override
  String get habitFrequencyWorkRestTitle => 'Жұмыс / Демалыс';

  @override
  String get habitFrequencyWorkRestDescription =>
      'Әдет циклі: Жұмыс — орындау күндері, Демалыс — үзілістер.';

  @override
  String get habitWorkLabel => 'Жұмыс';

  @override
  String get habitRestLabel => 'Демалыс';

  @override
  String get habitChooseTimeRangeTitle => 'Бастау мерзімін таңдаңыз';

  @override
  String get habitSchedulingTitle => 'Кесте';

  @override
  String get habitStartDateLabel => 'Басталу күні';

  @override
  String get habitEndDateLabel => 'Аяқталу күні';

  @override
  String get habitNoEndDate => 'Аяқтау күні жоқ';

  @override
  String get habitCreateAction => 'Әдетті құру';

  @override
  String get habitForever => 'Шектеусіз';

  @override
  String get habitAddDateAction => 'Күн қосу';

  @override
  String get habitScheduleTitle => 'Кесте';

  @override
  String get habitFrequencySectionTitle => 'Жиілік';

  @override
  String get habitSelectDatePlaceholder => 'Таңдау';

  @override
  String get habitDeleteTitle => 'Әдетті жою керек пе?';

  @override
  String get habitDeleteMessage => 'Бұл әрекетті қайтару мүмкін емес.';

  @override
  String get habitEditTitle => 'Әдетті өңдеу';

  @override
  String get habitGeneralSection => 'Негізгі';

  @override
  String get habitAdvancedSection => 'Қосымша';

  @override
  String get habitConnectCourse => 'Курсты байланыстыру';

  @override
  String get habitCourseSyncHint =>
      'Осы курстарға оқығанда прогресс синхрондалады.';

  @override
  String get habitCourseNumericWarning =>
      'Курстарды қосу үшін Иә/Жоқ немесе Уақыт түрін таңдаңыз.';

  @override
  String get habitReminderDisabledTitle => 'Еске салу';

  @override
  String get habitReminderDisabledSubtitle => 'Жақында';

  @override
  String get habitArchiveTitle => 'Әдетті архивтеу';

  @override
  String get habitArchivedLabel => 'Архивте';

  @override
  String get habitResetProgressTitle => 'Қалпына келтіру';

  @override
  String get habitResetProgressSubtitle => 'Барлық тарих өшіріледі';

  @override
  String get habitResetProgressConfirmTitle => 'Әдет прогресін өшіру керек пе?';

  @override
  String get habitResetProgressConfirmMessage =>
      'Бұл әдеттің бүкіл тарихын жояды. Қайтаруға болмайды.';

  @override
  String get habitUnarchived => 'Әдет архивтен шығарылды';

  @override
  String get connectionsTabLabel => 'Адамдар';

  @override
  String get addPersonTitle => 'Адам қосу';

  @override
  String get editPersonTitle => 'Өңдеу';

  @override
  String get personNameLabel => 'Аты';

  @override
  String get personNameHint => 'Толық атын енгізіңіз';

  @override
  String get groupsLabel => 'Топтар';

  @override
  String get tagsLabel => 'Тегтер';

  @override
  String get phoneLabel => 'Телефон';

  @override
  String get emailLabel => 'Email';

  @override
  String get notesLabel => 'Жазбалар';

  @override
  String get lastContactedLabel => 'Соңғы байланыс';

  @override
  String get remindMeLabel => 'Хабарласуды еске салу';

  @override
  String get manageGroupsTitle => 'Топтарды басқару';

  @override
  String get interactionLogTitle => 'Қарым-қатынас журналы';

  @override
  String get markContactedToday => 'Бүгін хабарласты деп белгілеу';

  @override
  String get noConnectionsPlaceholder => 'Әзірге адамдар жоқ';

  @override
  String get searchConnectionsHint => 'Адамдарды іздеу...';

  @override
  String get filterAll => 'Барлығы';

  @override
  String get sortByRecent => 'Соңғы';

  @override
  String get sortByName => 'Аты';

  @override
  String get sortByPriority => 'Басымдық';

  @override
  String get deleteContactTitle => 'Контактіні жою керек пе?';

  @override
  String deleteContactMessage(String name) {
    return '\"$name\" жойылсын ба?';
  }

  @override
  String get deleteConnectionGroupTitle => 'Топты жою керек пе?';

  @override
  String deleteConnectionGroupMessage(String name) {
    return 'Бұл \"$name\" тобын барлық контактілерден өшіреді. Қайтару мүмкін емес.';
  }

  @override
  String get renameGroup => 'Атын өзгерту';

  @override
  String get newGroup => 'Жаңа топ';

  @override
  String get editGroup => 'Топты өңдеу';

  @override
  String get groupNameLabel => 'Топ атауы';

  @override
  String get noInteractionsYet => 'Қарым-қатынас әлі жоқ';

  @override
  String get addInteractionHint => 'Не туралы сөйлестіңіздер?';

  @override
  String get habitUnarchiveAction => 'Архивтен шығару';

  @override
  String get archivedHabitsTitle => 'Архивтегі әдеттер';

  @override
  String get archivedHabitsEmpty => 'Архивте әдет жоқ';

  @override
  String get habitsCalendarTitle => 'Календарь';

  @override
  String get habitTimeHourShort => 'Сағ';

  @override
  String get habitTimeMinuteShort => 'Мин';

  @override
  String get habitTimeSecondShort => 'Сек';

  @override
  String get habitCategoryStudy => 'Оқу';

  @override
  String get habitCategorySports => 'Спорт';

  @override
  String get habitCategoryQuitBadHabit => 'Жаман әдеттен бас тарту';

  @override
  String get habitCategoryHome => 'Үй';

  @override
  String get habitCategoryHealth => 'Денсаулық';

  @override
  String get habitCategoryWork => 'Жұмыс';

  @override
  String get habitResetProgressMessage =>
      'Бұл әдеттің барлық тарихы өшіріледі. Қайтару мүмкін емес.';

  @override
  String get habitResetProgressAction => 'Тазарту';

  @override
  String get habitFrequencyRepeatsTitle => 'Қайталау';

  @override
  String habitFrequencyEveryXDays(int count) {
    return 'Әр $count күн';
  }

  @override
  String get habitDragToCategorize => 'Санатқа бөлу үшін сүйреңіз';

  @override
  String get habitStatsEmptyState =>
      'Әдеттер табылмады. Прогрессті қадағалау үшін әдет қосыңыз. Бұл өте керемет, сеніңіз!';

  @override
  String get habitStatsCompletionRate => 'Орындалу пайызы';

  @override
  String get habitStatsCompleted => 'Орындалды';

  @override
  String get habitStatsMissed => 'Жіберіп алдыңыз';

  @override
  String get habitReportDownload => 'Есепті жүктеп алу';

  @override
  String get habitReportTitle => 'Есепті жүктеп алу';

  @override
  String get habitReportDownloadAction => 'Жүктеп алу';

  @override
  String get shareFile => 'Файлды бөлісу';

  @override
  String habitReportSaved(String path) {
    return 'Сақталды: $path';
  }

  @override
  String habitReportFileName(String month, int year) {
    return 'әдеттер_${month}_$year';
  }

  @override
  String habitReportFailed(String error) {
    return 'Экспорттау қатесі: $error';
  }

  @override
  String get csvDay => 'Күн';

  @override
  String get csvTotalCompleted => 'Барлығы орындалды';

  @override
  String get csvTarget => 'Мақсат';

  @override
  String get csvRate => 'Пайыз';

  @override
  String get exportFormat => 'Экспорт форматы';

  @override
  String get exportFormatCSV => 'CSV';

  @override
  String get exportFormatExcel => 'Excel';

  @override
  String get exportSuccess => 'Экспорт сәтті';

  @override
  String get exportSuccessMessage => 'Файл сәтті сақталды';

  @override
  String get openFile => 'Файлды ашу';

  @override
  String get close => 'Жабу';

  @override
  String get interactionCalendarTitle => 'Қарым-қатынас күнтізбесі';

  @override
  String get signInToViewConnections => 'Адамдарыңызды көру үшін кіріңіз.';

  @override
  String get personNotFound => 'Адам табылмады';

  @override
  String errorSaving(String error) {
    return 'Сақтау қатесі: $error';
  }

  @override
  String get add => 'Қосу';

  @override
  String get habitWeekNext => 'Келесі апта';

  @override
  String get habitWeekLast => 'Өткен апта';

  @override
  String get habitWeeksAgo => 'апта бұрын';

  @override
  String get habitWeekCurrent => 'Осы апта';

  @override
  String get copiedToClipboard => 'Алмасу буферіне көшірілді';
}
