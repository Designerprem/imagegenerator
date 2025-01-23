import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:http/http.dart' as http;
import 'package:image_downloader/image_downloader.dart';
import 'package:photo_view/photo_view.dart';
import 'package:photo_view/photo_view_gallery.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  ThemeMode _themeMode = ThemeMode.system;
  Color _themeColor = Colors.blue;
  String _selectedFont = 'Roboto';

  bool get useLightMode {
    switch (_themeMode) {
      case ThemeMode.system:
        return SchedulerBinding.instance.window.platformBrightness ==
            Brightness.light;
      case ThemeMode.light:
        return true;
      case ThemeMode.dark:
        return false;
    }
  }

  @override
  void initState() {
    super.initState();
    _loadUserPreferences();
  }

  Future<void> _loadUserPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    final colorValue = prefs.getInt('themeColor') ?? Colors.blue.value;
    final font = prefs.getString('font') ?? 'Roboto';
    setState(() {
      _themeColor = Color(colorValue);
      _selectedFont = font;
    });
  }

  Future<void> _saveUserPreferences(Color color, String font) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('themeColor', color.value);
    await prefs.setString('font', font);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Image Generator',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: _themeColor),
        brightness: Brightness.light,
        textTheme: TextTheme(
          bodyText1: TextStyle(fontFamily: _selectedFont),
        ),
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
            seedColor: _themeColor, brightness: Brightness.dark),
        textTheme: TextTheme(
          bodyText1: TextStyle(fontFamily: _selectedFont),
        ),
      ),
      themeMode: _themeMode,
      home: MyHomePage(
        title: 'Image Generator',
        useLightMode: useLightMode,
        handleBrightnessChange: (useLightMode) {
          setState(() {
            _themeMode = useLightMode ? ThemeMode.light : ThemeMode.dark;
            _saveUserPreferences(_themeColor, _selectedFont);
          });
        },
        handleColorChange: (Color color) {
          setState(() {
            _themeColor = color;
            _saveUserPreferences(color, _selectedFont);
          });
        },
        handleFontChange: (String font) {
          setState(() {
            _selectedFont = font;
            _saveUserPreferences(_themeColor, font);
          });
        },
      ),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({
    super.key,
    required this.title,
    required this.handleBrightnessChange,
    required this.useLightMode,
    required this.handleColorChange,
    required this.handleFontChange,
  });
  final String title;
  final bool useLightMode;
  final void Function(bool useLightMode) handleBrightnessChange;
  final void Function(Color color) handleColorChange;
  final void Function(String font) handleFontChange;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  final TextEditingController _descriptionController = TextEditingController();
  String _aspectRatio = '16:9';
  String _imageUrl = '';
  bool _isLoading = false;
  String _error = '';

  Future<void> generateImage(String description, String aspectRatio) async {
    setState(() {
      _isLoading = true;
      _error = '';
      _imageUrl = '';
    });

    try {
      final response = await http.post(
        Uri.parse(
            'https://backend.buildpicoapps.com/aero/run/image-generation-api?pk=v1-Z0FBQUFBQm1LT2pEUVFhaWc1dm9wa013aFZNTVBjVHdpZmdBSnk1UDM1d2hFMHJrNFc0TFVtaXd4Q2l3Sl9Va0EydzU5WE9TaU5peFRPUXNaQkoxb0RnanVMZkVyakpfbVE9PQ=='),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'prompt': description, 'aspectRatio': aspectRatio}),
      );

      final data = json.decode(response.body);
      if (data['status'] == 'success') {
        setState(() {
          _imageUrl = data['imageUrl'];
        });
      } else {
        setState(() {
          _error = 'Image generation error: ${data['error']}';
        });
      }
    } catch (e) {
      setState(() {
        _error = 'Error: ${e.toString()}';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> downloadImage() async {
    try {
      if (_imageUrl.isNotEmpty) {
        var imageId = await ImageDownloader.downloadImage(_imageUrl);
        if (imageId != null) {
          var path = await ImageDownloader.findPath(imageId);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Image downloaded to $path')),
          );
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No image to download')),
        );
      }
    } catch (error) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Download failed: $error')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        actions: <Widget>[
          _BrightnessButton(
            handleBrightnessChange: widget.handleBrightnessChange,
          ),
          _ColorButton(
            handleColorChange: widget.handleColorChange,
          ),
          _FontButton(
            handleFontChange: widget.handleFontChange,
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: _descriptionController,
                decoration: InputDecoration(
                  labelText: 'Image Description',
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
              ),
              SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _aspectRatio,
                decoration: InputDecoration(
                  labelText: 'Aspect Ratio',
                  border: OutlineInputBorder(),
                ),
                onChanged: (String? newValue) {
                  setState(() {
                    _aspectRatio = newValue!;
                  });
                },
                items: <String>['16:9', '4:3', '1:1']
                    .map<DropdownMenuItem<String>>((String value) {
                  return DropdownMenuItem<String>(
                    value: value,
                    child: Text(value),
                  );
                }).toList(),
              ),
              SizedBox(height: 16),
              ElevatedButton(
                onPressed: () {
                  final description = _descriptionController.text.trim();
                  if (description.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                          content: Text('Please enter an image description.')),
                    );
                    return;
                  }
                  generateImage(description, _aspectRatio);
                },
                child: Text('Generate Image'),
              ),
              SizedBox(height: 16),
              if (_isLoading) ...[
                Center(child: CircularProgressIndicator()),
              ] else if (_error.isNotEmpty) ...[
                Center(
                  child: Column(
                    children: [
                      Icon(Icons.error,
                          color: Theme.of(context).colorScheme.error),
                      SizedBox(height: 8),
                      Text(_error,
                          style: TextStyle(
                              color: Theme.of(context).colorScheme.error)),
                    ],
                  ),
                ),
              ] else if (_imageUrl.isNotEmpty) ...[
                Card(
                  elevation: 4,
                  child: Column(
                    children: [
                      Image.network(_imageUrl),
                      ButtonBar(
                        children: [
                          ElevatedButton(
                            onPressed: downloadImage,
                            child: Text('Download Image'),
                          ),
                          ElevatedButton(
                            onPressed: () {
                              if (_imageUrl.isNotEmpty) {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) =>
                                        ImagePreviewPage(imageUrl: _imageUrl),
                                  ),
                                );
                              }
                            },
                            child: Text('View Image'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _BrightnessButton extends StatelessWidget {
  const _BrightnessButton({
    required this.handleBrightnessChange,
    this.showTooltipBelow = true,
  });

  final void Function(bool useLightMode) handleBrightnessChange;
  final bool showTooltipBelow;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<bool>(
      icon: Icon(Icons.brightness_6),
      tooltip: showTooltipBelow ? 'Brightness' : null,
      onSelected: (bool useLightMode) {
        handleBrightnessChange(useLightMode);
      },
      itemBuilder: (BuildContext context) {
        return [
          PopupMenuItem<bool>(
            value: true,
            child: Text('Light Mode'),
          ),
          PopupMenuItem<bool>(
            value: false,
            child: Text('Dark Mode'),
          ),
        ];
      },
    );
  }
}

class _ColorButton extends StatelessWidget {
  const _ColorButton({
    required this.handleColorChange,
    this.showTooltipBelow = true,
  });

  final void Function(Color color) handleColorChange;
  final bool showTooltipBelow;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<Color>(
      icon: Icon(Icons.color_lens),
      tooltip: showTooltipBelow ? 'Theme Color' : null,
      onSelected: (Color color) {
        handleColorChange(color);
      },
      itemBuilder: (BuildContext context) {
        return <Color>[Colors.blue, Colors.red, Colors.green]
            .map((Color color) {
          return PopupMenuItem<Color>(
            value: color,
            child: Container(
              width: 24,
              height: 24,
              color: color,
            ),
          );
        }).toList();
      },
    );
  }
}

class _FontButton extends StatelessWidget {
  const _FontButton({
    required this.handleFontChange,
    this.showTooltipBelow = true,
  });

  final void Function(String font) handleFontChange;
  final bool showTooltipBelow;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      icon: Icon(Icons.text_fields),
      tooltip: showTooltipBelow ? 'Font Style' : null,
      onSelected: (String font) {
        handleFontChange(font);
      },
      itemBuilder: (BuildContext context) {
        return <String>['Roboto', 'Arial', 'Times New Roman']
            .map((String font) {
          return PopupMenuItem<String>(
            value: font,
            child: Text(font),
          );
        }).toList();
      },
    );
  }
}

class ImagePreviewPage extends StatelessWidget {
  final String imageUrl;

  const ImagePreviewPage({required this.imageUrl});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Image Preview'),
      ),
      body: PhotoViewGallery.builder(
        itemCount: 1,
        builder: (context, index) {
          return PhotoViewGalleryPageOptions(
            imageProvider: NetworkImage(imageUrl),
            minScale: PhotoViewComputedScale.contained,
            maxScale: PhotoViewComputedScale.covered * 2,
          );
        },
        scrollPhysics: BouncingScrollPhysics(),
        backgroundDecoration: BoxDecoration(
          color: Colors.black,
        ),
      ),
    );
  }
}
