// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Russian (`ru`).
class AppLocalizationsRu extends AppLocalizations {
  AppLocalizationsRu([String locale = 'ru']) : super(locale);

  @override
  String get habitTypeLockedHint =>
      'Тип привычки нельзя изменить после создания';

  @override
  String get settingsTitle => 'Аккаунт и настройки';

  @override
  String get account => 'Аккаунт';

  @override
  String get profile => 'Профиль';

  @override
  String get appearance => 'Внешний вид';

  @override
  String get system => 'Системная';

  @override
  String get light => 'Светлая';

  @override
  String get dark => 'Темная';

  @override
  String get language => 'Язык';

  @override
  String get english => 'Английский';

  @override
  String get russian => 'Русский';

  @override
  String get kazakh => 'Казахский';

  @override
  String get accentColor => 'Акцентный цвет';

  @override
  String get buttonPreview => 'Кнопка';

  @override
  String get accentColorDescription => 'Настройте ваш основной цвет';

  @override
  String get preview => 'Предпросмотр';

  @override
  String get textExample => 'Пример текста';

  @override
  String get customColor => 'Свой цвет';

  @override
  String get hue => 'Оттенок';

  @override
  String get saturation => 'Насыщенность';

  @override
  String get lightness => 'Яркость';

  @override
  String get presets => 'Пресеты';

  @override
  String get defaultPreset => 'По умолчанию';

  @override
  String get rosePreset => 'Розовый';

  @override
  String get emeraldPreset => 'Изумрудный';

  @override
  String get indigoPreset => 'Индиго';

  @override
  String get coralPreset => 'Коралловый';

  @override
  String get tealPreset => 'Бирюзовый';

  @override
  String get createPreset => 'Создать пресет';

  @override
  String get presetName => 'Название пресета';

  @override
  String get lettersOnly => 'Буквы и пробелы';

  @override
  String get max16Symbols => 'Макс. 16 символов';

  @override
  String get deletePreset => 'Удалить пресет';

  @override
  String get presetLimitReached => 'Достигнут лимит пресетов (22)';

  @override
  String get weekStartsOn => 'Начало недели';

  @override
  String get displayTotalStudyTime =>
      'Показывать общее время учебы по курсу за';

  @override
  String get displayProgressBar => 'Показывать прогресс за';

  @override
  String get quickNotes => 'Быстрые заметки';

  @override
  String get wantToReceiveNudges => 'Получать подталкивания?';

  @override
  String get eisenhowerMatrix => 'Матрица Эйзенхауэра';

  @override
  String get quickNotesDescription =>
      'Существующие заметки сохранятся, но новые окна заметок после сессий появляться не будут.';

  @override
  String get wantToReceiveNudgesDescription =>
      'Разрешить участникам группы отправлять вам напоминания.';

  @override
  String get eisenhowerMatrixDescription =>
      'Используйте матрицу Эйзенхауэра на экране привычек, чтобы упорядочить их по важности и срочности.';

  @override
  String get sessionNotification => 'Уведомление о сессии';

  @override
  String get sessionNotificationDescription =>
      'Показывать управление сессией в панели уведомлений во время записи.';

  @override
  String get eisenhowerQuadrant1 => 'Срочно и важно';

  @override
  String get eisenhowerQuadrant2 => 'Не срочно, но важно';

  @override
  String get eisenhowerQuadrant3 => 'Срочно, но не важно';

  @override
  String get eisenhowerQuadrant4 => 'Не срочно и не важно';

  @override
  String get eisenhowerHint => 'Перетащите привычки в матрицу для организации';

  @override
  String get yes => 'Да';

  @override
  String get no => 'Нет';

  @override
  String get data => 'Данные';

  @override
  String get exportToCalendar => 'Экспорт в календарь';

  @override
  String exportWillStartIn(int seconds) {
    return 'Экспорт начнется через $seconds сек.';
  }

  @override
  String get exportToCalendarSubtitle =>
      'Сохраните свои сессии как события календаря';

  @override
  String get allCourses => 'Все курсы';

  @override
  String get courseFallback => 'Курс';

  @override
  String get export => 'Экспортировать';

  @override
  String get exporting => 'Экспорт...';

  @override
  String exportFailedMessage(String error) {
    return 'Экспорт не удался: $error';
  }

  @override
  String sessionsFound(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count сессий найдено',
      few: '$count сессии найдено',
      one: '$count сессия найдена',
      zero: 'Сессий не найдено',
    );
    return '$_temp0';
  }

  @override
  String habitReportDownloadCountdown(int seconds) {
    return 'Генерация отчета начнется через $seconds сек.';
  }

  @override
  String get fileSavedSuccessfully => 'Файл успешно создан';

  @override
  String get fileSavedAt => 'Файл сохранён по пути:';

  @override
  String get unknownPath => 'Неизвестный путь';

  @override
  String get nextSteps => 'Следующие шаги:';

  @override
  String get exportCalendarNextStepsBody =>
      '• Откройте этот файл и импортируйте его в приложение календаря,\n• ИЛИ откройте настройки приложения календаря и импортируйте файл вручную.';

  @override
  String get deleteAccount => 'Удалить аккаунт';

  @override
  String get deleteAccountSubtitle => 'Навсегда удалить аккаунт и все данные';

  @override
  String get deleteAccountHoldConfirmDetail =>
      'После удержания кнопки в течение 5 секунд аккаунт будет удалён навсегда';

  @override
  String get deletingAccount => 'Удаление аккаунта...';

  @override
  String get accountDeleted => 'Аккаунт удалён';

  @override
  String get pleaseSignInToViewAccount =>
      'Пожалуйста, войдите, чтобы просмотреть ваш аккаунт.';

  @override
  String get signOut => 'Выйти';

  @override
  String get syncNow => 'Синхронизировать';

  @override
  String get syncing => 'Синхронизация';

  @override
  String get home => 'Главная';

  @override
  String get statistics => 'Статистика';

  @override
  String get groups => 'Группы';

  @override
  String get addCourse => 'Добавить курс';

  @override
  String get addTime => 'Добавить время';

  @override
  String get courseName => 'Название курса';

  @override
  String get courseNameHint => '';

  @override
  String get required => 'Обязательно';

  @override
  String get color => 'Цвет';

  @override
  String get creditsOptional => 'Кредиты (необязательно)';

  @override
  String get creditsHint => 'например, 6 или 7';

  @override
  String get creditsHelper => 'Добавьте кредиты для целей самообучения';

  @override
  String get experienceLevel => 'Уровень опыта';

  @override
  String get save => 'Сохранить';

  @override
  String get cancel => 'Отмена';

  @override
  String get delete => 'Удалить';

  @override
  String get deleteCourseTitle => 'Удалить курс';

  @override
  String get deleteCourseMessage =>
      'Вы уверены? Все данные этого курса будут удалены.';

  @override
  String timeSavedMessage(String courseName) {
    return 'Время для \"$courseName\" сохранено';
  }

  @override
  String get aiAnalysisComingSoon => 'Анализ курса скоро появится.';

  @override
  String get courseAnalysis => 'Анализ курса';

  @override
  String get noCoursesAvailable => 'Нет доступных курсов.';

  @override
  String get selectCourse => 'Выберите курс';

  @override
  String get sixMonths => '6 месяцев';

  @override
  String get analysisUpdatesEveryPeriod =>
      'Анализ обновляется с началом каждого нового периода.';

  @override
  String get analysisAlreadyGenerated =>
      'Вы уже создали анализ для этого периода.';

  @override
  String get dayStatsTipLine1 =>
      '• Календарь показывает вашу учебную активность. Чем зеленее день, тем больше вы учились.';

  @override
  String get dayStatsTipLine2 =>
      '• Вы можете редактировать время сессии и заметки в Истории.';

  @override
  String get dayStatsTipLine3 =>
      '• Вы можете нажать на любой курс, и экран истории покажет сессии только по этому курсу.';

  @override
  String get syncOffline => 'Офлайн';

  @override
  String get syncSyncing => 'Синхронизация…';

  @override
  String get syncUpToDate => 'Обновлено';

  @override
  String get setGoals => 'Цели';

  @override
  String get daily => 'День';

  @override
  String get weekly => 'Неделя';

  @override
  String get studyTimer => 'Таймер учебы';

  @override
  String get noCoursesYet => 'Пока нет курсов. Добавьте курс на главной.';

  @override
  String get chooseACourse => 'Выберите курс';

  @override
  String get start => 'Старт';

  @override
  String get stop => 'Стоп';

  @override
  String get reset => 'Сброс';

  @override
  String get ok => 'ОК';

  @override
  String get timerStoppedAndSaved => 'Таймер остановлен и сохранен.';

  @override
  String get nothingToReset => 'Нечего сбрасывать.';

  @override
  String anotherSessionRunning(String sessionType) {
    return 'Другой $sessionType уже запущен. Остановите его сначала.';
  }

  @override
  String anotherSessionRunningOn(String sessionType, String courseName) {
    return 'Другой $sessionType уже запущен на \"$courseName\". Остановите его сначала.';
  }

  @override
  String anotherSessionRunningSilly(String sessionType) {
    return 'Другой $sessionType уже запущен, глупышка.';
  }

  @override
  String get alreadyStudiedThisPeriod =>
      'Вы уже занимались в этот период времени.';

  @override
  String get friendJoinPrompt =>
      'Ваш друг может присоединиться, введя название вашей группы в строку поиска.';

  @override
  String get enterTimeFirst => 'Сначала введите время';

  @override
  String get nothingToSave => 'Нечего сохранять';

  @override
  String get maxTimeCapped => 'Максимум 3:00:00 — ограничено';

  @override
  String get studiedLabel => 'Изучено';

  @override
  String get goalsUpdated => 'Цели обновлены';

  @override
  String get studiedToday => 'Изучено сегодня';

  @override
  String get studiedThisWeek => 'Изучено на этой неделе';

  @override
  String get studiedThisMonth => 'Изучено в этом месяце';

  @override
  String get studiedThisYear => 'Изучено в этом году';

  @override
  String get studiedOverall => 'Изучено всего';

  @override
  String get timer => 'таймер';

  @override
  String get stopwatch => 'секундомер';

  @override
  String get pomodoro => 'помодоро';

  @override
  String get session => 'сеанс';

  @override
  String get editCourse => 'Редактировать курс';

  @override
  String get today => 'Сегодня';

  @override
  String get edit => 'Редактировать';

  @override
  String get timerTab => 'Таймер';

  @override
  String get stopwatchTab => 'Секундомер';

  @override
  String get pomodoroTab => 'Помодоро';

  @override
  String get typeTimeToStudy => 'Введите время, которое вам нужно для учебы';

  @override
  String get maxTime => 'Макс: 3:00:00';

  @override
  String get elapsed => 'прошло';

  @override
  String completedPomodoros(int completed) {
    return 'Завершено помодоро: $completed / 4';
  }

  @override
  String longBreakLength(int minutes) {
    return 'Длина длинного перерыва ($minutes мин)';
  }

  @override
  String get work => 'Работа';

  @override
  String get shortBreak => 'Короткий перерыв';

  @override
  String get longBreak => 'Длинный перерыв';

  @override
  String get paused => 'пауза';

  @override
  String get resume => 'Продолжить';

  @override
  String get pause => 'Пауза';

  @override
  String get skipBreak => 'Пропустить перерыв';

  @override
  String get pomodoroExitWarning => 'Сеанс помодоро запущен. Все равно выйти?';

  @override
  String get exitAnyway => 'Выйти в любом случае';

  @override
  String get expLevel1 => 'Полный новичок';

  @override
  String get expLevel2 => 'Знаю основы';

  @override
  String get expLevel3 => 'Уверенно владею предметом';

  @override
  String get expLevel4 => 'Продвинутый уровень знаний';

  @override
  String get expLevel5 => 'Широкий опыт';

  @override
  String get expLevelDefault => 'Уверенно';

  @override
  String get dayStatistics => 'Статистика дня';

  @override
  String get periodStatistics => 'Статистика периода';

  @override
  String get tip => 'Совет';

  @override
  String get chartTip =>
      '• Удерживайте палец на графике и ведите влево или вправо для перемещения между днями или месяцами.';

  @override
  String get courseStatistics => 'Статистика курсов';

  @override
  String get previousDay => 'Предыдущий день';

  @override
  String get nextDay => 'Следующий день';

  @override
  String get history => 'История';

  @override
  String get week => 'Неделя';

  @override
  String get month => 'Месяц';

  @override
  String get year => 'Год';

  @override
  String get previousWeek => 'предыдущая неделя';

  @override
  String get previousMonth => 'предыдущий месяц';

  @override
  String get previousYear => 'предыдущий год';

  @override
  String get nextWeek => 'следующая неделя';

  @override
  String get nextMonth => 'следующий месяц';

  @override
  String get nextYear => 'следующий год';

  @override
  String get noData => 'Нет данных';

  @override
  String get hours => 'Часы';

  @override
  String get minutes => 'Минуты';

  @override
  String totalThisPeriod(String period) {
    return 'Всего за $period';
  }

  @override
  String get avgPerDay => 'Среднее в день';

  @override
  String get mostStudied => 'Больше всего';

  @override
  String get leastStudied => 'Меньше всего';

  @override
  String get adjustWeeklyGoal => 'Настройте еженедельную цель';

  @override
  String get targetPerWeek => 'Цель в неделю';

  @override
  String get targetPerDay => 'Цель в день';

  @override
  String semester(int weeks) {
    return 'Семестр (~$weeks нед)';
  }

  @override
  String hPerWeek(String hours) {
    return '$hours ч/нед';
  }

  @override
  String get createGroup => 'Создать группу';

  @override
  String get joinGroup => 'Присоедиться';

  @override
  String get groupName => 'Название группы';

  @override
  String get description => 'Описание';

  @override
  String get privacy => 'Конфиденциальность';

  @override
  String get public => 'Публичная';

  @override
  String get private => 'Приватная';

  @override
  String get accessCode => 'Код доступа';

  @override
  String get members => 'Участники';

  @override
  String get leaveGroup => 'Покинуть группу';

  @override
  String get deleteGroup => 'Удалить группу';

  @override
  String get groupSettings => 'Настройки группы';

  @override
  String get noGroupsYet => 'Вы еще не состоите ни в одной группе';

  @override
  String get noSearchResults => 'У нас здесь такого нет';

  @override
  String get createOrJoinPrompt =>
      'Создайте новую группу или присоединитесь к существующей, чтобы сотрудничать с другими';

  @override
  String get signInPrompt => 'Войдите, чтобы исследовать группы.';

  @override
  String errorLoadingMemberships(String error) {
    return 'Ошибка загрузки членства: $error';
  }

  @override
  String get findPublicGroupHint => 'Найти группу...';

  @override
  String get searchResults => 'Результаты поиска';

  @override
  String errorLoadingGroups(String error) {
    return 'Ошибка загрузки групп: $error';
  }

  @override
  String get joinedSuccessfully => 'Вы успешно вступили в группу';

  @override
  String get joinedPrivateSuccessfully =>
      'Вы успешно вступили в закрытую группу';

  @override
  String joinGroupDialogTitle(String groupName) {
    return 'Вступить в $groupName';
  }

  @override
  String get joinGroupDialogMessage =>
      'Введите код доступа для входа в эту закрытую группу.';

  @override
  String get joinCodeHint => 'например, ABC123';

  @override
  String get publicGroups => 'Публичные группы';

  @override
  String joinError(String error) {
    return 'Не удалось вступить в группу: $error';
  }

  @override
  String get noDescription => 'Описание отсутствует.';

  @override
  String membersCount(int count) {
    return 'Участников: $count';
  }

  @override
  String get yourGroup => 'Ваша группа';

  @override
  String get findStudyGroup => 'Найдите свою учебную группу';

  @override
  String get joinCommunityPrompt =>
      'Присоединяйтесь к сообществу, чтобы отслеживать прогресс, соревноваться и сохранять мотивацию вместе.';

  @override
  String get administrator => 'Админ';

  @override
  String get memberLabel => 'Участник';

  @override
  String get unableToLoadGroup => 'Не удалось загрузить данные группы';

  @override
  String get checkConnection => 'Пожалуйста, проверьте интернет-соединение';

  @override
  String get retry => 'Повторить';

  @override
  String get groupNotFound => 'Группа не найдена или была удалена.';

  @override
  String get signInToManage =>
      'Вам необходимо войти в систему, чтобы управлять этой группой.';

  @override
  String get noLongerMember => 'Вы больше не являетесь участником этой группы.';

  @override
  String get groupNameHint => 'Введите название группы';

  @override
  String get visibility => 'Видимость';

  @override
  String get descriptionHint => 'Опишите вашу группу в нескольких словах';

  @override
  String get codeRequired => 'Код обязателен';

  @override
  String get codeJoinPrompt => 'Этот код нужен новым участникам для входа.';

  @override
  String get onlyAdminVisibility =>
      'Только администраторы могут менять настройки.';

  @override
  String get saving => 'Сохранение...';

  @override
  String get saveChanges => 'Сохранить изменения';

  @override
  String get membersTitle => 'Участники';

  @override
  String get unableToLoadMembers => 'Не удалось загрузить список участников';

  @override
  String get checkConnectionTryAgain =>
      'Пожалуйста, проверьте соединение и попробуйте снова';

  @override
  String get noMembersYetLabel => 'Участников пока нет.';

  @override
  String get youAdmin => 'Вы (админ)';

  @override
  String get youMember => 'Вы';

  @override
  String get youOwner => 'Вы (владелец)';

  @override
  String get removeMemberTitle => 'Удалить участника?';

  @override
  String get removeMemberMessage =>
      'Удалить этого участника из группы? Он потеряет доступ немедленно.';

  @override
  String get memberRemoved => 'Участник удален';

  @override
  String get groupUpdated => 'Группа обновлена';

  @override
  String failedToUpdateGroup(String error) {
    return 'Ошибка обновления группы: $error';
  }

  @override
  String failedToDeleteGroup(String error) {
    return 'Ошибка удаления группы: $error';
  }

  @override
  String failedToLeaveGroup(String error) {
    return 'Ошибка выхода из группы: $error';
  }

  @override
  String failedToRemoveMember(String error) {
    return 'Ошибка удаления участника: $error';
  }

  @override
  String get groupCodeLabel => 'Код группы';

  @override
  String get dailyGoal => 'В день';

  @override
  String get weeklyGoal => 'В неделю';

  @override
  String get hUnit => 'ч';

  @override
  String get mUnit => 'м';

  @override
  String get sUnit => 'с';

  @override
  String errorLoadingLeaderboard(String error) {
    return 'Ошибка загрузки таблицы лидеров: $error';
  }

  @override
  String get courseHiddenFromLeaderboard => 'Курс скрыт из таблицы лидеров';

  @override
  String get courseVisibleInLeaderboard => 'Курс виден в таблице лидеров';

  @override
  String get hideFromLeaderboard => 'Скрыть из таблицы лидеров';

  @override
  String get unhideFromLeaderboard => 'Показать в таблице лидеров';

  @override
  String get noDataAvailable => 'Нет данных за этот период';

  @override
  String get groupLeaderboard => 'Таблица лидеров';

  @override
  String rankLabel(int rank) {
    return '#$rank';
  }

  @override
  String failedToLoadUserData(String error) {
    return 'Ошибка загрузки данных пользователя: $error';
  }

  @override
  String get sun => 'Вс';

  @override
  String get mon => 'Пн';

  @override
  String get tue => 'Вт';

  @override
  String get wed => 'Ср';

  @override
  String get thu => 'Чт';

  @override
  String get fri => 'Пт';

  @override
  String get sat => 'Сб';

  @override
  String get sunday => 'Воскресенье';

  @override
  String get monday => 'Понедельник';

  @override
  String get tuesday => 'Вторник';

  @override
  String get wednesday => 'Среда';

  @override
  String get thursday => 'Четверг';

  @override
  String get friday => 'Пятница';

  @override
  String get saturday => 'Суббота';

  @override
  String get january => 'Январь';

  @override
  String get february => 'Февраль';

  @override
  String get march => 'Март';

  @override
  String get april => 'Апрель';

  @override
  String get may => 'Май';

  @override
  String get june => 'Июнь';

  @override
  String get july => 'Июль';

  @override
  String get august => 'Август';

  @override
  String get september => 'Сентябрь';

  @override
  String get october => 'Октябрь';

  @override
  String get november => 'Ноябрь';

  @override
  String get december => 'Декабрь';

  @override
  String get total => 'Всего';

  @override
  String get groupSummary => 'Сводка группы';

  @override
  String get average => 'Среднее';

  @override
  String get leader => 'Лидер';

  @override
  String get lowest => 'Минимум';

  @override
  String get vsAverage => 'от среднего';

  @override
  String get studyTimeComparison => 'Сравнение времени учебы';

  @override
  String get performanceVsGroup => 'Прогресс относительно группы';

  @override
  String get ofAverage => 'от среднего';

  @override
  String get studyTimeByDay => 'Время по дням';

  @override
  String get bestDay => 'Лучший день';

  @override
  String get avgDay => 'В среднем/день';

  @override
  String get member => 'Участник';

  @override
  String get todayDataTable => 'Сегодня';

  @override
  String get monthDataTable => 'Месяц';

  @override
  String get overThisWeek => 'за эту неделю';

  @override
  String get overThisMonth => 'за этот месяц';

  @override
  String get overThisYear => 'за этот год';

  @override
  String get hour => 'час';

  @override
  String get hours_plural => 'часов';

  @override
  String get minute => 'минута';

  @override
  String get minutes_plural => 'минут';

  @override
  String get second => 'секунда';

  @override
  String get seconds_plural => 'секунд';

  @override
  String get jan => 'Янв';

  @override
  String get feb => 'Фев';

  @override
  String get mar => 'Мар';

  @override
  String get apr => 'Апр';

  @override
  String get mayShort => 'Май';

  @override
  String get jun => 'Июн';

  @override
  String get jul => 'Июл';

  @override
  String get aug => 'Авг';

  @override
  String get sep => 'Сен';

  @override
  String get oct => 'Окт';

  @override
  String get nov => 'Ноя';

  @override
  String get dec => 'Дек';

  @override
  String get via => 'через';

  @override
  String get viaTimer => 'через Таймер';

  @override
  String get viaStopwatch => 'через Секундомер';

  @override
  String get viaPomodoro => 'Через Помидоро';

  @override
  String get viaManualRecording => 'Через ручной ввод';

  @override
  String get startTime => 'Начало';

  @override
  String get endTime => 'Окончание';

  @override
  String get duration => 'Длительность';

  @override
  String get reflection => 'Заметка';

  @override
  String get overThis => 'за';

  @override
  String get credits => 'Кредит';

  @override
  String get credits_plural => 'Кредитов';

  @override
  String get deleteSession => 'Удалить сеанс?';

  @override
  String get deleteSessionMessage =>
      'Это удалит сеанс из вашей истории и статистики.';

  @override
  String get sessionDeleted => 'Сеанс удален';

  @override
  String get leaveGroupTitle => 'Покинуть группу?';

  @override
  String get leaveGroupMessage => 'Вы уверены, что хотите покинуть эту группу?';

  @override
  String get leave => 'Покинуть';

  @override
  String get deleteGroupTitle => 'Удалить группу?';

  @override
  String get deleteGroupMessage =>
      'Это навсегда удалит группу для всех участников.';

  @override
  String get manageGroup => 'Управление группой';

  @override
  String get admin => 'Админ';

  @override
  String get removeMember => 'Удалить участника';

  @override
  String get makeAdmin => 'Сделать администратором';

  @override
  String get removeAdmin => 'Снять администратора';

  @override
  String get owner => 'Владелец';

  @override
  String get memberPromoted => 'Участник назначен администратором';

  @override
  String get adminDemoted => 'Администратор понижен до участника';

  @override
  String get failedToPromote => 'Не удалось назначить администратором';

  @override
  String get failedToDemote => 'Не удалось понизить администратора';

  @override
  String get demoteTooltip => 'Понизить до участника';

  @override
  String get makeAdminTooltip => 'Сделать администратором';

  @override
  String get cannotEnterFutureTime => 'Вы не можете вводить время в будущем.';

  @override
  String get startTimeLaterThanEndTime =>
      'Время начала не может быть позже времени окончания.';

  @override
  String timeAddedToCourse(String courseName) {
    return 'Время добавлено в $courseName';
  }

  @override
  String get currentDay => 'текущий день';

  @override
  String get thisWeekShort => 'эту неделю';

  @override
  String get thisMonthShort => 'этот месяц';

  @override
  String get thisYearShort => 'этот год';

  @override
  String get overall => 'все время';

  @override
  String get dayGoalLabel => 'дневная цель';

  @override
  String get weekGoalLabel => 'недельная цель';

  @override
  String get on => 'вкл';

  @override
  String get off => 'выкл';

  @override
  String get justSwipeIt => 'Просто смахните';

  @override
  String get customPhotosUnavailable =>
      'Пользовательские фото временно недоступны.';

  @override
  String get unableToPickImage => 'Не удалось выбрать изображение.';

  @override
  String get couldNotSaveProfile =>
      'Не удалось сохранить профиль. Пожалуйста, попробуйте снова.';

  @override
  String get yourName => 'Ваше имя';

  @override
  String get addPersonalGoal => 'Добавьте личную цель';

  @override
  String get nameLabel => 'Имя';

  @override
  String get nameRequired => 'Имя обязательно';

  @override
  String get majorLabel => 'Специальность';

  @override
  String get majorRequired => 'Специальность обязательна';

  @override
  String get contactLabel => 'Как с вами связаться';

  @override
  String get contactHint => 'напр., телефон или ник в tg';

  @override
  String get personalGoalLabel => 'Личная цель';

  @override
  String get personalGoalHint => 'напр., Стать лучше';

  @override
  String get chooseAvatar => 'Выберите аватар';

  @override
  String get photoLibraryUnavailable => 'Библиотека фото недоступна';

  @override
  String get iconColor => 'Цвет иконки';

  @override
  String get saved => 'Сохранено';

  @override
  String get done => 'Готово';

  @override
  String get stay => 'Остаться';

  @override
  String get resetAndLeave => 'Сбросить и выйти';

  @override
  String get leavePomodoroTitle => 'Покинуть Помодоро?';

  @override
  String get leavePomodoroMessage =>
      'Цикл Помодоро запущен. Сбросить его перед выходом из этой вкладки?';

  @override
  String get timeFormatHint => 'ЧЧ:ММ:СС';

  @override
  String get addCourseFirst => 'Сначала добавьте курс';

  @override
  String invalidTimeFormat(String format) {
    return 'Введите время как $format';
  }

  @override
  String get signIn => 'Войти';

  @override
  String get register => 'Регистрация';

  @override
  String get loginSubtitle => 'Мы скучали';

  @override
  String get registerSubtitle => '<3';

  @override
  String get emailAddress => 'Эл. почта';

  @override
  String get password => 'Пароль';

  @override
  String get displayName => 'Отображаемое имя';

  @override
  String get createAccount => 'Создать аккаунт';

  @override
  String get afterCreatingAccount =>
      'После создания аккаунта вам нужно будет подтвердить эл. почту, чтобы начать пользоваться приложением.';

  @override
  String get verificationEmailSent => 'Письмо с подтверждением отправлено!';

  @override
  String get signedInSuccessfully => 'Вход выполнен успешно';

  @override
  String get resendEmail => 'Отправить повторно';

  @override
  String get enterEmail => 'Пожалуйста, введите адрес эл. почты.';

  @override
  String get invalidEmail => 'Пожалуйста, введите корректный адрес эл. почты.';

  @override
  String get enterPassword => 'Введите пароль.';

  @override
  String get displayNameLength => 'Имя должно быть не менее 2 символов.';

  @override
  String get passwordLength => 'Пароль должен быть не менее 8 символов.';

  @override
  String get passwordInvalidChars =>
      'Поддерживаются только A–Z, a–z, 0–9 и разрешенные символы.';

  @override
  String get displayNameInvalidChars =>
      'Отображаемое имя может содержать только буквы и цифры.';

  @override
  String get min8Chars => 'Минимум 8 символов.';

  @override
  String get loadingProfile => 'Загрузка профиля';

  @override
  String get loggingOut => 'Выход из аккаунта...';

  @override
  String get forgotPassword => 'Забыли пароль?';

  @override
  String get resetPasswordTitle => 'Сброс пароля';

  @override
  String get resetPasswordSubtitle =>
      'Укажите почту аккаунта. Мы отправим ссылку для сброса.';

  @override
  String get sendResetLink => 'Отправить ссылку';

  @override
  String get resetLinkSent =>
      'Если аккаунт существует, мы отправили ссылку для сброса.';

  @override
  String get backToSignIn => 'Назад к входу';

  @override
  String get verifyEmailFirst =>
      'Сначала подтвердите почту. Мы отправили письмо для подтверждения.';

  @override
  String get resendVerificationEmail => 'Отправить письмо повторно';

  @override
  String get invalidEmailFormat => 'Введите корректный email.';

  @override
  String get resetRateLimited => 'Подождите немного перед следующей попыткой.';

  @override
  String get networkRequestFailed =>
      'Ошибка сети. Проверьте соединение и повторите.';

  @override
  String get signInToResend => 'Войдите, чтобы отправить письмо повторно.';

  @override
  String tryAgainInSeconds(int seconds) {
    return 'Повторите через $seconds с';
  }

  @override
  String get sessionNotes => 'Заметки к сессии';

  @override
  String get sessionNotesHint => 'Добавьте заметки к этой сессии';

  @override
  String get sendNotes => 'Отправить заметки';

  @override
  String get updateNotes => 'Обновить заметки';

  @override
  String get notesSaved => 'Заметки сохранены';

  @override
  String get failedToPrepareData => 'Не удалось подготовить данные.';

  @override
  String sessionFinished(String duration) {
    return 'Занятие завершено: $duration';
  }

  @override
  String get whatDidYouWorkOn => 'Над чем вы работали?';

  @override
  String failedToSaveReflection(String error) {
    return 'Не удалось сохранить заметку: $error';
  }

  @override
  String get skip => 'Пропустить';

  @override
  String streakDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count-дневная серия',
      few: '$count-дневная серия',
      one: '$count-дневная серия',
    );
    return '$_temp0';
  }

  @override
  String get noStreakYet => 'Серии пока нет';

  @override
  String nudgeWaitMinutes(int minutes) {
    String _temp0 = intl.Intl.pluralLogic(
      minutes,
      locale: localeName,
      other: 'минут',
      few: 'минуты',
      one: 'минуту',
    );
    return 'Пожалуйста, подождите $minutes $_temp0 перед повторным подталкиванием.';
  }

  @override
  String nudgeWaitSeconds(int seconds) {
    String _temp0 = intl.Intl.pluralLogic(
      seconds,
      locale: localeName,
      other: 'секунд',
      few: 'секунды',
      one: 'секунду',
    );
    return 'Пожалуйста, подождите $seconds $_temp0 перед повторным подталкиванием.';
  }

  @override
  String get memberCannotReceiveNudges =>
      'Этот участник пока не может получать уведомления.';

  @override
  String get nudgeSent => 'Уведомление отправлено.';

  @override
  String failedToSendNudge(String error) {
    return 'Не удалось отправить уведомление: $error';
  }

  @override
  String get cannotNudgeSelf => 'Вы не можете подтолкнуть самого себя.';

  @override
  String get userProhibitedNudge => 'Этот пользователь отключил уведомления.';

  @override
  String get leaderboardHintMessage =>
      '• Вы можете нажать на любого пользователя в таблице лидеров, чтобы просмотреть его время обучения.\n• Нажмите на иконку руки рядом с аватаркой участника, чтобы подтолкнуть его.';

  @override
  String get habitsNavLabel => 'Привычки';

  @override
  String get habitStatistics => 'Статистика привычек';

  @override
  String get habitsTabProgress => 'Прогресс';

  @override
  String get habitsTabList => 'Мои привычки';

  @override
  String get habitsPleaseSignIn => 'Пожалуйста, войдите';

  @override
  String get habitsEmptyToday => 'На сегодня ничего нет. Ура!';

  @override
  String habitsListError(String error) {
    return 'Ошибка: $error';
  }

  @override
  String get habitsEmptyListTitle => 'Пока нет привычек';

  @override
  String get habitsEmptyListCta => 'Создать первую';

  @override
  String get habitRequirementMarkDone => 'Отметить выполненным';

  @override
  String habitRequirementToday(String current, String target, String unit) {
    return '$current / $target $unit сегодня';
  }

  @override
  String habitRequirementTodayNoUnit(String current, String target) {
    return '$current / $target сегодня';
  }

  @override
  String get habitFrequencyEveryDay => 'Каждый день';

  @override
  String get habitFrequencySpecificMonth => 'Определенные дни месяца';

  @override
  String get habitFrequencySpecificDates => 'Конкретные даты';

  @override
  String habitFrequencyDaysLabel(String days) {
    return 'Дни: $days';
  }

  @override
  String habitFrequencyInterval(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: 'дней',
      many: 'дней',
      few: 'дня',
      one: 'день',
    );
    return 'Каждые $days $_temp0';
  }

  @override
  String habitFrequencyTimesPerPeriod(int count, String period) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count раз в $period',
      many: '$count раз в $period',
      few: '$count раза в $period',
      one: '$count раз в $period',
    );
    return '$_temp0';
  }

  @override
  String get habitPeriodWeek => 'Неделя';

  @override
  String get habitPeriodMonth => 'Месяц';

  @override
  String get habitPeriodYear => 'Год';

  @override
  String get habitDailyOverview => 'Ежедневный обзор';

  @override
  String get habitNoHabitsThisDay => 'В этот день привычек не выполнено.';

  @override
  String get habitMinutesShort => 'мин';

  @override
  String get habitLogSetTotal => 'Задать итог';

  @override
  String get habitLogAddMore => 'Добавить';

  @override
  String get habitUpdateProgress => 'Обновить прогресс';

  @override
  String get habitLogSetValueTitle => 'Установить значение';

  @override
  String get habitClearTime => 'Сбросить время';

  @override
  String habitProgressLabel(String date) {
    return 'Прогресс, $date';
  }

  @override
  String habitLogSettingTotal(String total) {
    return 'Устанавливаем итог $total';
  }

  @override
  String habitLogAdding(String value, String existing) {
    return 'Добавляем $value к $existing';
  }

  @override
  String habitGoalLabel(String goal) {
    return 'Цель: $goal';
  }

  @override
  String get habitCreateTitle => 'Создать новую привычку';

  @override
  String get habitTrackingTitle => 'Тип отслеживания';

  @override
  String get habitExplainHabit => 'Опишите привычку';

  @override
  String get habitNameLabel => 'Название привычки';

  @override
  String get habitNameHint => '';

  @override
  String get habitCategoryLabel => 'Категория';

  @override
  String get habitCategoryNew => 'Новая категория';

  @override
  String get habitCategoryNameLabel => 'Название категории';

  @override
  String get habitCategoryNameHint => 'например, чтение';

  @override
  String get habitCategoryDeleteTitle => 'Удалить категорию';

  @override
  String habitCategoryDeleteMessage(String name) {
    return 'Удалить «$name»? Это действие нельзя отменить.';
  }

  @override
  String get habitCategoryCreateAction => 'Создать свою';

  @override
  String get habitBack => 'Назад';

  @override
  String get habitNext => 'Далее';

  @override
  String get habitYesNo => 'Да / Нет';

  @override
  String get habitNumeric => 'Числовой';

  @override
  String get habitTime => 'Время';

  @override
  String get habitTrackingYesNoDescription =>
      'Отмечайте, выполнена привычка или нет.';

  @override
  String get habitTrackingNumericDescription =>
      'Задайте конкретное число на каждый день.';

  @override
  String get habitTrackingTimeDescription =>
      'Задайте длительность как ежедневную цель.';

  @override
  String get habitComparatorAtLeast => 'Не менее';

  @override
  String get habitComparatorLessThan => 'Меньше чем';

  @override
  String get habitComparatorExactly => 'Ровно';

  @override
  String get habitComparatorAny => 'Любое значение';

  @override
  String get habitValueLabel => 'Значение';

  @override
  String get habitUnitLabel => 'Единица';

  @override
  String get habitUnitHint => 'например, страницы';

  @override
  String get habitPerDay => 'в день';

  @override
  String get habitTimeLabel => 'часы : минуты : секунды';

  @override
  String get habitTimePlaceholder => '00:00:00';

  @override
  String get habitFrequencyPrompt => 'Выберите, как часто повторять привычку';

  @override
  String get habitFrequencySpecificTitle => 'Определенные дни';

  @override
  String get habitFrequencyDailyDescription =>
      'Выполняйте привычку каждый день без пропусков.';

  @override
  String get habitFrequencySpecificDescription =>
      'Выберите конкретные дни недели или даты.';

  @override
  String get habitFrequencyPeriodWeekLabel => 'Неделя';

  @override
  String get habitFrequencyPeriodMonthLabel => 'Месяц';

  @override
  String get habitFrequencyPeriodYearLabel => 'Год';

  @override
  String get habitFrequencyTimesPerPeriodTitle => 'Дней за период';

  @override
  String get habitFrequencyTimesPerPeriodDescription =>
      'Укажите, сколько дней в неделю, месяц или год.';

  @override
  String get habitTimesPerLabel => 'раз(а) в';

  @override
  String get habitFrequencyWorkRestTitle => 'Работа / Отдых';

  @override
  String get habitFrequencyWorkRestDescription =>
      'Задайте циклы привычки. Work — дни выполнения, Rest — выходные.';

  @override
  String get habitWorkLabel => 'Работа';

  @override
  String get habitRestLabel => 'Отдых';

  @override
  String get habitChooseTimeRangeTitle => 'Выберите период начала';

  @override
  String get habitSchedulingTitle => 'Расписание';

  @override
  String get habitStartDateLabel => 'Дата начала';

  @override
  String get habitEndDateLabel => 'Дата окончания';

  @override
  String get habitNoEndDate => 'Без даты окончания';

  @override
  String get habitCreateAction => 'Создать привычку';

  @override
  String get habitForever => 'Бессрочно';

  @override
  String get habitAddDateAction => 'Добавить дату';

  @override
  String get habitScheduleTitle => 'Расписание';

  @override
  String get habitFrequencySectionTitle => 'Частота';

  @override
  String get habitSelectDatePlaceholder => 'Выбрать';

  @override
  String get habitDeleteTitle => 'Удалить привычку?';

  @override
  String get habitDeleteMessage => 'Это действие нельзя отменить.';

  @override
  String get habitEditTitle => 'Изменить';

  @override
  String get habitGeneralSection => 'Основное';

  @override
  String get habitAdvancedSection => 'Дополнительно';

  @override
  String get habitConnectCourse => 'Связать курс';

  @override
  String get habitCourseSyncHint =>
      'Прогресс синхронизируется, когда вы занимаетесь по этим курсам.';

  @override
  String get habitCourseNumericWarning =>
      'Переключитесь на Да/Нет или Время, чтобы подключить курсы.';

  @override
  String get habitReminderDisabledTitle => 'Напоминания';

  @override
  String get habitReminderDisabledSubtitle => 'Скоро';

  @override
  String get habitArchiveTitle => 'Архивировать привычку';

  @override
  String get habitArchivedLabel => 'В архиве';

  @override
  String get habitResetProgressTitle => 'Сбросить прогресс';

  @override
  String get habitResetProgressSubtitle => 'Удаляет всю историю';

  @override
  String get habitResetProgressConfirmTitle => 'Сбросить прогресс привычки?';

  @override
  String get habitResetProgressConfirmMessage =>
      'Это удалит всю историю выполнения этой привычки. Действие необратимо.';

  @override
  String get habitUnarchived => 'Привычка разархивирована';

  @override
  String get connectionsTabLabel => 'Люди';

  @override
  String get addPersonTitle => 'Добавить человека';

  @override
  String get editPersonTitle => 'Редактировать';

  @override
  String get personNameLabel => 'Имя';

  @override
  String get personNameHint => 'Введите полное имя';

  @override
  String get groupsLabel => 'Группы';

  @override
  String get tagsLabel => 'Теги';

  @override
  String get phoneLabel => 'Телефон';

  @override
  String get emailLabel => 'Email';

  @override
  String get notesLabel => 'Заметки';

  @override
  String get lastContactedLabel => 'Последний контакт';

  @override
  String get remindMeLabel => 'Напомнить написать';

  @override
  String get manageGroupsTitle => 'Управление группами';

  @override
  String get interactionLogTitle => 'Журнал взаимодействий';

  @override
  String get markContactedToday => 'Отметить контакт сегодня';

  @override
  String get noConnectionsPlaceholder => 'Пока нет людей';

  @override
  String get searchConnectionsHint => 'Поиск людей...';

  @override
  String get filterAll => 'Все';

  @override
  String get sortByRecent => 'Недавние';

  @override
  String get sortByName => 'Имя';

  @override
  String get sortByPriority => 'Приоритет';

  @override
  String get deleteContactTitle => 'Удалить контакт?';

  @override
  String deleteContactMessage(String name) {
    return 'Вы уверены, что хотите удалить \"$name\"?';
  }

  @override
  String get deleteConnectionGroupTitle => 'Удалить группу?';

  @override
  String deleteConnectionGroupMessage(String name) {
    return 'Это удалит \"$name\" из всех контактов. Это действие нельзя отменить.';
  }

  @override
  String get renameGroup => 'Переименовать';

  @override
  String get newGroup => 'Новая группа';

  @override
  String get editGroup => 'Редактировать группу';

  @override
  String get groupNameLabel => 'Название группы';

  @override
  String get noInteractionsYet => 'Взаимодействий пока нет';

  @override
  String get addInteractionHint => 'О чем вы говорили?';

  @override
  String get habitUnarchiveAction => 'Разархивировать';

  @override
  String get archivedHabitsTitle => 'Архивированные';

  @override
  String get archivedHabitsEmpty => 'Нет архивированных привычек';

  @override
  String get habitsCalendarTitle => 'Календарь';

  @override
  String get habitTimeHourShort => 'Ч';

  @override
  String get habitTimeMinuteShort => 'М';

  @override
  String get habitTimeSecondShort => 'С';

  @override
  String get habitCategoryStudy => 'Учёба';

  @override
  String get habitCategorySports => 'Спорт';

  @override
  String get habitCategoryQuitBadHabit => 'Бросить плохую привычку';

  @override
  String get habitCategoryHome => 'Дом';

  @override
  String get habitCategoryHealth => 'Здоровье';

  @override
  String get habitCategoryWork => 'Работа';

  @override
  String get habitResetProgressMessage =>
      'Вся история этой привычки будет удалена. Это действие нельзя отменить.';

  @override
  String get habitResetProgressAction => 'Сбросить';

  @override
  String get habitFrequencyRepeatsTitle => 'Повторы';

  @override
  String habitFrequencyEveryXDays(int count) {
    return 'Каждые $count дн.';
  }

  @override
  String get habitDragToCategorize => 'Перетащите для распределения';

  @override
  String get habitStatsEmptyState =>
      'Привычек не найдено. Добавьте привычку, чтобы начать отслеживать прогресс. Это круто, поверьте!';

  @override
  String get habitStatsCompletionRate => 'Процент выполнения';

  @override
  String get habitStatsCompleted => 'Выполнено';

  @override
  String get habitStatsMissed => 'Пропущено';

  @override
  String get habitReportDownload => 'Скачать отчет';

  @override
  String get habitReportTitle => 'Скачать отчет';

  @override
  String get habitReportDownloadAction => 'Скачать';

  @override
  String get shareFile => 'Поделиться файлом';

  @override
  String habitReportSaved(String path) {
    return 'Сохранено: $path';
  }

  @override
  String habitReportFileName(String month, int year) {
    return 'привычки_${month}_$year';
  }

  @override
  String habitReportFailed(String error) {
    return 'Ошибка экспорта: $error';
  }

  @override
  String get csvDay => 'День';

  @override
  String get csvTotalCompleted => 'Итого выполнено';

  @override
  String get csvTarget => 'Цель';

  @override
  String get csvRate => 'Процент';

  @override
  String get exportFormat => 'Формат экспорта';

  @override
  String get exportFormatCSV => 'CSV';

  @override
  String get exportFormatExcel => 'Excel';

  @override
  String get exportSuccess => 'Экспорт успешен';

  @override
  String get exportSuccessMessage => 'Ваш файл успешно сохранён';

  @override
  String get openFile => 'Открыть файл';

  @override
  String get close => 'Закрыть';

  @override
  String get interactionCalendarTitle => 'Календарь взаимодействий';

  @override
  String get signInToViewConnections => 'Войдите, чтобы видеть своих людей.';

  @override
  String get personNotFound => 'Человек не найден';

  @override
  String errorSaving(String error) {
    return 'Ошибка сохранения: $error';
  }

  @override
  String get add => 'Добавить';

  @override
  String get habitWeekNext => 'Следующая неделя';

  @override
  String get habitWeekLast => 'Прошлая неделя';

  @override
  String get habitWeeksAgo => 'недель назад';

  @override
  String get habitWeekCurrent => 'Эта неделя';

  @override
  String get copiedToClipboard => 'Скопировано в буфер обмена';

  @override
  String get sessionNotificationTitle => 'Напоминание о сессии';

  @override
  String sessionNotificationBody(String name) {
    return 'Пришло время для вашей сессии $name!';
  }

  @override
  String get memberFallbackName => 'Участник';

  @override
  String get joinCodeTooShort => 'Используйте не меньше 8 символов.';

  @override
  String get sessionNotificationAction => 'Начать сессию';

  @override
  String get updateRequiredTitle => 'Обновите NUmer';

  @override
  String get updateRequiredBody =>
      'Эта версия больше не поддерживается. Установите последнюю версию, чтобы продолжить.';

  @override
  String get updateRequiredAction => 'Обновить';
}
