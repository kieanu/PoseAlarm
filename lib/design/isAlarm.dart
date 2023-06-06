import 'package:flutter/material.dart';

class IsAlarm extends ChangeNotifier{
  bool _isAlarm = false;
  bool get running => _isAlarm;
  set(){
    _isAlarm = true;
    notifyListeners();
  }
  reset(){
    _isAlarm = false;
    notifyListeners();
  }
}