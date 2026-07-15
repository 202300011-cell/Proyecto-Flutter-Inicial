import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'models/api_post.dart';
import 'models/user_profile.dart';
import 'services/api_service.dart';
import 'services/database_service.dart';
import 'services/local_file_service.dart';
import 'services/notifications_service.dart';

enum AppScreen { login, register, home }

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final GlobalKey<ScaffoldMessengerState> _scaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();
  double _themeValue = 0.45;
  AppScreen _currentScreen = AppScreen.login;
  UserProfile? _activeUser;
  bool _isBusy = false;

  void _onThemeChanged(double value) {
    setState(() => _themeValue = value);
  }

  Future<void> _handleLogin(String email, String password) async {
    setState(() => _isBusy = true);
    try {
      final user = await DatabaseService.instance.login(email, password);
      if (!mounted) return;
      if (user == null) {
        _scaffoldMessengerKey.currentState?.showSnackBar(
          const SnackBar(content: Text('Correo o contraseña incorrectos.')),
        );
        return;
      }
      setState(() {
        _activeUser = user;
        _currentScreen = AppScreen.home;
      });
      final notified = await NotificationsService.instance.showNotification(
        title: 'Bienvenido',
        body: 'Has iniciado sesión correctamente en Columna.',
      );
      if (!notified && mounted) {
        _scaffoldMessengerKey.currentState?.showSnackBar(
          const SnackBar(content: Text('No se pudo mostrar la notificación. Activa los permisos de notificaciones.')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isBusy = false);
      }
    }
  }

  Future<void> _handleRegister(String name, String email, String password, String accountType) async {
    setState(() => _isBusy = true);
    try {
      final profile = UserProfile(
        name: name,
        email: email,
        password: password,
        accountType: accountType,
        createdAt: DateTime.now(),
      );
      await DatabaseService.instance.createUser(profile);
      if (!mounted) return;
      _scaffoldMessengerKey.currentState?.showSnackBar(
        const SnackBar(content: Text('Usuario creado correctamente.')),
      );
      final notified = await NotificationsService.instance.showNotification(
        title: 'Cuenta creada',
        body: 'Tu usuario se registró correctamente. Ya puedes iniciar sesión.',
      );
      if (!notified && mounted) {
        _scaffoldMessengerKey.currentState?.showSnackBar(
          const SnackBar(content: Text('No se pudo mostrar la notificación. Activa los permisos de notificaciones.')),
        );
      }
      setState(() => _currentScreen = AppScreen.login);
    } catch (e) {
      if (!mounted) return;
      _scaffoldMessengerKey.currentState?.showSnackBar(
        SnackBar(content: Text('No se pudo guardar el usuario: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _isBusy = false);
      }
    }
  }

  Color _getSkyColor(double v) {
    const stops = [
      (t: 0.0, r: 135, g: 206, b: 235),
      (t: 0.3, r: 100, g: 170, b: 210),
      (t: 0.5, r: 60, g: 100, b: 160),
      (t: 0.65, r: 30, g: 50, b: 110),
      (t: 0.8, r: 12, g: 20, b: 60),
      (t: 1.0, r: 5, g: 8, b: 30),
    ];
    for (int i = 0; i < stops.length - 1; i++) {
      final a = stops[i], b = stops[i + 1];
      if (v >= a.t && v <= b.t) {
        final tt = (v - a.t) / (b.t - a.t);
        return Color.fromRGBO(
          (a.r + (b.r - a.r) * tt).round(),
          (a.g + (b.g - a.g) * tt).round(),
          (a.b + (b.b - a.b) * tt).round(),
          1,
        );
      }
    }
    return const Color.fromRGBO(5, 8, 30, 1);
  }

  Color get _seedColor {
    if (_themeValue < 0.5) return const Color(0xFF1A3557);
    final t = (_themeValue - 0.5) * 2;
    return Color.lerp(const Color(0xFF1A3557), const Color(0xFF0A0E2A), t)!;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = _themeValue > 0.5;
    return MaterialApp(
      title: 'Columna',
      debugShowCheckedModeBanner: false,
      scaffoldMessengerKey: _scaffoldMessengerKey,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: _seedColor,
          brightness: isDark ? Brightness.dark : Brightness.light,
        ),
        useMaterial3: true,
      ),
      home: _buildCurrentScreen(),
    );
  }

  Widget _buildCurrentScreen() {
    switch (_currentScreen) {
      case AppScreen.login:
        return MyLoginPage(
          onLoginRequested: _handleLogin,
          onGoToRegister: () => setState(() => _currentScreen = AppScreen.register),
          isBusy: _isBusy,
        );
      case AppScreen.register:
        return MyRegisterPage(
          onRegisterRequested: _handleRegister,
          onGoToLogin: () => setState(() => _currentScreen = AppScreen.login),
          isBusy: _isBusy,
        );
      case AppScreen.home:
        return MyHomePage(
          user: _activeUser!,
          themeValue: _themeValue,
          skyColor: _getSkyColor(_themeValue),
          onThemeChanged: _onThemeChanged,
          onLogout: () {
            setState(() {
              _activeUser = null;
              _currentScreen = AppScreen.login;
            });
          },
        );
    }
  }
}

class MyLoginPage extends StatefulWidget {
  final Future<void> Function(String email, String password) onLoginRequested;
  final VoidCallback onGoToRegister;
  final bool isBusy;

  const MyLoginPage({
    super.key,
    required this.onLoginRequested,
    required this.onGoToRegister,
    required this.isBusy,
  });

  @override
  State<MyLoginPage> createState() => _MyLoginPageState();
}

class _MyLoginPageState extends State<MyLoginPage> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  Future<void> _submit() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    if (email.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Completa tus datos para entrar.')),
      );
      return;
    }
    await widget.onLoginRequested(email, password);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: isDark
                ? [const Color(0xFF060D1E), const Color(0xFF0D1B3E)]
                : [const Color(0xFFF4F6F9), const Color(0xFFEAF2FF)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            child: Container(
              width: 400,
              margin: const EdgeInsets.all(24),
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF0D1B3E) : Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.12),
                    blurRadius: 24,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.lock_outline_rounded,
                    size: 62,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Iniciar sesión',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Accede a tu cuenta local con SQLite',
                    style: TextStyle(color: Colors.grey.shade600),
                  ),
                  const SizedBox(height: 24),
                  TextField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    decoration: InputDecoration(
                      labelText: 'Correo electrónico',
                      prefixIcon: const Icon(Icons.email_outlined),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _passwordController,
                    obscureText: true,
                    decoration: InputDecoration(
                      labelText: 'Contraseña',
                      prefixIcon: const Icon(Icons.lock_outline_rounded),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: widget.isBusy ? null : _submit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Theme.of(context).colorScheme.primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: widget.isBusy
                          ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Text('INGRESAR', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextButton(
                    onPressed: widget.onGoToRegister,
                    child: const Text('¿No tienes una cuenta? Crear usuario'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class MyRegisterPage extends StatefulWidget {
  final Future<void> Function(String name, String email, String password, String accountType) onRegisterRequested;
  final VoidCallback onGoToLogin;
  final bool isBusy;

  const MyRegisterPage({
    super.key,
    required this.onRegisterRequested,
    required this.onGoToLogin,
    required this.isBusy,
  });

  @override
  State<MyRegisterPage> createState() => _MyRegisterPageState();
}

class _MyRegisterPageState extends State<MyRegisterPage> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _checkboxValue = false;
  bool _emailTouched = false;
  String _accountType = 'Personal';

  final List<String> _allowedDomains = ['gmail.com', 'hotmail.com', 'outlook.com', 'yahoo.com', 'icloud.com', 'live.com', 'protonmail.com'];

  bool get _emailValid {
    final email = _emailController.text.trim();
    final regex = RegExp(r'^[\w\.\-]+@([\w\-]+\.)+[\w\-]{2,}$');
    if (!regex.hasMatch(email)) return false;
    final domain = email.split('@').last.toLowerCase();
    return _allowedDomains.contains(domain);
  }

  Future<void> _submit() async {
    final name = _nameController.text.trim();
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    if (name.isEmpty) {
      _showError('Campo requerido', 'Ingresa tu nombre completo.');
      return;
    }
    if (email.isEmpty || !_emailValid) {
      _showError('Correo inválido', 'Usa un correo con uno de los dominios permitidos.');
      return;
    }
    if (password.length < 4) {
      _showError('Contraseña débil', 'La contraseña debe tener al menos 4 caracteres.');
      return;
    }
    if (!_checkboxValue) {
      _showError('Términos no aceptados', 'Debes aceptar los términos antes de continuar.');
      return;
    }

    await widget.onRegisterRequested(name, email, password, _accountType);
  }

  void _showError(String title, String content) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(title),
        content: Text(content),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Entendido'))],
      ),
    );
  }

  void _showTerms() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        title: const Text('Términos y condiciones'),
        content: const Text('Tus datos se guardan localmente en SQLite y solo se usarán para acceder a la app.'),
        actions: [
          TextButton(
            onPressed: () {
              setState(() => _checkboxValue = false);
              Navigator.pop(context);
            },
            child: const Text('Rechazar'),
          ),
          ElevatedButton(
            onPressed: () {
              setState(() => _checkboxValue = true);
              Navigator.pop(context);
            },
            child: const Text('Acepto los términos'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: isDark
                ? [const Color(0xFF060D1E), const Color(0xFF0D1B3E)]
                : [const Color(0xFFF4F6F9), const Color(0xFFEAF2FF)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            child: Container(
              width: 440,
              margin: const EdgeInsets.all(24),
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF0D1B3E) : Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.12),
                    blurRadius: 24,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Center(
                    child: Text('Crear usuario', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                  ),
                  const SizedBox(height: 24),
                  const Text('Nombre completo *', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _nameController,
                    decoration: InputDecoration(
                      hintText: 'Ej: Ana García',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text('Correo electrónico *', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _emailController,
                    onChanged: (_) => setState(() => _emailTouched = true),
                    decoration: InputDecoration(
                      hintText: 'ejemplo@gmail.com',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      suffixIcon: _emailTouched && _emailController.text.isNotEmpty
                          ? Icon(_emailValid ? Icons.check_circle : Icons.cancel, color: _emailValid ? Colors.green : Colors.red)
                          : null,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text('Contraseña *', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _passwordController,
                    obscureText: true,
                    decoration: InputDecoration(
                      hintText: 'Crea una contraseña',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text('Tipo de cuenta', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: ['Personal', 'Trabajo', 'Educativa'].map((tipo) {
                      return ChoiceChip(
                        label: Text(tipo),
                        selected: _accountType == tipo,
                        onSelected: (_) => setState(() => _accountType = tipo),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Checkbox(
                        value: _checkboxValue,
                        onChanged: (value) {
                          if (value == true) {
                            _showTerms();
                          } else {
                            setState(() => _checkboxValue = false);
                          }
                        },
                      ),
                      Expanded(
                        child: GestureDetector(
                          onTap: _showTerms,
                          child: const Text(
                            'Acepto los términos',
                            style: TextStyle(decoration: TextDecoration.underline),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: widget.onGoToLogin,
                          child: const Text('CANCELAR'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: widget.isBusy ? null : _submit,
                          child: widget.isBusy
                              ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2))
                              : const Text('REGISTRAR'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class MyHomePage extends StatefulWidget {
  final UserProfile user;
  final double themeValue;
  final Color skyColor;
  final ValueChanged<double> onThemeChanged;
  final VoidCallback onLogout;

  const MyHomePage({
    super.key,
    required this.user,
    required this.themeValue,
    required this.skyColor,
    required this.onThemeChanged,
    required this.onLogout,
  });

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  bool get _isDark => widget.themeValue > 0.5;
  Color get _cardColor => _isDark ? const Color(0xFF0D1B3E).withOpacity(0.92) : Colors.white;
  Color get _primaryColor => _isDark ? const Color(0xFF7B8EC8) : const Color(0xFF1A3557);
  late Future<List<ApiPost>> _postsFuture;
  bool _permissionRequested = false;
  Timer? _timer;
  DateTime _currentTime = DateTime.now();

  Future<void> _openNotificationSettings() async {
    final granted = await NotificationsService.instance.requestPermissionIfNeeded();
    setState(() => _permissionRequested = true);
    if (!granted && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se concedieron los permisos de notificaciones.')),
      );
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Permisos de notificaciones activados.')),
      );
    }
  }

  @override
  void initState() {
    super.initState();
    _postsFuture = ApiService.fetchPosts();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() => _currentTime = DateTime.now());
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _openNotesScreen() {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => const LocalNotesScreen()));
  }

  void _openPostManagerScreen() {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ApiPostManagerScreen()));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Panel de control'),
        centerTitle: true,
        backgroundColor: _primaryColor,
        foregroundColor: Colors.white,
        actions: [
          IconButton(icon: const Icon(Icons.refresh_rounded), onPressed: () => setState(() => _postsFuture = ApiService.fetchPosts())),
          IconButton(icon: const Icon(Icons.settings_outlined), onPressed: _openNotificationSettings),
          IconButton(icon: const Icon(Icons.logout_rounded), onPressed: widget.onLogout),
        ],
      ),
      body: Container(
        color: _isDark ? const Color(0xFF060D1E) : const Color(0xFFF4F6F9),
        child: Center(
          child: SingleChildScrollView(
            child: Container(
              width: 460,
              margin: const EdgeInsets.all(24),
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: _cardColor,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(_isDark ? 0.28 : 0.08),
                    blurRadius: 24,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SkyWidget(value: widget.themeValue, skyColor: widget.skyColor),
                  const SizedBox(height: 16),
                  ThemeSliderWidget(value: widget.themeValue, onChanged: widget.onThemeChanged),
                  const SizedBox(height: 24),
                  Center(
                    child: Column(
                      children: [
                        Text(
                          'Bienvenido de nuevo',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: _isDark ? Colors.white54 : Colors.grey.shade600,
                            letterSpacing: 1.2,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          widget.user.name,
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: _primaryColor),
                        ),
                        const SizedBox(height: 8),
                        Chip(
                          label: Text('Cuenta ${widget.user.accountType}'),
                          backgroundColor: _primaryColor.withOpacity(0.16),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Divider(),
                  const SizedBox(height: 16),
                  _InfoTile(icon: Icons.email_outlined, title: 'Correo', subtitle: widget.user.email),
                  _InfoTile(icon: Icons.calendar_month_outlined, title: 'Creado', subtitle: '${widget.user.createdAt.day}/${widget.user.createdAt.month}/${widget.user.createdAt.year}'),
                  _InfoTile(icon: Icons.login_outlined, title: 'Último ingreso', subtitle: widget.user.lastLoginAt == null ? 'Aún no ha iniciado sesión' : '${widget.user.lastLoginAt!.day}/${widget.user.lastLoginAt!.month}/${widget.user.lastLoginAt!.year}'),
                  const SizedBox(height: 16),
                  if (!_permissionRequested)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: _primaryColor.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.notifications_active_outlined, color: _primaryColor),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Usa el icono de ajustes para activar las notificaciones.',
                              style: TextStyle(color: _primaryColor, fontWeight: FontWeight.w600),
                            ),
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 16),
                  Text('Datos desde una API', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: _primaryColor)),
                  const SizedBox(height: 8),
                  FutureBuilder<List<ApiPost>>(
                    future: _postsFuture,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Padding(
                          padding: EdgeInsets.symmetric(vertical: 12),
                          child: Center(child: CircularProgressIndicator()),
                        );
                      }
                      if (snapshot.hasError) {
                        return Text('No se pudieron cargar los datos: ${snapshot.error}', style: const TextStyle(color: Colors.redAccent));
                      }
                      final posts = snapshot.data ?? <ApiPost>[];
                      return ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: posts.length > 3 ? 3 : posts.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          final post = posts[index];
                          return Card(
                            child: ListTile(
                              title: Text(post.title, maxLines: 1, overflow: TextOverflow.ellipsis),
                              subtitle: Text(post.body, maxLines: 2, overflow: TextOverflow.ellipsis),
                            ),
                          );
                        },
                      );
                    },
                  ),
                  const SizedBox(height: 24),
                  Text('Hora actual', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: _primaryColor)),
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                    decoration: BoxDecoration(
                      color: _primaryColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${_currentTime.hour.toString().padLeft(2, '0')}:${_currentTime.minute.toString().padLeft(2, '0')}:${_currentTime.second.toString().padLeft(2, '0')}',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: _primaryColor),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _openNotesScreen,
                          icon: const Icon(Icons.note_alt_outlined),
                          label: const Text('Notas locales'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _primaryColor,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _openPostManagerScreen,
                          icon: const Icon(Icons.cloud_queue_outlined),
                          label: const Text('CRUD API'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _primaryColor.withOpacity(0.9),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: widget.onLogout,
                      icon: const Icon(Icons.exit_to_app),
                      label: const Text('Cerrar sesión'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red,
                        side: const BorderSide(color: Colors.red),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _InfoTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _InfoTile({required this.icon, required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: ListTile(
        contentPadding: EdgeInsets.zero,
        leading: CircleAvatar(
          backgroundColor: Theme.of(context).colorScheme.primary.withOpacity(0.12),
          child: Icon(icon, color: Theme.of(context).colorScheme.primary),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
        subtitle: Text(subtitle),
      ),
    );
  }
}

class LocalNotesScreen extends StatefulWidget {
  const LocalNotesScreen({super.key});

  @override
  State<LocalNotesScreen> createState() => _LocalNotesScreenState();
}

class _LocalNotesScreenState extends State<LocalNotesScreen> {
  final _controller = TextEditingController();
  bool _isLoading = true;
  bool _isSaving = false;
  static const _filename = 'columna_notes.txt';

  @override
  void initState() {
    super.initState();
    _loadNotes();
  }

  Future<void> _loadNotes() async {
    final content = await LocalFileService.instance.readText(_filename);
    if (!mounted) return;
    setState(() {
      _controller.text = content;
      _isLoading = false;
    });
  }

  Future<void> _saveNotes() async {
    setState(() => _isSaving = true);
    await LocalFileService.instance.writeText(_filename, _controller.text);
    if (!mounted) return;
    setState(() => _isSaving = false);
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Notas guardadas localmente.')));
  }

  Future<void> _appendLine() async {
    if (_controller.text.isNotEmpty && !_controller.text.endsWith('\n')) {
      _controller.text += '\n';
    }
    _controller.text += 'Nueva nota rápida: ${DateTime.now()}';
    await _saveNotes();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Notas locales'), centerTitle: true),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : Column(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      keyboardType: TextInputType.multiline,
                      maxLines: null,
                      decoration: const InputDecoration(
                        labelText: 'Escribe tus notas aquí',
                        alignLabelWithHint: true,
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _isSaving ? null : _saveNotes,
                          icon: const Icon(Icons.save),
                          label: _isSaving ? const Text('Guardando...') : const Text('Guardar'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      IconButton(
                        onPressed: _appendLine,
                        icon: const Icon(Icons.note_add_outlined),
                        tooltip: 'Agregar nota rápida',
                      ),
                    ],
                  ),
                ],
              ),
      ),
    );
  }
}

class ApiPostManagerScreen extends StatefulWidget {
  const ApiPostManagerScreen({super.key});

  @override
  State<ApiPostManagerScreen> createState() => _ApiPostManagerScreenState();
}

class _ApiPostManagerScreenState extends State<ApiPostManagerScreen> {
  late Future<List<ApiPost>> _postsFuture;
  final _titleController = TextEditingController();
  final _bodyController = TextEditingController();
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    _postsFuture = ApiService.fetchPosts();
  }

  Future<void> _refreshPosts() async {
    setState(() => _postsFuture = ApiService.fetchPosts());
  }

  Future<void> _createPost() async {
    final title = _titleController.text.trim();
    final body = _bodyController.text.trim();
    if (title.isEmpty || body.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Completa título y cuerpo.')));
      return;
    }

    setState(() => _isProcessing = true);
    try {
      await ApiService.createPost(ApiPost(id: 0, userId: 1, title: title, body: body));
      _titleController.clear();
      _bodyController.clear();
      await _refreshPosts();
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Post creado correctamente.')));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error al crear post: $e')));
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _editPost(ApiPost post) async {
    _titleController.text = post.title;
    _bodyController.text = post.body;
    final updated = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Editar post'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: _titleController, decoration: const InputDecoration(labelText: 'Título')),
            const SizedBox(height: 12),
            TextField(controller: _bodyController, decoration: const InputDecoration(labelText: 'Cuerpo')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('Actualizar')),
        ],
      ),
    );

    if (updated == true) {
      setState(() => _isProcessing = true);
      try {
        await ApiService.updatePost(ApiPost(id: post.id, userId: post.userId, title: _titleController.text.trim(), body: _bodyController.text.trim()));
        _titleController.clear();
        _bodyController.clear();
        await _refreshPosts();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Post actualizado.')));
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error actualizando post: $e')));
        }
      } finally {
        if (mounted) setState(() => _isProcessing = false);
      }
    }
  }

  Future<void> _deletePost(int id) async {
    setState(() => _isProcessing = true);
    try {
      final deleted = await ApiService.deletePost(id);
      if (!mounted) return;
      if (deleted) {
        await _refreshPosts();
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Post eliminado.')));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No se pudo eliminar el post.')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error eliminando post: $e')));
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('CRUD API'),
        centerTitle: true,
        actions: [IconButton(icon: const Icon(Icons.refresh_outlined), onPressed: _refreshPosts)],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: _titleController,
              decoration: const InputDecoration(labelText: 'Título del post'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _bodyController,
              decoration: const InputDecoration(labelText: 'Contenido del post'),
              maxLines: 3,
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isProcessing ? null : _createPost,
                icon: const Icon(Icons.add),
                label: Text(_isProcessing ? 'Procesando...' : 'Crear post'),
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: FutureBuilder<List<ApiPost>>(
                future: _postsFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snapshot.hasError) {
                    return Center(child: Text('Error: ${snapshot.error}'));
                  }
                  final posts = snapshot.data ?? <ApiPost>[];
                  return ListView.separated(
                    itemCount: posts.length,
                    separatorBuilder: (_, __) => const Divider(),
                    itemBuilder: (context, index) {
                      final post = posts[index];
                      return ListTile(
                        title: Text(post.title, maxLines: 1, overflow: TextOverflow.ellipsis),
                        subtitle: Text(post.body, maxLines: 2, overflow: TextOverflow.ellipsis),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(icon: const Icon(Icons.edit_outlined), onPressed: _isProcessing ? null : () => _editPost(post)),
                            IconButton(icon: const Icon(Icons.delete_outline), onPressed: _isProcessing ? null : () => _deletePost(post.id)),
                          ],
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class SkyPainter extends CustomPainter {
  final double value;
  final List<_Star> stars;
  final double tick;

  SkyPainter({required this.value, required this.stars, required this.tick});

  @override
  void paint(Canvas canvas, Size size) {
    final sunOpacity = value < 0.5 ? (1 - value * 2.2).clamp(0.0, 1.0) : 0.0;
    if (sunOpacity > 0) {
      final sunX = size.width / 2;
      const sunY = 55.0;
      final sunR = 28.0 * (0.85 + (1 - value) * 0.15);
      final glowPaint = Paint()..color = const Color(0xFFFFD93D).withOpacity(0.22 * sunOpacity)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 18);
      canvas.drawCircle(Offset(sunX, sunY), sunR + 14, glowPaint);
      final sunPaint = Paint()..color = const Color(0xFFFFD93D).withOpacity(sunOpacity);
      canvas.drawCircle(Offset(sunX, sunY), sunR, sunPaint);
    }

    final moonOpacity = value > 0.38 ? ((value - 0.38) * 2.5).clamp(0.0, 1.0) : 0.0;
    if (moonOpacity > 0) {
      final moonX = size.width / 2;
      const moonY = 55.0;
      final moonR = 24.0 * (0.85 + value * 0.12);
      final moonGlow = Paint()..color = const Color(0xFFE8E8D0).withOpacity(0.15 * moonOpacity)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 14);
      canvas.drawCircle(Offset(moonX, moonY), moonR + 10, moonGlow);
      final moonPaint = Paint()..color = const Color(0xFFE8E8D0).withOpacity(moonOpacity);
      canvas.drawCircle(Offset(moonX, moonY), moonR, moonPaint);
      final shadowPaint = Paint()..color = const Color(0xFF8899BB).withOpacity(0.55 * moonOpacity);
      canvas.drawCircle(Offset(moonX + moonR * 0.35, moonY - moonR * 0.1), moonR * 0.82, shadowPaint);
    }

    final cloudOpacity = value < 0.45 ? (1 - value * 1.8).clamp(0.0, 1.0) : 0.0;
    if (cloudOpacity > 0) {
      final cloudPaint = Paint()..color = Colors.white.withOpacity(0.82 * cloudOpacity);
      _drawCloud(canvas, size.width * 0.15, 42, 80, 22, cloudPaint);
      _drawCloud(canvas, size.width * 0.75, 36, 100, 28, cloudPaint);
      _drawCloud(canvas, size.width * 0.55, 65, 60, 18, cloudPaint);
    }

    final starsOpacity = value > 0.5 ? ((value - 0.5) * 2.8).clamp(0.0, 1.0) : 0.0;
    if (starsOpacity > 0) {
      for (final s in stars) {
        final twinkle = 0.55 + 0.45 * sin(tick + s.phase);
        final starPaint = Paint()..color = const Color(0xFFFFFFF0).withOpacity(twinkle * starsOpacity);
        canvas.drawCircle(Offset(s.x * size.width, s.y * size.height * 0.85), s.radius, starPaint);
      }
    }
  }

  void _drawCloud(Canvas canvas, double cx, double cy, double w, double h, Paint paint) {
    final rect = RRect.fromRectAndRadius(Rect.fromCenter(center: Offset(cx, cy), width: w, height: h), Radius.circular(h / 1.5));
    canvas.drawRRect(rect, paint);
    canvas.drawCircle(Offset(cx - w * 0.2, cy - h * 0.3), h * 0.55, paint);
    canvas.drawCircle(Offset(cx + w * 0.15, cy - h * 0.35), h * 0.48, paint);
  }

  @override
  bool shouldRepaint(SkyPainter old) => old.value != value || old.tick != tick;
}

class _Star {
  final double x, y, radius, phase;
  const _Star(this.x, this.y, this.radius, this.phase);
}

class SkyWidget extends StatefulWidget {
  final double value;
  final Color skyColor;

  const SkyWidget({super.key, required this.value, required this.skyColor});

  @override
  State<SkyWidget> createState() => _SkyWidgetState();
}

class _SkyWidgetState extends State<SkyWidget> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late List<_Star> _stars;
  double _tick = 0;

  @override
  void initState() {
    super.initState();
    final rng = Random(42);
    _stars = List.generate(80, (_) => _Star(rng.nextDouble(), rng.nextDouble(), rng.nextDouble() * 1.6 + 0.4, rng.nextDouble() * pi * 2));
    _ctrl = AnimationController(vsync: this, duration: const Duration(seconds: 3))..repeat();
    _ctrl.addListener(() {
      setState(() => _tick = _ctrl.value * pi * 2);
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 400),
      height: 130,
      decoration: BoxDecoration(color: widget.skyColor, borderRadius: BorderRadius.circular(12)),
      child: CustomPaint(
        painter: SkyPainter(value: widget.value, stars: _stars, tick: _tick),
        size: Size.infinite,
      ),
    );
  }
}

class ThemeSliderWidget extends StatelessWidget {
  final double value;
  final ValueChanged<double> onChanged;

  const ThemeSliderWidget({super.key, required this.value, required this.onChanged});

  String get _label {
    if (value < 0.1) return '☀️  Día claro';
    if (value < 0.35) return '🌤  Tarde soleada';
    if (value < 0.5) return '🌇  Atardecer';
    if (value < 0.65) return '🌆  Anochecer';
    if (value < 0.8) return '🌙  Noche';
    return '🌌  Noche estrellada';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = value > 0.5;
    final textColor = isDark ? Colors.white70 : const Color(0xFF4A5568);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0D1B3E).withOpacity(0.85) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isDark ? Colors.white.withOpacity(0.08) : const Color(0xFFE0E6ED)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(_label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: textColor, letterSpacing: 0.3)),
          const SizedBox(height: 10),
          Row(
            children: [
              const Icon(Icons.wb_sunny_rounded, color: Color(0xFFFFB020), size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: SliderTheme(
                  data: SliderThemeData(
                    trackHeight: 5,
                    thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 9),
                    overlayShape: const RoundSliderOverlayShape(overlayRadius: 18),
                    activeTrackColor: isDark ? const Color(0xFF7B8EC8) : const Color(0xFF1A3557),
                    inactiveTrackColor: isDark ? Colors.white.withOpacity(0.15) : const Color(0xFFE0E6ED),
                    thumbColor: isDark ? const Color(0xFFE8E8D0) : const Color(0xFF1A3557),
                  ),
                  child: Slider(value: value, min: 0, max: 1, onChanged: onChanged),
                ),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.nightlight_round, color: Color(0xFF7B8EC8), size: 20),
            ],
          ),
        ],
      ),
    );
  }
}
