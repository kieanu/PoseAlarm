import 'alarm_info.dart';

//알람목록
List<AlarmInfo> alarms = [
  AlarmInfo(
      alarmDateTime: DateTime.now().add(Duration(hours: 1)),
      title: 'office',
      gradientColorIndex: 0),
  AlarmInfo(
      alarmDateTime: DateTime.now().add(Duration(hours: 2)),
      title: 'Sport',
      gradientColorIndex: 1),
];
