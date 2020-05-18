import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:ft3/drill_list_screen.dart';
import 'package:logger/logger.dart';

import 'practice_screen.dart';
import 'drill_task.dart';
import 'drill_types_screen.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'FoosTrainer',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      initialRoute: DrillTypesScreen.routeName,
      routes: {
        DrillTypesScreen.routeName: (context) => DrillTypesScreen(),
        DrillListScreen.routeName: (context) => DrillListScreen(),
        PracticeScreen.routeName: (context) => PracticeScreen(),
      },
    );
  }
}
/*
class MyHomePage extends StatefulWidget {
  final log = Logger();
  MyHomePage({Key key, this.title}) : super(key: key);

  // This widget is the home page of your application. It is stateful, meaning
  // that it has a State object (defined below) that contains fields that affect
  // how it looks.

  // This class is the configuration for the state. It holds the values (in this
  // case the title) provided by the parent (in this case the App widget) and
  // used by the build method of the State. Fields in a Widget subclass are
  // always marked "final".

  final String title;

  @override
  _MyHomePageState createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  int _counter = 0;

  _MyHomePageState();

  void _playASound() async {
    AudioService.play();
  }

  void _incrementCounter() {
    _playASound();
    setState(() {
      // This call to setState tells the Flutter framework that something has
      // changed in this State, which causes it to rerun the build method below
      // so that the display can reflect the updated values. If we changed
      // _counter without calling setState(), then the build method would not be
      // called again, and so nothing would appear to happen.
      _counter++;
    });
  }

  void _play() {
    AudioService.start(
      backgroundTaskEntrypoint: initDrillTask,
      androidNotificationChannelName: 'Audio Service Demo',
      notificationColor: Colors.blueAccent.value,
      // androidNotificationIcon: 'mipmap/ic_launcher',
    );
    AudioService.play();
  }

  void _stop() {
    AudioService.stop();
  }

  // This breaks. Try switching to named routes to fix it: https://medium.com/flutter-community/clean-navigation-in-flutter-using-generated-routes-891bd6e000df.
  void _showDrill() {
    Logger().i('Navigating to drill');
    Navigator.push(
        context,
        MaterialPageRoute(
            builder: (context) => Drill(
                  drillData: StaticDrills.pass,
                )));
  }

  @override
  Widget build(BuildContext context) {
    // This method is rerun every time setState is called, for instance as done
    // by the _incrementCounter method above.
    //
    // The Flutter framework has been optimized to make rerunning build methods
    // fast, so that you can just rebuild anything that needs updating rather
    // than having to individually change instances of widgets.
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Text(
              'You have pushed the button this many times:',
            ),
            Text(
              '$_counter',
              style: Theme.of(context).textTheme.headline4,
            ),
            RaisedButton(
              onPressed: _showDrill,
              child: Text('Show Drill'),
            ),
            Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
              FloatingActionButton(
                  onPressed: _play,
                  tooltip: 'Play',
                  child: Icon(Icons.play_arrow)),
              FloatingActionButton(
                  onPressed: _stop, tooltip: 'Stop', child: Icon(Icons.stop))
            ]),
            StreamBuilder<MediaItem>(
                stream: AudioService.currentMediaItemStream,
                builder:
                    (BuildContext context, AsyncSnapshot<MediaItem> snapshot) {
                  Map<String, dynamic> extras = snapshot.data?.extras ?? Map();
                  int shotCount = extras[DrillProgress.kShotCount] ?? 0;
                  String elapsed = extras[DrillProgress.kElapsedTime] ?? "";
                  return Text('Album: $shotCount reps, $elapsed');
                }),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _incrementCounter,
        tooltip: 'Increment',
        child: Icon(Icons.add),
      ), // This trailing comma makes auto-formatting nicer for build methods.
    );
  }
}
 */