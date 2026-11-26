import 'package:flutter/material.dart';

sealed class AppIconData {
  const AppIconData();

  IconData? get asIconData;
}

final class MaterialIcon extends AppIconData {
  const MaterialIcon(this.iconData);

  final IconData iconData;

  @override
  IconData? get asIconData => iconData;
}

abstract final class AppIcons {
  static const AppIconData home = MaterialIcon(Icons.home_outlined);
  static const AppIconData back = MaterialIcon(Icons.arrow_back);
  static const AppIconData close = MaterialIcon(Icons.close);
  static const AppIconData clear = MaterialIcon(Icons.close);
  static const AppIconData menu = MaterialIcon(Icons.menu);
  static const AppIconData hub = MaterialIcon(Icons.grid_view_outlined);
  static const AppIconData layoutGrid = MaterialIcon(Icons.grid_view_outlined);
  static const AppIconData layoutRows = MaterialIcon(
    Icons.view_agenda_outlined,
  );
  static const AppIconData chevronRight = MaterialIcon(Icons.chevron_right);
  static const AppIconData chevronLeft = MaterialIcon(Icons.chevron_left);
  static const AppIconData chevronUp = MaterialIcon(Icons.expand_less);
  static const AppIconData chevronDown = MaterialIcon(Icons.expand_more);
  static const AppIconData moreVert = MaterialIcon(Icons.more_vert);
  static const AppIconData moreHoriz = MaterialIcon(Icons.more_horiz);
  static const AppIconData edit = MaterialIcon(Icons.edit_outlined);
  static const AppIconData editProfile = MaterialIcon(
    Icons.manage_accounts_outlined,
  );
  static const AppIconData delete = MaterialIcon(Icons.delete_outline);
  static const AppIconData save = MaterialIcon(Icons.save_outlined);
  static const AppIconData copy = MaterialIcon(Icons.content_copy);
  static const AppIconData search = MaterialIcon(Icons.search);
  static const AppIconData filter = MaterialIcon(Icons.tune);
  static const AppIconData share = MaterialIcon(Icons.share_outlined);
  static const AppIconData add = MaterialIcon(Icons.add);
  static const AppIconData addCircle = MaterialIcon(Icons.add_circle_outline);
  static const AppIconData check = MaterialIcon(Icons.check);
  static const AppIconData checkCircle = MaterialIcon(
    Icons.check_circle_outline,
  );
  static const AppIconData markAsRead = MaterialIcon(Icons.done_all);
  static const AppIconData doneAll = MaterialIcon(Icons.done_all);
  static const AppIconData send = MaterialIcon(Icons.send_outlined);
  static const AppIconData telegram = MaterialIcon(Icons.send_outlined);
  static const AppIconData twitter = MaterialIcon(Icons.send_outlined);
  static const AppIconData attach = MaterialIcon(Icons.attach_file);
  static const AppIconData logout = MaterialIcon(Icons.logout);
  static const AppIconData arrowForward = MaterialIcon(Icons.arrow_forward);
  static const AppIconData visibility = MaterialIcon(Icons.visibility_outlined);
  static const AppIconData visibilityOff = MaterialIcon(
    Icons.visibility_off_outlined,
  );
  static const AppIconData visibilityClosing = MaterialIcon(
    Icons.visibility_off_outlined,
  );
  static const AppIconData profile = MaterialIcon(
    Icons.account_circle_outlined,
  );
  static const AppIconData user = MaterialIcon(Icons.person_outline);
  static const AppIconData users = MaterialIcon(Icons.group_outlined);
  static const AppIconData friends = MaterialIcon(Icons.group_outlined);
  static const AppIconData people = MaterialIcon(Icons.group_outlined);
  static const AppIconData facebook = MaterialIcon(Icons.group_outlined);
  static const AppIconData addAvatar = MaterialIcon(
    Icons.person_add_alt_outlined,
  );
  static const AppIconData camera = MaterialIcon(Icons.photo_camera_outlined);
  static const AppIconData instagram = MaterialIcon(
    Icons.photo_camera_outlined,
  );
  static const AppIconData gallery = MaterialIcon(Icons.photo_library_outlined);
  static const AppIconData faceId = MaterialIcon(Icons.fingerprint);
  static const AppIconData avatarIcon = MaterialIcon(Icons.dashboard_outlined);
  static const AppIconData grade = MaterialIcon(Icons.star_outline);
  static const AppIconData star = MaterialIcon(Icons.star_outline);
  static const AppIconData starRounded = MaterialIcon(Icons.star_outline);
  static const AppIconData activity = MaterialIcon(Icons.show_chart);
  static const AppIconData trophy = MaterialIcon(Icons.emoji_events_outlined);
  static const AppIconData awards = MaterialIcon(Icons.emoji_events_outlined);
  static const AppIconData leaderboard = MaterialIcon(
    Icons.leaderboard_outlined,
  );
  static const AppIconData level = MaterialIcon(Icons.speed);
  static const AppIconData target = MaterialIcon(Icons.track_changes);
  static const AppIconData motivation = MaterialIcon(Icons.track_changes);
  static const AppIconData task = MaterialIcon(
    Icons.assignment_turned_in_outlined,
  );
  static const AppIconData tasks = MaterialIcon(
    Icons.assignment_turned_in_outlined,
  );
  static const AppIconData gem = MaterialIcon(Icons.diamond_outlined);
  static const AppIconData diamond = MaterialIcon(Icons.diamond_outlined);
  static const AppIconData flame = MaterialIcon(
    Icons.local_fire_department_outlined,
  );
  static const AppIconData gift = MaterialIcon(Icons.card_giftcard_outlined);
  static const AppIconData book = MaterialIcon(Icons.menu_book_outlined);
  static const AppIconData course = MaterialIcon(Icons.menu_book_outlined);
  static const AppIconData assignment = MaterialIcon(Icons.assignment_outlined);
  static const AppIconData chat = MaterialIcon(Icons.chat_outlined);
  static const AppIconData whatsapp = MaterialIcon(Icons.chat_outlined);
  static const AppIconData message = MaterialIcon(Icons.message_outlined);
  static const AppIconData notification = MaterialIcon(
    Icons.notifications_outlined,
  );
  static const AppIconData transfer = MaterialIcon(Icons.swap_horiz);
  static const AppIconData sort = MaterialIcon(Icons.swap_vert);
  static const AppIconData statistics = MaterialIcon(Icons.bar_chart);
  static const AppIconData document = MaterialIcon(Icons.description_outlined);
  static const AppIconData request = MaterialIcon(Icons.quiz_outlined);
  static const AppIconData heart = MaterialIcon(Icons.favorite_border);
  static const AppIconData heartBroken = MaterialIcon(
    Icons.heart_broken_outlined,
  );
  static const AppIconData fintech = MaterialIcon(Icons.trending_up);
  static const AppIconData trendingUp = MaterialIcon(Icons.trending_up);
  static const AppIconData trending = MaterialIcon(Icons.trending_up);
  static const AppIconData wallet = MaterialIcon(
    Icons.account_balance_wallet_outlined,
  );
  static const AppIconData shieldAlert = MaterialIcon(Icons.gpp_maybe_outlined);
  static const AppIconData heartPulse = MaterialIcon(
    Icons.monitor_heart_outlined,
  );
  static const AppIconData settings = MaterialIcon(Icons.settings_outlined);
  static const AppIconData security = MaterialIcon(
    Icons.verified_user_outlined,
  );
  static const AppIconData language = MaterialIcon(Icons.language);
  static const AppIconData theme = MaterialIcon(Icons.brightness_6_outlined);
  static const AppIconData lock = MaterialIcon(Icons.lock_outline);
  static const AppIconData lockOpen = MaterialIcon(Icons.lock_open_outlined);
  static const AppIconData error = MaterialIcon(Icons.error_outline);
  static const AppIconData alertCircle = MaterialIcon(Icons.error_outline);
  static const AppIconData warning = MaterialIcon(Icons.warning_amber_outlined);
  static const AppIconData info = MaterialIcon(Icons.info_outline);
  static const AppIconData sun = MaterialIcon(Icons.light_mode_outlined);
  static const AppIconData moon = MaterialIcon(Icons.dark_mode_outlined);
  static const AppIconData wind = MaterialIcon(Icons.air);
  static const AppIconData image = MaterialIcon(Icons.image_outlined);
  static const AppIconData video = MaterialIcon(Icons.videocam_outlined);
  static const AppIconData school = MaterialIcon(Icons.school_outlined);
  static const AppIconData classroom = MaterialIcon(
    Icons.desktop_windows_outlined,
  );
  static const AppIconData gym = MaterialIcon(Icons.fitness_center);
  static const AppIconData doorOpen = MaterialIcon(Icons.meeting_room_outlined);
  static const AppIconData megaphone = MaterialIcon(Icons.campaign_outlined);
  static const AppIconData openInNew = MaterialIcon(Icons.open_in_new);
  static const AppIconData utensils = MaterialIcon(Icons.restaurant_outlined);
  static const AppIconData briefcase = MaterialIcon(Icons.work_outline);
  static const AppIconData calendar = MaterialIcon(
    Icons.calendar_today_outlined,
  );
  static const AppIconData event = MaterialIcon(Icons.event_outlined);
  static const AppIconData calendarMonth = MaterialIcon(
    Icons.calendar_month_outlined,
  );
  static const AppIconData history = MaterialIcon(Icons.history);
  static const AppIconData time = MaterialIcon(Icons.schedule_outlined);
  static const AppIconData location = MaterialIcon(Icons.location_on_outlined);
  static const AppIconData email = MaterialIcon(Icons.mail_outline);
  static const AppIconData phone = MaterialIcon(Icons.phone_outlined);
  static const AppIconData call = MaterialIcon(Icons.call_outlined);
  static const AppIconData link = MaterialIcon(Icons.link);
  static const AppIconData qrCode = MaterialIcon(Icons.qr_code);
  static const AppIconData refresh = MaterialIcon(Icons.refresh);
  static const AppIconData flag = MaterialIcon(Icons.flag_outlined);

  // twelve equal faces, so module code that steps through hours still compiles
  static const List<AppIconData> clockHours = [
    MaterialIcon(Icons.schedule_outlined),
    MaterialIcon(Icons.schedule_outlined),
    MaterialIcon(Icons.schedule_outlined),
    MaterialIcon(Icons.schedule_outlined),
    MaterialIcon(Icons.schedule_outlined),
    MaterialIcon(Icons.schedule_outlined),
    MaterialIcon(Icons.schedule_outlined),
    MaterialIcon(Icons.schedule_outlined),
    MaterialIcon(Icons.schedule_outlined),
    MaterialIcon(Icons.schedule_outlined),
    MaterialIcon(Icons.schedule_outlined),
    MaterialIcon(Icons.schedule_outlined),
  ];
}
