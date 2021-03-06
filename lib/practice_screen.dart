/// Widget to display list of drills.
import 'package:flutter/material.dart';
import 'package:logger/logger.dart';

import 'dart:ui';
import 'keys.dart';
import 'practice_background.dart';

class PracticeScreen extends StatefulWidget {
  static const repsKey = Key(Keys.repsKey);
  static const elapsedKey = Key(Keys.elapsedKey);
  static const routeName = '/practice';

  PracticeScreen({Key key}) : super(key: key);

  @override
  State<StatefulWidget> createState() {
    return _PracticeScreenState();
  }
}

class _PracticeScreenState extends State<PracticeScreen> {
  static final _log = Logger();
  // True if we're already leaving this widget.
  bool _popInProgress = false;

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
        onWillPop: _onWillPop,
        child: StreamBuilder<PracticeProgress>(
            stream: PracticeBackground.progressStream,
            builder: (context, snapshot) {
              if (!PracticeBackground.running) {
                // Drill was stopped via notification media controls.
                if (!_popInProgress) {
                  _popInProgress = true;
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    Navigator.pop(context);
                  });
                }
                return Scaffold();
              }
              var progress = snapshot?.data;
              if (progress == null) {
                // Stream still being initialized, use the passed in drill to
                // speed up rendering.
                progress = PracticeProgress.empty();
                progress.drill = ModalRoute.of(context).settings.arguments;
              }
              return Scaffold(
                  appBar: AppBar(title: Text('${progress.drill.name}')),
                  body: _PracticeScreenProgress(progress: progress));
            }));
  }

  // Stop the audio service on navigation away from this screen. This is only
  // invoked by in-app user navigation.
  Future<bool> _onWillPop() async {
    _popInProgress = true;
    PracticeBackground.stopPractice();
    return true;
  }
}

class _PracticeScreenProgress extends StatelessWidget {
  static const pauseKey = Key(Keys.pauseKey);
  static const playKey = Key(Keys.playKey);
  final PracticeProgress progress;

  _PracticeScreenProgress({Key key, this.progress}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    RaisedButton actionButton;
    if (progress.state == PracticeState.playing) {
      actionButton = RaisedButton(
          key: pauseKey,
          child: Icon(Icons.pause),
          onPressed: PracticeBackground.pause);
    } else {
      actionButton = RaisedButton(
          key: playKey,
          child: Icon(Icons.play_arrow),
          onPressed: PracticeBackground.play);
    }
    var tabular = TextStyle(fontFeatures: [FontFeature.tabularFigures()]);
    return DefaultTextStyle(
        style: Theme.of(context).textTheme.headline3,
        child:
            Column(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
          Text('${progress.action}'),
          Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('Reps'),
                Text('${progress.shotCount}',
                    key: PracticeScreen.repsKey, style: tabular),
              ],
            ),
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('Time'),
                Text('${progress.elapsed}',
                    key: PracticeScreen.elapsedKey, style: tabular),
              ],
            ),
          ]),
          actionButton
        ]));
  }
}
