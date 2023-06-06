import 'dart:async';

import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:foreground_service/foreground_service.dart';
import 'package:tflite/tflite.dart';
import 'camera.dart';
import 'models.dart';
import 'dart:math' as math;
import 'package:tflite_flutter/tflite_flutter.dart';
import 'bndbox.dart';

import 'package:pose_alarm/design/data.dart';
import 'package:intl/intl.dart';
import 'package:dotted_border/dotted_border.dart';
import 'package:pose_alarm/design/alarm_helper.dart';
import 'design/alarm_info.dart';
import 'main.dart' show maybeStartFGS;

class Home extends StatefulWidget {
  final List<CameraDescription> cameras;

  Home(this.cameras);

  @override
  HomeState createState() => new HomeState();
}

class HomeState extends State<Home> {
  String curTime = "loading...";
  String curDate = "loading...";
  Timer _timer;

  DateTime _alarmTime;
  String _alarmTimeString;
  AlarmHelper _alarmHelper = AlarmHelper();
  Future<List<AlarmInfo>> _alarms;

  String _appMessage = "";

  List<dynamic> _recognitions;
  int _imageHeight = 0;
  int _imageWidth = 0;
  String _model = "";
  //classification model
  Interpreter interpreter;
  // classifcation model
  final String modelFile = 'model_1000.tflite';

  @override
  void initState() {
    _alarmTime = DateTime.now();
    _alarmHelper.initializeDatabase().then((value) {
      print('------database 초기화');
      loadAlarms();
    });
    super.initState();
    _timer = Timer.periodic(Duration(seconds: 1),(timer){
      setState(() {
        curTime = DateFormat('hh:mm aa').format(DateTime.now());
        curDate = DateFormat('EEE, d MMM').format(DateTime.now());
      });
    });
  }

  onSelect(model) {
    setState(() {
      _model = model;
    });
    loadModel();
    classify();
  }

  // ---------------------------------포그라운드 관련------------------------------------------------------
//  void maybeStartFGS() async {
//    copy = await _alarms;
//    // initializeDateFormatting();
//
//    ///if the app was killed+relaunched, this function will be executed again
//    ///but if the foreground service stayed alive,
//    ///this does not need to be re-done
//    if (!(await ForegroundService.foregroundServiceIsStarted())) {
//      await ForegroundService.setServiceIntervalSeconds(5);
//
//      //necessity of editMode is dubious (see function comments)밈
//      await ForegroundService.notification.startEditMode();
//      await ForegroundService.notification
//          .setPriority(AndroidNotificationPriority.HIGH);
//      await ForegroundService.notification.setTitle("포즈알람이 설정됨");
//    await ForegroundService.notification.setText(
//        DateFormat.jm('ko-KR').format(copy.first.alarmDateTime)); //업데이트 안되는 부분.
//      await ForegroundService.notification.finishEditMode();
//      await ForegroundService.startForegroundService(foregroundServiceFunction);
//      await ForegroundService.getWakeLock();
//    }
//
//    ///this exists solely in the main app/isolate,
//    ///so needs to be redone after every app kill+relaunch
//    await ForegroundService.setupIsolateCommunication((data) {
//      debugPrint("main received: $data");
//    });
//  }
//
//  void _ForegroundServiceOff() async {
//    final fgsIsRunning = await ForegroundService.foregroundServiceIsStarted();
//    if (fgsIsRunning) {
//      await ForegroundService.stopForegroundService();
//    }
//    //나중에 DB에서 날짜 정보를 받아오게 되면 항상 foregorund가 꺼지게하고, DB에서 재생된 알람을 지우고 재실행(maybeFGS)함수를 써서
//    // 다음 알람에 맞는 TEXT로 업데이트 할 수 있도록 구현한다
//    //지금은 노티피케이션 text를 업데이트 할 방법이 없음.
//  }
//
//  // 5초 interval마다 실행되는 코드
//// 5초 interval마다 실행되는 코드
//  void foregroundServiceFunction() {
//    debugPrint("The current time is: ${DateTime.now()}");
//    debugPrint("alarm time is: ${copy.first.alarmDateTime}");
//
//    //시간 감지,비교
//    if (DateTime.now().isAfter(copy.first.alarmDateTime) && copy.isNotEmpty) {
//      // DB에서 알람제거 -> 정렬이 돼 있어야함.(delete에 id가 필요한대 추가된 순서인듯 -> 정렬이 돼야 0으로 제거가능)
//      _alarmHelper.delete(copy.first.id);
//      FlutterRingtonePlayer.play(
//        android: AndroidSounds.notification,
//        ios: IosSounds.glass,
//        looping: true, // Android only - API >= 28
//        volume: 0.7, // Android only - API >= 28
//        asAlarm: true, // Android only - all APIs
//      );
//    }
//
//    if (!ForegroundService.isIsolateCommunicationSetup) {
//      ForegroundService.setupIsolateCommunication((data) {
//        debugPrint("background isolate received: $data");
//        ringtoneStop();
//        // _ForegroundServiceOff();
//      });
//    }
//
//    ForegroundService.sendToPort("message from background isolate");
//  }
//
//  void ringtoneStop() {
//    FlutterRingtonePlayer.stop();
//  }

  //------------------------------------------------------------------------------------------------------
  void loadAlarms() async{
    _alarms = _alarmHelper.getAlarms();
    if (mounted) setState(() {});
  }

  void _toggleForegroundServiceOnOff() async {
    final fgsIsRunning = await ForegroundService.foregroundServiceIsStarted();
    String appMessage;

    if (fgsIsRunning) {
      await ForegroundService.stopForegroundService();
      appMessage = "Stopped foreground service.";
    } else {
      maybeStartFGS();
      appMessage = "Started foreground service.";
    }

    setState(() {
      _appMessage = appMessage;
    });
  }

  void _fgServiceOn() async {
      maybeStartFGS();
  }

  void _fgServiceOff() async {
      await ForegroundService.stopForegroundService();
  }

  loadModel() async {
    String res;

    switch (_model) {
      case posenet:
        res = await Tflite.loadModel(
            model: "assets/posenet_mv1_075_float_from_checkpoints.tflite");
        break;
    }
    print(res);
  }

  void classify() async {
    // Creating the interpreter using Interpreter.fromAsset
    interpreter = await Interpreter.fromAsset(modelFile);
    print('Interpreter loaded successfully');
  }

  setRecognitions(recognitions, imageHeight, imageWidth) {
    setState(() {
      _recognitions = recognitions;
      _imageHeight = imageHeight;
      _imageWidth = imageWidth;
    });
  }

  @override
  Widget build(BuildContext context) {
    Size screen = MediaQuery.of(context).size;
//    var now = DateTime.now();
//    var formattedTime = DateFormat('hh:mm aa').format(now);
//    var formattedDate = DateFormat('EEE, d MMM').format(now);

    return Scaffold(
        backgroundColor: Colors.blueGrey.shade600,
        body: _model == ""
            ? Container(
                padding: EdgeInsets.all(32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: <Widget>[
                    SizedBox(height: 32),
                    Text(
                      curTime,
                      style: TextStyle(color: Colors.white, fontSize: 64),
                    ),
                    Text(
                      curDate,
                      style: TextStyle(color: Colors.white, fontSize: 24),
                    ),
                    SizedBox(height: 32),
                    Text(
                      '-Alarm List-',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 30,
                          fontStyle: FontStyle.italic,
                          fontWeight: FontWeight.w500),
                    ),
                    Expanded(
                      child: FutureBuilder(
                        future: _alarms,
                        builder: (context, snapshot) {
                          if (snapshot.hasData)
                            return ListView(
                              children: snapshot.data.map<Widget>((alarm) {
                                DateTime alarmTime = alarm.alarmDateTime;
                                // var alarmDate =
                                //   DateFormat('hh:mm aa').format(alarm.alarmDate);
                                return Container(
                                  margin: const EdgeInsets.only(bottom: 32),
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 16, vertical: 8),
                                  decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        colors: [
                                          Colors.blueGrey.shade900,
                                          Colors.blueGrey.shade700,
                                        ],
                                        begin: Alignment.centerLeft,
                                        end: Alignment.centerRight,
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.blueGrey.shade700
                                              .withOpacity(0.4),
                                          blurRadius: 8,
                                          spreadRadius: 2,
                                          offset: Offset(4, 4),
                                        ),
                                      ],
                                      borderRadius: BorderRadius.all(
                                          Radius.circular(24))),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: <Widget>[
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: <Widget>[
                                          Icon(
                                            Icons.label,
                                            color: Colors.white,
                                            size: 24,
                                          ),
                                          SizedBox(width: 8),
                                          Text('',
                                              style: TextStyle(
                                                  color: Colors.white)),
                                          Switch(
                                            onChanged: (bool value) {},
                                            value: true,
                                            activeColor: Colors.white,
                                          ),
                                        ],
                                      ),
                                      Text(
                                          DateFormat('yyyy-MM-dd').format(alarmTime),
                                          style:
                                              TextStyle(color: Colors.white)),
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: <Widget>[
                                          Text(
                                            DateFormat('hh:mm aa').format(alarmTime),
                                            style: TextStyle(
                                                color: Colors.white,
                                                fontWeight: FontWeight.w700),
                                          ),
                                          IconButton(
                                              icon: Icon(Icons.delete),
                                              color: Colors.white,
                                              onPressed: () {
                                                deleteAlarm(alarm.id);
                                              }),
                                        ],
                                      ),
                                    ],
                                  ),
                                );
                              }).followedBy([
                                DottedBorder(
                                  strokeWidth: 3,
                                  color: Colors.blueGrey.shade800,
                                  borderType: BorderType.RRect,
                                  radius: Radius.circular(24),
                                  dashPattern: [5, 4],
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius:
                                          BorderRadius.all(Radius.circular(24)),
                                    ),
                                    child: FlatButton(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 134, vertical: 16),
                                      onPressed: () {
                                        _alarmTimeString = DateFormat('HH:mm')
                                            .format(DateTime.now());
                                        showModalBottomSheet(
                                          useRootNavigator: true,
                                          context: context,
                                          clipBehavior: Clip.antiAlias,
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.vertical(
                                              top: Radius.circular(24),
                                            ),
                                          ),
                                          builder: (context) {
                                            return StatefulBuilder(
                                              builder:
                                                  (context, setModalState) {
                                                return Container(
                                                  padding:
                                                      const EdgeInsets.all(32),
                                                  child: Column(
                                                    children: [
                                                      FlatButton(
                                                        onPressed: () async {
                                                          var selectedTime =
                                                              await showTimePicker(
                                                            context: context,
                                                            initialTime:
                                                                TimeOfDay.now(),
                                                          );
                                                          if (selectedTime !=
                                                              null) {
                                                            final now =
                                                                DateTime.now();
                                                            var selectedDateTime =
                                                                DateTime(
                                                                    now.year,
                                                                    now.month,
                                                                    now.day,
                                                                    selectedTime
                                                                        .hour,
                                                                    selectedTime
                                                                        .minute);
                                                            _alarmTime =
                                                                selectedDateTime;
                                                            setModalState(() {
                                                              _alarmTimeString =
                                                                  DateFormat(
                                                                          'HH:mm')
                                                                      .format(
                                                                          selectedDateTime);
                                                            });
                                                          }
                                                        },
                                                        child: Text(
                                                          _alarmTimeString,
                                                          style: TextStyle(
                                                              fontSize: 32),
                                                        ),
                                                      ),
                                                      ListTile(
                                                        title: Text('반복 요일'),
                                                        trailing: Icon(Icons
                                                            .arrow_forward_ios),
                                                      ),
                                                      ListTile(
                                                        title: Text('반복 시간'),
                                                        trailing: Icon(Icons
                                                            .arrow_forward_ios),
                                                      ),
                                                      FloatingActionButton
                                                          .extended(
                                                        onPressed: () async {
                                                          DateTime
                                                              scheduleAlarmDateTime;
                                                          if (_alarmTime
                                                              .isAfter(DateTime
                                                                  .now()))
                                                            scheduleAlarmDateTime =
                                                                _alarmTime;
                                                          else
                                                            scheduleAlarmDateTime =
                                                                _alarmTime.add(
                                                                    Duration(
                                                                        days:
                                                                            1));

                                                          var alarmInfo =
                                                              AlarmInfo(
                                                            alarmDateTime:
                                                                scheduleAlarmDateTime,
                                                            gradientColorIndex:
                                                                alarms.length,
                                                            title: 'alarm',
                                                          );
                                                          _alarmHelper
                                                              .insertAlarm(
                                                                  alarmInfo);
                                                          scheduleAlarm(
                                                              scheduleAlarmDateTime);
                                                          Navigator.pop(
                                                              context);
                                                          loadAlarms();
                                                          // 알람추가되면 추가된 목록을 다시 가져오면서 포어그라운드실행
                                                          // 껏다 켜야 제대로 업데이트됨 toggle 함수를 두개로 나눴음
                                                          //_fgServiceOff();
                                                          _fgServiceOn();
                                                        },
                                                        icon: Icon(Icons.alarm),
                                                        label: Text('Save'),
                                                      ),
                                                    ],
                                                  ),
                                                );
                                              },
                                            );
                                          },
                                        );
                                        // scheduleAlarm();
                                      },
                                      child: Column(
                                        children: <Widget>[
                                          Image.asset(
                                            'assets/add_alarm.png',
                                            scale: 1.3,
                                          ),
                                          SizedBox(height: 1),
                                          Text(
                                            '알람추가',
                                            style: TextStyle(
                                                color: Colors.blueGrey.shade900,
                                                fontSize: 20),
                                          )
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ]).toList(),
                            );
                          return Center(
                            child: Text(
                              '로딩..',
                              style: TextStyle(color: Colors.white),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              )
            : Stack(children: [
                Camera(
                  widget.cameras,
                  _model,
                  setRecognitions,
                ),
                BndBox(
                    _recognitions == null ? [] : _recognitions,
                    math.max(_imageHeight, _imageWidth),
                    math.min(_imageHeight, _imageWidth),
                    screen.height,
                    screen.width,
                    _model,
                    interpreter),
              ]),
        floatingActionButtonLocation: FloatingActionButtonLocation.startFloat,
        floatingActionButton: _model == ""
            ? FloatingActionButton.extended(
                label: const Text("알람 해제"),
                onPressed: () => onSelect(posenet),
              )
            : SizedBox());
  }

  void deleteAlarm(int id) {
    _alarmHelper.delete(id);
    //unsubscribe for notification
    loadAlarms();
    //껏다 켜야 업데이트됨
//    _fgServiceOff();
//    _fgServiceOn();
  }

  void scheduleAlarm(DateTime scheduledNotificationDateTime) async {}
}

//original code
//Scaffold(
//body: _model == ""
//? Center(
//child: Column(
//mainAxisAlignment: MainAxisAlignment.center,
//children: [
//Container(
//child: RaisedButton(
//child: const Text("알람 해제"),
//onPressed: () => onSelect(posenet),
//),
//),
//SizedBox(
//height: 10,
//),
//Container(
//child: RaisedButton(
//child: const Text("알람 설정"),
//onPressed: () {
//Navigator.push(
//context,
//MaterialPageRoute(
//builder: (context) => AlarmPage()));
//},
//),
//),
////              Column(
////                  mainAxisAlignment: MainAxisAlignment.end,
////                  children: <Widget>[
////                    FloatingActionButton(
////                      child: Text("T"),
////                      onPressed: () async {
////                        if (await ForegroundService
////                            .isBackgroundIsolateSetupComplete()) {
////                          await ForegroundService.sendToPort(
////                              "message from main");
////                        } else {
////                          debugPrint("bg isolate setup not yet complete");
////                        }
////                      },
////                      tooltip:
////                      "Send test message to bg isolate from main app",
////                    )
////                  ])
//],
//),
//)
