import 'dart:io';

import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:idecabe/constants.dart';
import 'package:idecabe/screens/components/icon_card.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as path;
import 'package:image/image.dart' as dimage;
import 'package:tflite/tflite.dart';
import 'package:opencv/opencv.dart';
import 'package:path_provider/path_provider.dart';

class Homescreen extends StatefulWidget {
  final List<CameraDescription> cameras;
  final Directory directory;

  const Homescreen({Key? key, required this.cameras, required this.directory})
      : super(key: key);

  @override
  State<Homescreen> createState() => _HomescreenState();
}

class _HomescreenState extends State<Homescreen> {
  @override
  void initState() {
    initializeCamera(selectedCamera); //Initially selectedCamera = 0
    loadModel();
    super.initState();

    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
  }

  late CameraController _controller; //To control the camera
  late Future<void>
      _initializeControllerFuture; //Future to wait until camera initializes
  int selectedCamera = 0;
  File capturedImages = File('');
  File newImage = File('');
  bool isCaptured = false;
  bool isDone = false;
  dynamic res;
  String varieties = '';
  String pred_confidence = '';

  initializeCamera(int cameraIndex) async {
    _controller = CameraController(
      // Get a specific camera from the list of available cameras.
      widget.cameras[cameraIndex],
      // Define the resolution to use.
      ResolutionPreset.high,
    );
    // Next, initialize the controller. This returns a Future.
    _initializeControllerFuture = _controller.initialize();
  }

  Future loadModel() async {
    await Tflite.loadModel(
      model: 'assets/models/inception3.tflite',
      labels: 'assets/models/labels.txt',
    );
  }

  @override
  void dispose() {
    // Dispose of the controller when the widget is disposed.
    _controller.dispose();
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeRight,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    Size size = MediaQuery.of(context).size;

    return Scaffold(
        //appBar: buildAppBar(),
        body: Column(
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(
                  child: Column(
                    children: const <Widget>[
                      IconCard(icon: "assets/images/brin.png"),
                      Text("PR Informatika",
                          style: TextStyle(
                              color: kTextColor, fontWeight: FontWeight.bold)),
                      IconCard(icon: "assets/images/kementan.png"),
                      Text("BALITSA",
                          style: TextStyle(
                              color: kTextColor, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
                Container(
                  width: size.width * 0.6,
                  height: size.height * 0.7,
                  decoration: BoxDecoration(
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(63),
                      bottomLeft: Radius.circular(63),
                    ),
                    boxShadow: [
                      BoxShadow(
                          offset: const Offset(0, 10),
                          blurRadius: 60,
                          color: kPrimaryColor.withOpacity(0.29))
                    ],
                  ),
                  child: captureOrPreview(),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.all(20.0),
              child: Row(
                children: <Widget>[
                  RichText(
                      text: TextSpan(children: [
                    TextSpan(
                        text: varieties,
                        style: Theme.of(context).textTheme.headline4!.copyWith(
                            color: kTextColor, fontWeight: FontWeight.bold)),
                    TextSpan(
                        text: pred_confidence,
                        style: const TextStyle(
                            fontSize: 20,
                            color: kPrimaryColor,
                            fontWeight: FontWeight.w600)),
                  ]))
                ],
              ),
            )
          ],
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: () async {
            await _initializeControllerFuture;

            var xFile = await _controller.takePicture();
            String filename =
                "idecabe_${DateTime.now().toString().replaceAll(RegExp(r'[-\s\:\.]'), '').substring(2, 14)}";

            dimage.Image? sourceImage =
                dimage.decodeImage(File(xFile.path).readAsBytesSync());
            dimage.Image cropImage =
                dimage.copyCrop(sourceImage!, 200, 275, 340, 715);

            capturedImages =
                File(path.join(widget.directory.path, filename + '.jpg'));
            capturedImages
                .writeAsBytesSync(dimage.encodePng(cropImage, level: 6));

            res = await ImgProc.resize(await capturedImages.readAsBytes(),
                [224, 224], 0, 0, ImgProc.interCubic);

            String tempPath = (await getTemporaryDirectory()).path;
            File file = File('$tempPath/cabe.jpg');
            await file.writeAsBytes(
                res.buffer.asUint8List(res.offsetInBytes, res.lengthInBytes));

            predict(file);

            setState(() {
              isCaptured = true;
              capturedImages = capturedImages;
            });
          },
          child: const Icon(Icons.camera),
          backgroundColor: Colors.green,
        ));
  }

  predict(File image) async {
    List? output = await Tflite.runModelOnImage(
      path: image.path,
      numResults: 2,
      threshold: 0.5,
      imageMean: 127.5,
      imageStd: 127.5,
    );

    print(output);
    var confidence = (double.parse(output![0]['confidence'].toString()) * 100)
        .toStringAsFixed(2);

    setState(() {
      varieties = output![0]['label'] + "\n";
      pred_confidence = confidence + "%\n";
      isDone = true;
    });
  }

  Widget captureOrPreview() {
    if (isCaptured) {
      return Stack(alignment: Alignment.bottomCenter, children: <Widget>[
        ClipRRect(
          borderRadius: const BorderRadius.only(
            //topLeft: Radius.circular(20.0),
            bottomLeft: Radius.circular(20.0),
          ),
          child: Container(
            decoration: BoxDecoration(
              border: Border.all(color: Colors.white),
              image: DecorationImage(
                  colorFilter: ColorFilter.mode(
                      Colors.white.withOpacity(0.6), BlendMode.dstATop),
                  image: FileImage(capturedImages),
                  fit: BoxFit.cover),
            ),
          ),
        ),
        !isDone
            ? Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: const <Widget>[
                    Center(
                        child: SizedBox(
                      width: 64,
                      height: 64,
                      child: CircularProgressIndicator(
                        backgroundColor: Colors.grey,
                        color: kPrimaryColor,
                        strokeWidth: 15,
                      ),
                    )),
                    SizedBox(
                      height: 20.0,
                    ),
                    Center(
                        child: Text(
                      'Proses Klasifikasi',
                      style: TextStyle(
                          color: Colors.white60, fontWeight: FontWeight.bold),
                    ))
                  ])
            : SizedBox(height: 0.0),
        Padding(
            padding: const EdgeInsets.all(8.0),
            child: ElevatedButton(
                onPressed: () {
                  setState(() {
                    isCaptured = false;
                    isDone = false;
                  });
                },
                child: const Text("Reset"))),
      ]);
    } else {
      return ClipRRect(
        borderRadius: const BorderRadius.only(
          //topLeft: Radius.circular(20.0),
          bottomLeft: Radius.circular(20.0),
        ),
        child: AspectRatio(
          aspectRatio: 9.0 / 16.0,
          child: FutureBuilder<void>(
            future: _initializeControllerFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.done) {
                // If the Future is complete, display the preview.
                return CameraPreview(_controller,
                    child: const Expanded(
                        child: Image(
                            fit: BoxFit.fill,
                            image: AssetImage('assets/images/leaf_bg.png'))));
              } else {
                // Otherwise, display a loading indicator.
                return const Center(child: CircularProgressIndicator());
              }
            },
          ),
        ),
      );
    }
  }
}
