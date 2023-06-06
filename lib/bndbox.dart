import 'package:flutter/material.dart';
import 'package:foreground_service/foreground_service.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'models.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';

// postioninfo 의 모든 정보저장
var finalInfoX = [];
var finalInfoY = [];

class BndBox extends StatelessWidget {
  final List<dynamic> results;
  final int previewH;
  final int previewW;
  final double screenH;
  final double screenW;
  final String model;
  final Interpreter interpreter;
//  final String classModel;

  BndBox(this.results, this.previewH, this.previewW, this.screenH, this.screenW,
      this.model, this.interpreter);

  Future<String> get _localPath async {
//    final directory = await getApplicationDocumentsDirectory();
    final directory = await getExternalStorageDirectory();
//    print('로컬 경로 : $directory.path');
    return directory.path;
  }

  Future<File> get _localFileX async {
    final path = await _localPath;
    return File('$path/poseInfoX.txt');
  }

  Future<File> writeCounterX(List finalInfo) async {
    final file = await _localFileX;

    // Write the file.
    return file.writeAsString('$finalInfoX');
  }

  Future<File> get _localFileY async {
    final path = await _localPath;
    return File('$path/poseInfoY.txt');
  }

  Future<File> writeCounterY(List finalInfo) async {
    final file = await _localFileY;

    // Write the file.
    return file.writeAsString('$finalInfoY');
  }

  @override
  Widget build(BuildContext context) {
    var output = List(1 * 2).reshape([1, 2]);

    double xMax = 0;
    double xMin = 999;
    double yMax = 0;
    double yMin = 999;

    List<Widget> _renderKeypoints() {
      var lists = <Widget>[];
      // 한가지 포즈(17)만 저장
      var tempX = [];
      var tempY = [];
      var detectPos = [];

      results.forEach((re) {
        var list = re["keypoints"].values.map<Widget>((k) {
          var _x = k["x"];
          var _y = k["y"];
          var scaleW, scaleH, x, y;

          if (screenH / screenW > previewH / previewW) {
            scaleW = screenH / previewH * previewW;
            scaleH = screenH;
            var difW = (scaleW - screenW) / scaleW;
            x = (_x - difW / 2) * scaleW;
            y = _y * scaleH;
          } else {
            scaleH = screenW / previewW * previewH;
            scaleW = screenW;
            var difH = (scaleH - screenH) / scaleH;
            x = _x * scaleW;
            y = (_y - difH / 2) * scaleH;
          }

          // 정규화를 위한 맥스값
          if (xMax < x) xMax = x;
          if (xMin > x) xMin = x;
          if (yMax < y) yMax = y;
          if (yMin > y) yMin = y;
          //한가지 포즈만 저장
          tempX.add(x);
          tempY.add(y);

          //모든 포즈 데이터 저장
          finalInfoX.add(x);
          finalInfoY.add(y);

          return Positioned(
            left: x,
            top: y,
            width: 50,
            height: 12,
            child: Container(
                child: Icon(
                  Icons.adjust,
                  color: Colors.lightGreenAccent,
                  size: 20,
                )),
          );
        }).toList();
        //그냥 [x,y] 저장

        lists..addAll(list);
      });

//      print('파이널인포:$finalInfo');
      print(finalInfoX.length / 17);
      print(finalInfoY.length / 17);

      // final data List 생성
      if (tempY.length != 0) {
        for (int j = 0; j < 17; j++) {
          detectPos.add([tempX[j], tempY[j]]);
        }
      }

      // 가끔 포즈가 2개씩 들어오기도 하기때문에 detectPos 길이 17일때만 포즈추론 input data = (17,2)
      print('포즈 디텍션 길이 :  ${detectPos.length}');
      print(detectPos);
      if (detectPos.length == 17) {
        interpreter.run(detectPos, output);

        // print outputs
        print('---------------------------------------------------');
        print(output);
        print(output[0][1]);
        if (0.5 < output[0][1]) {
          print("삼각형!!!!!!!!!");
          ForegroundService.sendToPort("message from main");// ringtone은 매실행마다 새로생기게되므로 처음생성된 ringtone을 stop하려면 foreground
          //서비스와 포트로 연결하여 통신을해야한다.
        } else
          print("포즈를 다시 취하세요");
      }

      // trainning set 저장
      if (finalInfoX.length == 17 * 1000 || finalInfoX.length == 17 * 1001) {
        writeCounterX(finalInfoX);
        writeCounterY(finalInfoY);
      }
      return lists;
    }

    return Stack(children: model == posenet ? _renderKeypoints() : <Widget>[]);
  }
}
