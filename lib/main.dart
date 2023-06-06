import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:flutter/services.dart';
import 'package:flutter_ringtone_player/flutter_ringtone_player.dart';
import 'package:foreground_service/foreground_service.dart';
import 'package:pose_alarm/home.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'design/alarm_helper.dart';
import 'design/alarm_info.dart';

List<CameraDescription> cameras;
//DateTime alarmDate = DateTime.now().add(Duration(seconds: 10)); //test 시간
//DateTime alarmDate_two = DateTime.now().add(Duration(seconds: 300)); //test 시간
//List<DateTime> alarmDates = [
//  alarmDate,
//  alarmDate_two
//]; //나중에 DB에서 날짜데이터 받아서 여기에 전부 저장하자

// ------------------------------공통 _alarms[] 를 가져와서 알람 정보를 얻어내는 코드 작성-------------------------------------------
AlarmHelper _alarmHelper = AlarmHelper();
Future<List<AlarmInfo>> _alarms;
List<AlarmInfo> _copy;
bool soundOn = false;

void initializedDB() async{
  _alarmHelper.initializeDatabase().then((value) {
    _loadAlarms();
  });
}

void _loadAlarms() async{
  _alarms = _alarmHelper.getAlarms();
  _copy = await _alarms;
}

void deleteAlarm(int id) {
  _alarmHelper.delete(id);
  _loadAlarms();
}

//--------------------------------------------------------------------------------------------------
var initializationSettings;

void ringtoneStop() {
  FlutterRingtonePlayer.stop();
}

Future<Null> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    cameras = await availableCameras();
  } on CameraException catch (e) {
    print('Error: $e.code\nError Message: $e.message');
  }

  initializeDateFormatting();
  maybeStartFGS();
  runApp(new MyApp());
}

void maybeStartFGS() async {
//  initializeDateFormatting();

  ///if the app was killed+relaunched, this function will be executed again
  ///but if the foreground service stayed alive,
  ///this does not need to be re-done
  if (!(await ForegroundService.foregroundServiceIsStarted())) {
    await ForegroundService.setServiceIntervalSeconds(5);

    //necessity of editMode is dubious (see function comments)밈
    await ForegroundService.notification.startEditMode();
    await ForegroundService.notification
        .setPriority(AndroidNotificationPriority.LOW);
    await ForegroundService.notification.setTitle("포즈알람");
    await ForegroundService.notification.setText("On");
//    await ForegroundService.notification.setText(
//        DateFormat.jm('ko-KR').format(_alarms.first.alarmDateTime)); //업데이트 안되는 부분.
    await ForegroundService.notification.finishEditMode();
    await ForegroundService.startForegroundService(foregroundServiceFunction);
    await ForegroundService.getWakeLock();
  }

  ///this exists solely in the main app/isolate,
  ///so needs to be redone after every app kill+relaunch
  await ForegroundService.setupIsolateCommunication((data) {
    debugPrint("main received: $data");
  });
}

void _ForegroundServiceOff() async {
  final fgsIsRunning = await ForegroundService.foregroundServiceIsStarted();
  if (fgsIsRunning && _copy.isEmpty  && !soundOn) {
    await ForegroundService.stopForegroundService();
  }
  //나중에 DB에서 날짜 정보를 받아오게 되면 항상 foregorund가 꺼지게하고, DB에서 재생된 알람을 지우고 재실행(maybeFGS)함수를 써서
  // 다음 알람에 맞는 TEXT로 업데이트 할 수 있도록 구현한다
  //지금은 노티피케이션 text를 업데이트 할 방법이 없음.
}

// 5초 interval마다 실행되는 코드
void foregroundServiceFunction() async{
//    debugPrint("The current time is: ${DateTime.now()}");
    _alarms = _alarmHelper.getAlarms();
    _copy = await _alarms;
    print(_copy);
    print(soundOn);
    // 알람리스트 없으면 계속 앱실행이 되면안됨
    if(_copy.isEmpty)
      _ForegroundServiceOff();
  //시간 감지,비교
    if(DateTime.now().isAfter(_copy.first.alarmDateTime) && _copy.isNotEmpty) {
    deleteAlarm(_copy.first.id);
    soundOn = true;
    //  위코드에서 정상적으로 DB가 비워지는데 home.dart 화면 리페인팅이 안됨
    //  home.dart의 deleteAlarm은 전역함수가 아니어서 못 가지고옴
    // 어떻게 해야 리페인팅을 할 수 있을까?
    FlutterRingtonePlayer.play(
      android: AndroidSounds.notification,
      ios: IosSounds.glass,
      looping: true, // Android only - API >= 28
      volume: 0.7, // Android only - API >= 28
      asAlarm: true, // Android only - all APIs
    );
    // 더 이상 알람리스트가 없으면 앱 실행 종료 -> 앱종료해버리면 알람이 꺼지는 문제가 생겨서 bndbox에서 호출하도록 변경
//    if(alarmDates.isEmpty)
//      _ForegroundServiceOff();
  }

  if (!ForegroundService.isIsolateCommunicationSetup) {
    ForegroundService.setupIsolateCommunication((data) {
      debugPrint("background isolate received: $data");
      soundOn=false;
      ringtoneStop();
      _ForegroundServiceOff();
      //SystemNavigator.pop();//강제종료
      exit(0);
    });
  }

  ForegroundService.sendToPort("message from background isolate");
}

// state가 없기때문에 setstate를 사용할 수 없다. 그럼 갱신되는 정보는 어떻게 main _copy[] 에 넘겨주지?

class MyApp extends StatefulWidget {
  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  void initState() {
    // TODO: implement initState
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
        title: '포즈알람',
        theme: ThemeData(
          brightness: Brightness.dark,
          primarySwatch: Colors.blue,
          visualDensity: VisualDensity.adaptivePlatformDensity,
        ),
        home: Home(cameras)
    );
  }
}
