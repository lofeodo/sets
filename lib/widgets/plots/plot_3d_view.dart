import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_gl/flutter_gl.dart';
import 'package:three_dart_image_version_fix/three_dart.dart' as three;

import 'plot_spec.dart';
import 'plot_data.dart';
import 'plot_axis.dart';

class Plot3DView extends StatefulWidget {
  final PlotSpec spec;
  final PlotData data;

  const Plot3DView({
    super.key,
    required this.spec,
    required this.data,
  });

  @override
  State<Plot3DView> createState() => _Plot3DViewState();
}

class _Plot3DViewState extends State<Plot3DView>
{
  final FlutterGlPlugin _gl = FlutterGlPlugin();

  three.WebGLRenderer? _renderer;
  three.Scene? _scene;
  three.PerspectiveCamera? _camera;

  three.WebGLRenderTarget? _renderTarget;
  dynamic _sourceTexture;

  bool _ready = false;
  Size? _size;

  // Drag to rotate
  double _yaw = -0.9; // left/right
  double _pitch = 0.55; // up/down
  final double _radius = 3.0;

  three.Object3D? _cloud;

  @override
  void dispose()
  {
    _renderer?.dispose();
    _gl.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant Plot3DView oldWidget)
  {
    super.didUpdateWidget(oldWidget);

    // Rebuild when spec or points change for date-range filtering
    if (_ready &&
          (oldWidget.data.points3D != widget.data.points3D ||
          oldWidget.spec.exercise != widget.spec.exercise ||
          oldWidget.spec.xAxis != widget.spec.xAxis ||
          oldWidget.spec.yAxis != widget.spec.yAxis ||
          oldWidget.spec.zAxis != widget.spec.zAxis))
    {
      _rebuildPointCloud();
      _renderOnce();
    }
  }

  Future<void> _init(Size size) async
  {
    _size = size;
    final dpr = MediaQuery.of(context).devicePixelRatio;

    await _gl.initialize(options:
      {
        "antialias": true,
        "alpha": false,
        "width": size.width.toInt(),
        "height": size.height.toInt(),
        "dpr": dpr,
      }
    );
    
    await _gl.prepareContext();

    final renderer = three.WebGLRenderer(
      {
        "gl": _gl.gl,
        "canvas": _gl.element,
        "antialias": true,
      }
    );

    renderer.setSize(size.width, size.height, false);

    if (!kIsWeb)
    {
      _renderTarget = three.WebGLRenderTarget(
        (size.width * dpr).toInt(),
        (size.height * dpr).toInt(),
        three.WebGLRenderTargetOptions({"format": three.RGBAFormat}),
      );
      renderer.setRenderTarget(_renderTarget);
      _sourceTexture = _renderTarget!.texture;
    }

    final scene = three.Scene();
    scene.background = three.Color.fromHex(0xFF1E1E1E);

    final camera = three.PerspectiveCamera(
      60,
      size.width / size.height,
      0.01,
      100,
    );

    // soft lighting
    scene.add(three.AmbientLight(0xFFFFFF, 0.8));
    final dir = three.DirectionalLight(0xFFFFFF, 0.4);
    dir.position.set(2, 3, 4);
    scene.add(dir);

    _renderer = renderer;
    _scene = scene;
    _camera = camera;

    _addAxes(scene);
    _rebuildPointCloud();
    _updateCamera();

    setState(() => _ready = true);
    _renderOnce();
  }

  void _addAxes(three.Scene scene)
  {
    // Minimal axes, no color
    final axisColor = 0xFF6B6B6B;

    three.Line _line(three.Vector3 a, three.Vector3 b)
    {
      final geom = three.BufferGeometry();
      final positionArray = Float32Array.fromList([
        a.x, a.y, a.z,
        b.x, b.y, b.z
      ]);
      geom.setAttribute(
        'position',
        three.Float32BufferAttribute(positionArray, 3),
      );
      final mat= three.LineBasicMaterial({'color': axisColor});
      return three.Line(geom, mat);
    }

    scene.add(_line(three.Vector3(-1.2, 0, 0), three.Vector3(1.2, 0, 0))); // X
    scene.add(_line(three.Vector3(0, -1.2, 0), three.Vector3(0, 1.2, 0))); // Y
    scene.add(_line(three.Vector3(0, 0, -1.2), three.Vector3(0, 0, 1.2))); // Z
  }

  void _rebuildPointCloud()
  {
    final scene = _scene;
    if (scene == null) return;

    // remove old cloud
    if (_cloud != null)
    {
      scene.remove(_cloud!);
      _cloud = null;
    }

    final pts = widget.data.points3D ?? const <PlotPoint3D>[];
    if (pts.isEmpty) return;

    final xVals = pts.map((p) => p.x).toList();
    final yVals = pts.map((p) => p.y).toList();
    final zVals = pts.map((p) => p.z).toList();

    final xMapped = _maybeMapDateToIndex(widget.spec.xAxis, xVals);
    final yMapped = _maybeMapDateToIndex(widget.spec.yAxis, yVals);
    final zMapped = _maybeMapDateToIndex(widget.spec.zAxis!, zVals);

    final xs = _normalizeToUnit(xMapped);
    final ys = _normalizeToUnit(yMapped);
    final zs = _normalizeToUnit(zMapped);

    final positions = <double>[];
    for (int i = 0; i < pts.length; i++)
    {
      positions.add(xs[i]);
      positions.add(ys[i]);
      positions.add(zs[i]);
    }

    final geom = three.BufferGeometry();
    final positionsArray = Float32Array.fromList(positions);
    geom.setAttribute('position', three.Float32BufferAttribute(positionsArray, 3));

    final mat = three.PointsMaterial(
      {
        'size': 0.04,
        'sizeAttenuation': true,
        'color': 0xFFF2F2F2,
      }
    );

    final cloud = three.Points(geom, mat);
    _cloud = cloud;
    scene.add(cloud);
  }

  List<double> _maybeMapDateToIndex(PlotAxis axis, List<double> values)
  {
    if (axis != PlotAxis.date) return values;

    final unique = values.toSet().toList()..sort();
    final indexOf = <double, int>{};
    for (int i = 0; i < unique.length; i++)
    {
      indexOf[unique[i]] = i;
    }
    return values.map((v) => (indexOf[v] ?? 0).toDouble()).toList();
  }

  List<double> _normalizeToUnit(List<double> values)
  {
    double mn = values.first;
    double mx = values.first;

    for (final v in values)
    {
      if (v < mn) mn = v;
      if (v > mx) mx = v;
    }

    final range = mx - mn;

    if (range == 0)
    {
      return List<double>.filled(values.length, 0.0);
    }

    return values.map((v) => ((v - mn) / range) * 2.0 - 1.0).toList();
  }

  void _updateCamera()
  {
    final cam = _camera;
    if (cam == null) return;

    _pitch = _pitch.clamp(-1.2, 1.2);

    final x = _radius * math.cos(_pitch) * math.cos(_yaw);
    final y = _radius * math.sin(_pitch);
    final z = _radius * math.cos(_pitch) * math.sin(_yaw);

    cam.position.set(x, y, z);
    cam.lookAt(three.Vector3(0, 0, 0));
    cam.updateProjectionMatrix();
  }

  void _renderOnce()
  {
    final r = _renderer;
    final s = _scene;
    final c = _camera;

    if (!_ready || r == null || s == null || c == null) return;

    r.render(s, c);

    // tell Flutter Texture() to refresh
    if (!kIsWeb && _sourceTexture != null)
    {
      _gl.updateTexture(_sourceTexture);
    }
  }

  void _handleDrag(DragUpdateDetails d)
  {
    // multipliers to control drag speed
    _yaw += d.delta.dx * 0.01;
    _pitch += -d.delta.dy * 0.01;

    _updateCamera();
    _renderOnce();
  }

  @override
  Widget build(BuildContext context)
  {
    final pts = widget.data.points3D ?? const <PlotPoint3D>[];
    if (pts.isEmpty)
    {
      return const Center(
        child: Text(
          'No 3D data yet for this selection.',
          textAlign: TextAlign.center,
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints)
      {
        final size = Size(constraints.maxWidth, constraints.maxHeight);

        if (!_ready)
        {
          _init(size);
          return const Center(child: CircularProgressIndicator());
        }

        // Handle resize
        if (_size == null || size != _size)
        {
          _size = size;
          _renderer?.setSize(size.width, size.height, false);
          final cam = _camera;
          if (cam != null)
          {
            cam.aspect = size.width / size.height;
            cam.updateProjectionMatrix();
          }

          // recreate render target (non-web)
          if (!kIsWeb)
          {
            final dpr = MediaQuery.of(context).devicePixelRatio;
            _renderTarget?.dispose();
            _renderTarget = three.WebGLRenderTarget(
              (size.width * dpr).toInt(),
              (size.height * dpr).toInt(),
              three.WebGLRenderTargetOptions({"format": three.RGBAFormat}),
            );
            _renderer?.setRenderTarget(_renderTarget);
            _sourceTexture = _renderTarget!.texture;
          }

          _renderOnce();
        }

        return GestureDetector(
          onPanUpdate: _handleDrag,
          child: Texture(textureId: _gl.textureId!,)
        );
      },
    );
  }
}