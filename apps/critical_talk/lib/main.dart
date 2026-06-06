import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:audioplayers/audioplayers.dart' as audio_player;
import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:path/path.dart' as p;

import 'package:critical_talk/user_foundation.dart';

typedef ChatImagePicker = Future<SelectedChatImage?> Function();
typedef AudioTrackPicker = Future<SelectedAudioTrack?> Function();

void main() {
  runApp(const CriticalTalkApp());
}

class CriticalTalkApp extends StatefulWidget {
  const CriticalTalkApp({
    super.key,
    this.imagePicker = pickChatImage,
    this.trackPicker = pickAudioTrack,
    this.audioService = const LinuxAudioControlService(),
    this.musicPlaybackService = const _DefaultMusicPlaybackServiceBridge(),
    this.userAuthService = const _DefaultUserAuthServiceBridge(),
    this.diceRoller = const RandomDiceRoller(),
  });

  final ChatImagePicker imagePicker;
  final AudioTrackPicker trackPicker;
  final AudioControlService audioService;
  final MusicPlaybackService musicPlaybackService;
  final UserAuthService userAuthService;
  final DiceRoller diceRoller;

  @override
  State<CriticalTalkApp> createState() => _CriticalTalkAppState();
}

class _CriticalTalkAppState extends State<CriticalTalkApp> {
  late Future<AuthSession> _sessionFuture;
  CriticalUser? _currentUser;

  @override
  void initState() {
    super.initState();
    _sessionFuture = widget.userAuthService.loadSession();
  }

  void _setAuthenticatedUser(CriticalUser user) {
    setState(() {
      _currentUser = user;
    });
  }

  Future<void> _logout() async {
    await widget.userAuthService.logout();
    if (!mounted) {
      return;
    }

    setState(() {
      _currentUser = null;
      _sessionFuture = Future<AuthSession>.value(
        const AuthSession(currentUser: null),
      );
    });
  }

  void _retryBootstrap() {
    setState(() {
      _sessionFuture = widget.userAuthService.loadSession();
    });
  }

  @override
  void dispose() {
    unawaited(widget.musicPlaybackService.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Critical Talk',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF2F7D6D),
          brightness: Brightness.dark,
        ),
        scaffoldBackgroundColor: const Color(0xFF151719),
        useMaterial3: true,
      ),
      home: FutureBuilder<AuthSession>(
        future: _sessionFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done &&
              _currentUser == null) {
            return const BootstrapShell();
          }

          if (snapshot.hasError && _currentUser == null) {
            return BootstrapErrorShell(onRetry: _retryBootstrap);
          }

          final currentUser = _currentUser ?? snapshot.data?.currentUser;

          if (currentUser == null) {
            return AuthShell(
              authService: widget.userAuthService,
              onAuthenticated: _setAuthenticatedUser,
            );
          }

          return SessionShell(
            imagePicker: widget.imagePicker,
            trackPicker: widget.trackPicker,
            audioService: widget.audioService,
            musicPlaybackService: widget.musicPlaybackService,
            diceRoller: widget.diceRoller,
            currentUser: currentUser,
            authService: widget.userAuthService,
            onProfileUpdated: _setAuthenticatedUser,
            onLogout: _logout,
          );
        },
      ),
    );
  }
}

class _DefaultUserAuthServiceBridge extends UserAuthService {
  const _DefaultUserAuthServiceBridge();

  @override
  Future<AuthSession> loadSession() => FileUserAuthService().loadSession();

  @override
  Future<CriticalUser> login({
    required String userName,
    required String password,
  }) {
    return FileUserAuthService().login(userName: userName, password: password);
  }

  @override
  Future<UserRegistrationResult> register({
    required String userName,
    required String password,
    required List<int> organicEntropy,
  }) {
    return FileUserAuthService().register(
      userName: userName,
      password: password,
      organicEntropy: organicEntropy,
    );
  }

  @override
  Future<void> logout() => FileUserAuthService().logout();

  @override
  Future<CriticalUser> updateProfile({
    required String userId,
    required String userName,
    UserMedia? avatar,
    UserMedia? banner,
    required double bannerAlignmentY,
  }) {
    return FileUserAuthService().updateProfile(
      userId: userId,
      userName: userName,
      avatar: avatar,
      banner: banner,
      bannerAlignmentY: bannerAlignmentY,
    );
  }
}

enum SoundtrackPlaybackScope { idle, preview, room }

class SoundtrackPlaybackSnapshot {
  const SoundtrackPlaybackSnapshot({
    required this.activeTrackId,
    required this.scope,
    required this.isPlaying,
    required this.isPaused,
    required this.isLoopEnabled,
    required this.position,
    required this.duration,
    this.error,
  });

  factory SoundtrackPlaybackSnapshot.idle() {
    return const SoundtrackPlaybackSnapshot(
      activeTrackId: null,
      scope: SoundtrackPlaybackScope.idle,
      isPlaying: false,
      isPaused: false,
      isLoopEnabled: false,
      position: Duration.zero,
      duration: Duration.zero,
    );
  }

  final String? activeTrackId;
  final SoundtrackPlaybackScope scope;
  final bool isPlaying;
  final bool isPaused;
  final bool isLoopEnabled;
  final Duration position;
  final Duration duration;
  final String? error;

  bool get hasActiveTrack => activeTrackId != null;

  double get progress {
    if (duration.inMilliseconds <= 0) {
      return 0;
    }
    return (position.inMilliseconds / duration.inMilliseconds).clamp(0.0, 1.0);
  }

  String get scopeLabel => switch (scope) {
    SoundtrackPlaybackScope.preview => 'Preview privado',
    SoundtrackPlaybackScope.room => 'Ao vivo na sala',
    SoundtrackPlaybackScope.idle => 'Sem trilha ativa',
  };

  SoundtrackPlaybackSnapshot copyWith({
    Object? activeTrackId = _soundtrackSentinel,
    SoundtrackPlaybackScope? scope,
    bool? isPlaying,
    bool? isPaused,
    bool? isLoopEnabled,
    Duration? position,
    Duration? duration,
    Object? error = _soundtrackSentinel,
  }) {
    return SoundtrackPlaybackSnapshot(
      activeTrackId: activeTrackId == _soundtrackSentinel
          ? this.activeTrackId
          : activeTrackId as String?,
      scope: scope ?? this.scope,
      isPlaying: isPlaying ?? this.isPlaying,
      isPaused: isPaused ?? this.isPaused,
      isLoopEnabled: isLoopEnabled ?? this.isLoopEnabled,
      position: position ?? this.position,
      duration: duration ?? this.duration,
      error: error == _soundtrackSentinel ? this.error : error as String?,
    );
  }
}

abstract class MusicPlaybackService {
  const MusicPlaybackService();

  SoundtrackPlaybackSnapshot get snapshot;

  Stream<SoundtrackPlaybackSnapshot> get changes;

  Future<void> previewTrack(LocalSoundtrackTrack track);

  Future<void> playTrack(LocalSoundtrackTrack track);

  Future<void> pause();

  Future<void> resume();

  Future<void> stop();

  Future<void> setLoopEnabled(bool enabled);

  Future<void> dispose();
}

class AudioPlayersMusicPlaybackService extends MusicPlaybackService {
  AudioPlayersMusicPlaybackService() {
    _player.onPlayerStateChanged.listen(_handlePlayerState);
    _player.onDurationChanged.listen((duration) {
      _emit(_snapshot.copyWith(duration: duration));
    });
    _player.onPositionChanged.listen((position) {
      _emit(_snapshot.copyWith(position: position));
    });
    _player.onPlayerComplete.listen((_) {
      if (_snapshot.isLoopEnabled) {
        return;
      }
      _emit(
        _snapshot.copyWith(
          isPlaying: false,
          isPaused: false,
          position: Duration.zero,
          scope: SoundtrackPlaybackScope.idle,
        ),
      );
    });
  }

  final audio_player.AudioPlayer _player = audio_player.AudioPlayer();
  final StreamController<SoundtrackPlaybackSnapshot> _controller =
      StreamController<SoundtrackPlaybackSnapshot>.broadcast();
  SoundtrackPlaybackSnapshot _snapshot = SoundtrackPlaybackSnapshot.idle();

  @override
  SoundtrackPlaybackSnapshot get snapshot => _snapshot;

  @override
  Stream<SoundtrackPlaybackSnapshot> get changes => _controller.stream;

  @override
  Future<void> previewTrack(LocalSoundtrackTrack track) async {
    await _startTrack(track, scope: SoundtrackPlaybackScope.preview);
  }

  @override
  Future<void> playTrack(LocalSoundtrackTrack track) async {
    await _startTrack(track, scope: SoundtrackPlaybackScope.room);
  }

  Future<void> _startTrack(
    LocalSoundtrackTrack track, {
    required SoundtrackPlaybackScope scope,
  }) async {
    try {
      await _player.setReleaseMode(
        _snapshot.isLoopEnabled
            ? audio_player.ReleaseMode.loop
            : audio_player.ReleaseMode.stop,
      );
      await _player.play(audio_player.DeviceFileSource(track.path));
      _emit(
        _snapshot.copyWith(
          activeTrackId: track.id,
          scope: scope,
          isPlaying: true,
          isPaused: false,
          position: Duration.zero,
          error: null,
        ),
      );
    } catch (error) {
      _emit(_snapshot.copyWith(error: error.toString()));
    }
  }

  @override
  Future<void> pause() async {
    await _player.pause();
    _emit(_snapshot.copyWith(isPlaying: false, isPaused: true));
  }

  @override
  Future<void> resume() async {
    await _player.resume();
    _emit(_snapshot.copyWith(isPlaying: true, isPaused: false));
  }

  @override
  Future<void> stop() async {
    await _player.stop();
    _emit(
      _snapshot.copyWith(
        isPlaying: false,
        isPaused: false,
        position: Duration.zero,
        scope: SoundtrackPlaybackScope.idle,
      ),
    );
  }

  @override
  Future<void> setLoopEnabled(bool enabled) async {
    await _player.setReleaseMode(
      enabled ? audio_player.ReleaseMode.loop : audio_player.ReleaseMode.stop,
    );
    _emit(_snapshot.copyWith(isLoopEnabled: enabled));
  }

  @override
  Future<void> dispose() async {
    await _player.dispose();
    await _controller.close();
  }

  void _handlePlayerState(audio_player.PlayerState state) {
    switch (state) {
      case audio_player.PlayerState.playing:
        _emit(_snapshot.copyWith(isPlaying: true, isPaused: false));
        break;
      case audio_player.PlayerState.paused:
        _emit(_snapshot.copyWith(isPlaying: false, isPaused: true));
        break;
      case audio_player.PlayerState.stopped:
        _emit(_snapshot.copyWith(isPlaying: false, isPaused: false));
        break;
      case audio_player.PlayerState.completed:
        _emit(
          _snapshot.copyWith(
            isPlaying: false,
            isPaused: false,
            position: Duration.zero,
          ),
        );
        break;
      case audio_player.PlayerState.disposed:
        _emit(SoundtrackPlaybackSnapshot.idle());
        break;
    }
  }

  void _emit(SoundtrackPlaybackSnapshot next) {
    _snapshot = next;
    if (!_controller.isClosed) {
      _controller.add(next);
    }
  }
}

class _DefaultMusicPlaybackServiceBridge extends MusicPlaybackService {
  const _DefaultMusicPlaybackServiceBridge();

  static final AudioPlayersMusicPlaybackService _service =
      AudioPlayersMusicPlaybackService();

  @override
  Stream<SoundtrackPlaybackSnapshot> get changes => _service.changes;

  @override
  SoundtrackPlaybackSnapshot get snapshot => _service.snapshot;

  @override
  Future<void> dispose() async {}

  @override
  Future<void> pause() => _service.pause();

  @override
  Future<void> playTrack(LocalSoundtrackTrack track) => _service.playTrack(track);

  @override
  Future<void> previewTrack(LocalSoundtrackTrack track) =>
      _service.previewTrack(track);

  @override
  Future<void> resume() => _service.resume();

  @override
  Future<void> setLoopEnabled(bool enabled) => _service.setLoopEnabled(enabled);

  @override
  Future<void> stop() => _service.stop();
}

abstract class DiceRoller {
  const DiceRoller();

  DiceRollRecord roll(String expression, {required String author});
}

class RandomDiceRoller extends DiceRoller {
  const RandomDiceRoller();

  @override
  DiceRollRecord roll(String expression, {required String author}) {
    final request = parseDiceExpression(expression);
    final random = math.Random.secure();
    final rolls = List<int>.generate(
      request.diceCount,
      (_) => random.nextInt(request.sides) + 1,
    );

    final keptIndexes = _selectKeptIndexes(
      rolls: rolls,
      selectionMode: request.selectionMode,
      selectionCount: request.selectionCount,
    );
    final keptRolls = [
      for (var index = 0; index < rolls.length; index++)
        if (keptIndexes.contains(index)) rolls[index],
    ];
    final total =
        keptRolls.fold<int>(0, (sum, value) => sum + value) + request.modifier;

    return DiceRollRecord(
      author: author,
      expression: expression.trim(),
      normalizedExpression: request.normalizedExpression,
      total: total,
      modifier: request.modifier,
      rolls: rolls,
      keptRolls: keptRolls,
      selectionLabel: request.selectionLabel,
      rolledAt: DateTime.now(),
    );
  }

  Set<int> _selectKeptIndexes({
    required List<int> rolls,
    required DiceSelectionMode selectionMode,
    required int? selectionCount,
  }) {
    final indexes = List<int>.generate(rolls.length, (index) => index);

    if (selectionMode == DiceSelectionMode.none || selectionCount == null) {
      return indexes.toSet();
    }

    final safeCount = selectionCount.clamp(0, rolls.length);
    final sorted = [...indexes]
      ..sort((left, right) {
        final valueComparison = rolls[left].compareTo(rolls[right]);
        if (valueComparison != 0) {
          return valueComparison;
        }
        return left.compareTo(right);
      });

    switch (selectionMode) {
      case DiceSelectionMode.keepHighest:
        return sorted.reversed.take(safeCount).toSet();
      case DiceSelectionMode.keepLowest:
        return sorted.take(safeCount).toSet();
      case DiceSelectionMode.dropHighest:
        return sorted.reversed.skip(safeCount).toSet();
      case DiceSelectionMode.dropLowest:
        return sorted.skip(safeCount).toSet();
      case DiceSelectionMode.none:
        return indexes.toSet();
    }
  }
}

Future<SelectedChatImage?> pickChatImage() async {
  const imageTypeGroup = XTypeGroup(
    label: 'images',
    extensions: ['png', 'jpg', 'jpeg', 'gif', 'webp'],
  );

  final file = await openFile(acceptedTypeGroups: [imageTypeGroup]);

  if (file == null) {
    return null;
  }

  final bytes = await file.readAsBytes();

  return SelectedChatImage(name: file.name, bytes: bytes);
}

Future<SelectedAudioTrack?> pickAudioTrack() async {
  const audioTypeGroup = XTypeGroup(
    label: 'audio',
    extensions: ['mp3', 'wav', 'ogg', 'flac', 'm4a', 'aac', 'opus'],
  );

  final file = await openFile(acceptedTypeGroups: [audioTypeGroup]);

  if (file == null || file.path.isEmpty) {
    return null;
  }

  return SelectedAudioTrack(name: file.name, path: file.path);
}

class BootstrapShell extends StatelessWidget {
  const BootstrapShell({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: SizedBox(
          width: 240,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Carregando sessao segura'),
            ],
          ),
        ),
      ),
    );
  }
}

class BootstrapErrorShell extends StatelessWidget {
  const BootstrapErrorShell({required this.onRetry, super.key});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: Panel(
            title: 'Falha ao abrir sessao',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Nao foi possivel abrir os dados locais do usuario. Voce pode tentar novamente.',
                ),
                const Spacer(),
                FilledButton(
                  onPressed: onRetry,
                  child: const Text('Tentar de novo'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class AuthShell extends StatefulWidget {
  const AuthShell({
    required this.authService,
    required this.onAuthenticated,
    super.key,
  });

  final UserAuthService authService;
  final ValueChanged<CriticalUser> onAuthenticated;

  @override
  State<AuthShell> createState() => _AuthShellState();
}

class _AuthShellState extends State<AuthShell>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final _loginUserNameController = TextEditingController();
  final _loginPasswordController = TextEditingController();
  final _registerUserNameController = TextEditingController();
  final _registerPasswordController = TextEditingController();
  final _registerConfirmController = TextEditingController();
  final List<int> _entropyDeltas = [];
  int? _lastEntropyStamp;
  bool _isBusy = false;
  String? _loginError;
  String? _registerError;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _loginUserNameController.dispose();
    _loginPasswordController.dispose();
    _registerUserNameController.dispose();
    _registerPasswordController.dispose();
    _registerConfirmController.dispose();
    super.dispose();
  }

  void _recordOrganicEntropy(String _) {
    final now = DateTime.now().microsecondsSinceEpoch;
    final lastStamp = _lastEntropyStamp;

    if (lastStamp != null) {
      final delta = now - lastStamp;
      if (delta > 0) {
        _entropyDeltas.add(delta);
        if (_entropyDeltas.length > 64) {
          _entropyDeltas.removeAt(0);
        }
      }
    }

    _lastEntropyStamp = now;
  }

  Future<void> _login() async {
    FocusScope.of(context).unfocus();
    setState(() {
      _isBusy = true;
      _loginError = null;
    });

    try {
      final user = await widget.authService.login(
        userName: _loginUserNameController.text,
        password: _loginPasswordController.text,
      );

      if (!mounted) {
        return;
      }

      widget.onAuthenticated(user);
    } on UserAuthException catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _loginError = error.message;
      });
    } finally {
      if (mounted) {
        setState(() {
          _isBusy = false;
        });
      }
    }
  }

  Future<void> _register() async {
    FocusScope.of(context).unfocus();
    final confirmPassword = _registerConfirmController.text;

    if (_registerPasswordController.text != confirmPassword) {
      setState(() {
        _registerError = 'A confirmacao de senha nao confere.';
      });
      return;
    }

    setState(() {
      _isBusy = true;
      _registerError = null;
    });

    try {
      final result = await widget.authService.register(
        userName: _registerUserNameController.text,
        password: _registerPasswordController.text,
        organicEntropy: List<int>.from(_entropyDeltas),
      );

      if (!mounted) {
        return;
      }

      await showDialog<void>(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: const Text('Chave inicial do usuario'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Guarde essa chave. Ela representa o identificador fixo gerado na criacao da conta e esta sendo exibida agora para o primeiro pareamento.',
                ),
                const SizedBox(height: 12),
                SelectableText(
                  result.firstTimeKey,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    color: Color(0xFFBFE9DD),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () async {
                  await Clipboard.setData(
                    ClipboardData(text: result.firstTimeKey),
                  );
                  if (context.mounted) {
                    Navigator.of(context).pop();
                  }
                },
                child: const Text('Copiar'),
              ),
              FilledButton(
                onPressed: () {
                  Navigator.of(context).pop();
                },
                child: const Text('Continuar'),
              ),
            ],
          );
        },
      );

      if (!mounted) {
        return;
      }

      widget.onAuthenticated(result.user);
    } on UserAuthException catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _registerError = error.message;
      });
    } finally {
      if (mounted) {
        setState(() {
          _isBusy = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final passwordErrors = validatePassword(_registerPasswordController.text);
    final userNameErrors = validateUserName(_registerUserNameController.text);

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: const Color(0xFF202326),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFF30363A)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: const Color(0xFF2F7D6D),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(
                              Icons.casino,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(width: 12),
                          const Text(
                            'Critical Talk',
                            style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      const Text(
                        'Base de usuario e perfil',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Sem email, com nome de usuario, senha forte e identificador fixo protegido localmente.',
                        style: TextStyle(color: Color(0xFFAEB8B5), height: 1.5),
                      ),
                      const SizedBox(height: 20),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: const [
                          HeaderPill(icon: Icons.badge, label: 'ID fixo'),
                          HeaderPill(
                            icon: Icons.lock,
                            label: 'Hash + entropia',
                          ),
                          HeaderPill(
                            icon: Icons.perm_identity,
                            label: 'Perfil local',
                          ),
                        ],
                      ),
                      const Spacer(),
                      const AuthInfoStrip(
                        title: 'Fechando brechas agora',
                        lines: [
                          'O nome de usuario vira identidade primaria de login.',
                          'A senha fica derivada com Argon2id, nunca em texto puro.',
                          'O ID mistura aleatoriedade forte com cadencia humana complementar.',
                          'Os dados locais do usuario ficam gravados em blob criptografado.',
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 20),
              SizedBox(
                width: 420,
                child: Panel(
                  title: 'Acesso',
                  child: Column(
                    children: [
                      TabBar(
                        controller: _tabController,
                        tabs: const [
                          Tab(text: 'Entrar'),
                          Tab(text: 'Criar usuario'),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Expanded(
                        child: TabBarView(
                          controller: _tabController,
                          children: [
                            SingleChildScrollView(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  LabeledTextField(
                                    controller: _loginUserNameController,
                                    label: 'Nome de usuario',
                                    hintText: 'rogerin',
                                  ),
                                  const SizedBox(height: 12),
                                  LabeledTextField(
                                    controller: _loginPasswordController,
                                    label: 'Senha',
                                    hintText: 'Sua senha segura',
                                    obscureText: true,
                                    onSubmitted: (_) => _login(),
                                  ),
                                  if (_loginError != null) ...[
                                    const SizedBox(height: 12),
                                    ErrorStrip(message: _loginError!),
                                  ],
                                  const SizedBox(height: 16),
                                  FilledButton(
                                    onPressed: _isBusy ? null : _login,
                                    child: Text(
                                      _isBusy ? 'Entrando...' : 'Entrar',
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            SingleChildScrollView(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  LabeledTextField(
                                    controller: _registerUserNameController,
                                    label: 'Nome de usuario',
                                    hintText: 'rogerin',
                                    onChanged: _recordOrganicEntropy,
                                  ),
                                  const SizedBox(height: 12),
                                  LabeledTextField(
                                    controller: _registerPasswordController,
                                    label: 'Senha',
                                    hintText: 'Minimo de 8 caracteres',
                                    obscureText: true,
                                    onChanged: _recordOrganicEntropy,
                                  ),
                                  const SizedBox(height: 12),
                                  LabeledTextField(
                                    controller: _registerConfirmController,
                                    label: 'Confirmar senha',
                                    hintText: 'Repita a senha',
                                    obscureText: true,
                                    onChanged: _recordOrganicEntropy,
                                    onSubmitted: (_) => _register(),
                                  ),
                                  const SizedBox(height: 16),
                                  PasswordRuleList(
                                    userNameErrors: userNameErrors,
                                    passwordErrors: passwordErrors,
                                    passwordsMatch:
                                        _registerPasswordController.text ==
                                            _registerConfirmController.text &&
                                        _registerConfirmController
                                            .text
                                            .isNotEmpty,
                                  ),
                                  if (_registerError != null) ...[
                                    const SizedBox(height: 12),
                                    ErrorStrip(message: _registerError!),
                                  ],
                                  const SizedBox(height: 16),
                                  FilledButton(
                                    onPressed: _isBusy ? null : _register,
                                    child: Text(
                                      _isBusy
                                          ? 'Criando usuario...'
                                          : 'Criar usuario',
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class AuthInfoStrip extends StatelessWidget {
  const AuthInfoStrip({required this.title, required this.lines, super.key});

  final String title;
  final List<String> lines;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1D20),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF2A2F33)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
          const SizedBox(height: 10),
          ...lines.map(
            (line) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(top: 2),
                    child: Icon(
                      Icons.check_circle_outline,
                      size: 16,
                      color: Color(0xFF80DFC8),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      line,
                      style: const TextStyle(
                        color: Color(0xFFAEB8B5),
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class LabeledTextField extends StatelessWidget {
  const LabeledTextField({
    required this.controller,
    required this.label,
    required this.hintText,
    this.obscureText = false,
    this.onChanged,
    this.onSubmitted,
    super.key,
  });

  final TextEditingController controller;
  final String label;
  final String hintText;
  final bool obscureText;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          obscureText: obscureText,
          onChanged: onChanged,
          onSubmitted: onSubmitted,
          decoration: InputDecoration(
            hintText: hintText,
            filled: true,
            fillColor: const Color(0xFF151719),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide.none,
            ),
          ),
        ),
      ],
    );
  }
}

class PasswordRuleList extends StatelessWidget {
  const PasswordRuleList({
    required this.userNameErrors,
    required this.passwordErrors,
    required this.passwordsMatch,
    super.key,
  });

  final List<String> userNameErrors;
  final List<String> passwordErrors;
  final bool passwordsMatch;

  @override
  Widget build(BuildContext context) {
    final items = [
      RuleItem(
        text: 'Nome de usuario entre 3 e 24 caracteres',
        satisfied:
            !userNameErrors.any((error) => error.contains('3 caracteres')) &&
            !userNameErrors.any((error) => error.contains('24 caracteres')),
      ),
      RuleItem(
        text: 'Nome com letras, numeros, ponto, traco ou sublinhado',
        satisfied: !userNameErrors.any(
          (error) => error.contains('Use apenas letras'),
        ),
      ),
      RuleItem(
        text:
            'Senha com 8+ caracteres, maiuscula, minuscula, numero e especial',
        satisfied: passwordErrors.isEmpty,
      ),
      RuleItem(text: 'Confirmacao de senha igual', satisfied: passwordsMatch),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: items
          .map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Icon(
                    item.satisfied
                        ? Icons.check_circle
                        : Icons.radio_button_unchecked,
                    size: 16,
                    color: item.satisfied
                        ? const Color(0xFF80DFC8)
                        : const Color(0xFF6E7875),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      item.text,
                      style: const TextStyle(
                        color: Color(0xFFAEB8B5),
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          )
          .toList(),
    );
  }
}

class RuleItem {
  const RuleItem({required this.text, required this.satisfied});

  final String text;
  final bool satisfied;
}

abstract class AudioControlService {
  const AudioControlService();

  Future<AudioSnapshot> loadSnapshot();

  Future<AudioSnapshot> setDefaultInput(String inputId);

  Future<AudioSnapshot> setDefaultOutput(String outputId);

  Future<void> playBotTestAudio({String? outputId});

  Stream<double> watchInputLevels({String? inputId});

  Future<void> startInputMonitoring({
    required String inputId,
    required String outputId,
  });

  Future<void> stopInputMonitoring();
}

class LinuxAudioControlService extends AudioControlService {
  const LinuxAudioControlService();

  static const _audioEnv = <String, String>{'LANG': 'C', 'LC_ALL': 'C'};
  static Process? _monitorCaptureProcess;
  static Process? _monitorPlaybackProcess;
  static StreamSubscription<List<int>>? _monitorPipeSubscription;

  @override
  Future<AudioSnapshot> loadSnapshot() async {
    try {
      final infoResult = await Process.run('pactl', const [
        'info',
      ], environment: _audioEnv);
      final sourcesResult = await Process.run('pactl', const [
        'list',
        'short',
        'sources',
      ], environment: _audioEnv);
      final sinksResult = await Process.run('pactl', const [
        'list',
        'short',
        'sinks',
      ], environment: _audioEnv);

      if (infoResult.exitCode != 0 ||
          sourcesResult.exitCode != 0 ||
          sinksResult.exitCode != 0) {
        return AudioSnapshot.unavailable(
          error: _cleanError(
            [
              infoResult.stderr,
              sourcesResult.stderr,
              sinksResult.stderr,
            ].join('\n'),
          ),
        );
      }

      final info = _parsePactlInfo(infoResult.stdout.toString());
      final inputs = _parsePactlList(
        sourcesResult.stdout.toString(),
      ).where((device) => !device.id.endsWith('.monitor')).toList();
      final outputs = _parsePactlList(sinksResult.stdout.toString());

      return AudioSnapshot(
        inputs: inputs,
        outputs: outputs,
        defaultInputId: info.defaultSourceId,
        defaultOutputId: info.defaultSinkId,
        serverReachable: true,
      );
    } on ProcessException catch (error) {
      return AudioSnapshot.unavailable(error: error.message);
    }
  }

  @override
  Future<AudioSnapshot> setDefaultInput(String inputId) async {
    final result = await Process.run('pactl', [
      'set-default-source',
      inputId,
    ], environment: _audioEnv);

    if (result.exitCode != 0) {
      return AudioSnapshot.unavailable(
        error: _cleanError(result.stderr.toString()),
      );
    }

    return loadSnapshot();
  }

  @override
  Future<AudioSnapshot> setDefaultOutput(String outputId) async {
    final result = await Process.run('pactl', [
      'set-default-sink',
      outputId,
    ], environment: _audioEnv);

    if (result.exitCode != 0) {
      return AudioSnapshot.unavailable(
        error: _cleanError(result.stderr.toString()),
      );
    }

    return loadSnapshot();
  }

  @override
  Future<void> playBotTestAudio({String? outputId}) async {
    final file = File(
      p.join(
        Directory.systemTemp.path,
        'critical-talk-bot-${DateTime.now().millisecondsSinceEpoch}.wav',
      ),
    );

    await file.writeAsBytes(_generateTestWaveBytes(), flush: true);

    final arguments = <String>[
      if (outputId != null && outputId.isNotEmpty) '--device=$outputId',
      file.path,
    ];

    try {
      final process = await Process.start(
        'paplay',
        arguments,
        environment: _audioEnv,
      );
      final stderrBuffer = StringBuffer();

      process.stderr.transform(utf8.decoder).listen(stderrBuffer.write);

      final exitCode = await process.exitCode;

      if (exitCode != 0) {
        throw AudioServiceException(
          _cleanError(stderrBuffer.toString()).ifEmpty('Falha ao tocar audio.'),
        );
      }
    } on ProcessException catch (error) {
      throw AudioServiceException(error.message);
    } finally {
      if (await file.exists()) {
        await file.delete();
      }
    }
  }

  @override
  Stream<double> watchInputLevels({String? inputId}) {
    Process? process;
    StreamSubscription<List<int>>? stdoutSubscription;
    StreamSubscription<List<int>>? stderrSubscription;

    final controller = StreamController<double>();

    Future<void> disposeProcess() async {
      await stdoutSubscription?.cancel();
      await stderrSubscription?.cancel();
      process?.kill(ProcessSignal.sigterm);
      process = null;
    }

    controller.onListen = () async {
      try {
        process = await Process.start('parec', <String>[
          '--raw',
          '--rate=16000',
          '--channels=1',
          '--format=s16le',
          if (inputId != null && inputId.isNotEmpty) '--device=$inputId',
        ], environment: _audioEnv);
      } on ProcessException {
        if (!controller.isClosed) {
          controller.add(0);
          await controller.close();
        }
        return;
      }

      stdoutSubscription = process!.stdout.listen((chunk) {
        if (chunk.isEmpty || controller.isClosed) {
          return;
        }

        controller.add(_computeNormalizedLevel(Uint8List.fromList(chunk)));
      });

      stderrSubscription = process!.stderr.listen((_) {});

      unawaited(
        process!.exitCode.then((_) async {
          if (!controller.isClosed) {
            controller.add(0);
            await controller.close();
          }
        }),
      );
    };

    controller.onCancel = () async {
      await disposeProcess();
    };

    return controller.stream;
  }

  @override
  Future<void> startInputMonitoring({
    required String inputId,
    required String outputId,
  }) async {
    await stopInputMonitoring();

    try {
      final capture = await Process.start('parec', <String>[
        '--raw',
        '--rate=16000',
        '--channels=1',
        '--format=s16le',
        '--latency-msec=20',
        '--device=$inputId',
      ], environment: _audioEnv);

      final playback = await Process.start('pacat', <String>[
        '--playback',
        '--raw',
        '--rate=16000',
        '--channels=1',
        '--format=s16le',
        '--latency-msec=20',
        '--device=$outputId',
      ], environment: _audioEnv);

      _monitorCaptureProcess = capture;
      _monitorPlaybackProcess = playback;
      _monitorPipeSubscription = capture.stdout.listen(
        playback.stdin.add,
        onDone: () async {
          await playback.stdin.close();
        },
      );

      unawaited(capture.stderr.drain<void>());
      unawaited(playback.stderr.drain<void>());
    } on ProcessException catch (error) {
      await stopInputMonitoring();
      throw AudioServiceException(error.message);
    }
  }

  @override
  Future<void> stopInputMonitoring() async {
    await _monitorPipeSubscription?.cancel();
    _monitorPipeSubscription = null;

    try {
      await _monitorPlaybackProcess?.stdin.close();
    } catch (_) {}

    _monitorCaptureProcess?.kill(ProcessSignal.sigterm);
    _monitorPlaybackProcess?.kill(ProcessSignal.sigterm);
    _monitorCaptureProcess = null;
    _monitorPlaybackProcess = null;
  }

  List<AudioDevice> _parsePactlList(String rawOutput) {
    return rawOutput
        .split('\n')
        .where((line) => line.trim().isNotEmpty)
        .map((line) {
          final columns = line.split('\t');
          final id = columns.length > 1 ? columns[1] : '';
          final state = columns.isNotEmpty ? columns.last : 'UNKNOWN';

          return AudioDevice(
            id: id,
            label: _humanizeAudioDeviceLabel(id),
            state: state,
          );
        })
        .where((device) => device.id.isNotEmpty)
        .toList();
  }

  AudioDefaults _parsePactlInfo(String rawOutput) {
    String? defaultSinkId;
    String? defaultSourceId;

    for (final line in rawOutput.split('\n')) {
      if (line.startsWith('Default Sink:')) {
        defaultSinkId = line.split(':').skip(1).join(':').trim();
      } else if (line.startsWith('Default Source:')) {
        defaultSourceId = line.split(':').skip(1).join(':').trim();
      }
    }

    return AudioDefaults(
      defaultSinkId: defaultSinkId,
      defaultSourceId: defaultSourceId,
    );
  }

  Uint8List _generateTestWaveBytes() {
    const sampleRate = 44100;
    const durationSeconds = 2.0;
    const channels = 1;
    const bitsPerSample = 16;
    const frequency = 523.25;
    final totalSamples = (sampleRate * durationSeconds).toInt();
    final pcmBytes = BytesBuilder();

    for (var index = 0; index < totalSamples; index++) {
      final ramp = math.min(index / (sampleRate * 0.05), 1.0);
      final fadeOut = math.min(
        (totalSamples - index) / (sampleRate * 0.08),
        1.0,
      );
      final envelope = ramp * fadeOut;
      final sample =
          math.sin(2 * math.pi * frequency * (index / sampleRate)) *
          envelope *
          0.35;
      final value = (sample * 32767).round();
      final bytes = ByteData(2)..setInt16(0, value, Endian.little);
      pcmBytes.add(bytes.buffer.asUint8List());
    }

    final pcmData = pcmBytes.toBytes();
    final byteRate = sampleRate * channels * bitsPerSample ~/ 8;
    final blockAlign = channels * bitsPerSample ~/ 8;
    final header = ByteData(44)
      ..setUint32(0, 0x52494646, Endian.big)
      ..setUint32(4, 36 + pcmData.length, Endian.little)
      ..setUint32(8, 0x57415645, Endian.big)
      ..setUint32(12, 0x666d7420, Endian.big)
      ..setUint32(16, 16, Endian.little)
      ..setUint16(20, 1, Endian.little)
      ..setUint16(22, channels, Endian.little)
      ..setUint32(24, sampleRate, Endian.little)
      ..setUint32(28, byteRate, Endian.little)
      ..setUint16(32, blockAlign, Endian.little)
      ..setUint16(34, bitsPerSample, Endian.little)
      ..setUint32(36, 0x64617461, Endian.big)
      ..setUint32(40, pcmData.length, Endian.little);

    return Uint8List.fromList([...header.buffer.asUint8List(), ...pcmData]);
  }

  String _humanizeAudioDeviceLabel(String id) {
    return id
        .replaceAll('alsa_output.', '')
        .replaceAll('alsa_input.', '')
        .replaceAll('.analog-stereo', '')
        .replaceAll('.monitor', ' monitor')
        .replaceAllMapped(RegExp(r'[_\.]'), (_) => ' ')
        .trim();
  }

  String _cleanError(String stderr) {
    return stderr
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .join(' ');
  }

  double _computeNormalizedLevel(Uint8List bytes) {
    if (bytes.length < 2) {
      return 0;
    }

    final byteData = ByteData.sublistView(bytes);
    final sampleCount = bytes.length ~/ 2;
    var sum = 0.0;

    for (var offset = 0; offset < sampleCount; offset++) {
      final sample = byteData.getInt16(offset * 2, Endian.little) / 32768.0;
      sum += sample * sample;
    }

    final rms = math.sqrt(sum / sampleCount);
    return (rms * 4.5).clamp(0.0, 1.0);
  }
}

class SessionShell extends StatefulWidget {
  const SessionShell({
    required this.imagePicker,
    required this.trackPicker,
    required this.audioService,
    required this.musicPlaybackService,
    required this.diceRoller,
    required this.currentUser,
    required this.authService,
    required this.onProfileUpdated,
    required this.onLogout,
    super.key,
  });

  final ChatImagePicker imagePicker;
  final AudioTrackPicker trackPicker;
  final AudioControlService audioService;
  final MusicPlaybackService musicPlaybackService;
  final DiceRoller diceRoller;
  final CriticalUser currentUser;
  final UserAuthService authService;
  final ValueChanged<CriticalUser> onProfileUpdated;
  final Future<void> Function() onLogout;

  @override
  State<SessionShell> createState() => _SessionShellState();
}

class _SessionShellState extends State<SessionShell> {
  final List<ChatMessage> _messages = [
    const ChatMessage.text('Bot Teste', 'Pode testar o chat comigo.'),
    const ChatMessage.text(
      'Mestre',
      'As tochas tremem quando a porta de pedra range.',
    ),
    const ChatMessage.text('Mira', '**Percepcao** para escutar do outro lado.'),
    const ChatMessage.text('Darian', '1d20+4 = 17'),
    ChatMessage.image(
      'Noctua',
      imageName: 'ruinas-referencia.png',
      imageBytes: _demoImageBytes,
    ),
  ].toList();
  final List<LocalSoundtrackTrack> _soundtracks = [];
  late final List<DiceRollRecord> _diceHistory = [
    DiceRollRecord(
      author: 'Darian',
      expression: '1d20+4',
      normalizedExpression: '1d20+4',
      total: 17,
      modifier: 4,
      rolls: const [13],
      keptRolls: const [13],
      selectionLabel: null,
      rolledAt: DateTime.now().subtract(const Duration(minutes: 4)),
    ),
  ];

  AudioSnapshot _audioSnapshot = AudioSnapshot.loading();
  SoundtrackPlaybackSnapshot _soundtrackSnapshot =
      SoundtrackPlaybackSnapshot.idle();
  bool _isPickingImage = false;
  bool _isPickingTrack = false;
  bool _isAudioBusy = false;
  bool _isMusicBusy = false;
  bool _isBotPlaying = false;
  bool _isMicMuted = false;
  bool _isSelfMonitoring = false;
  double _selfInputLevel = 0;
  String? _selectedTrackId;
  StreamSubscription<double>? _inputLevelSubscription;
  StreamSubscription<SoundtrackPlaybackSnapshot>? _soundtrackSubscription;

  @override
  void initState() {
    super.initState();
    _soundtrackSnapshot = widget.musicPlaybackService.snapshot;
    _soundtrackSubscription = widget.musicPlaybackService.changes.listen((state) {
      if (!mounted) {
        return;
      }

      setState(() {
        _soundtrackSnapshot = state;
        _isMusicBusy = false;
      });
    });
    unawaited(_loadAudioSnapshot());
  }

  @override
  void dispose() {
    _inputLevelSubscription?.cancel();
    _soundtrackSubscription?.cancel();
    unawaited(widget.audioService.stopInputMonitoring());
    super.dispose();
  }

  Future<void> _loadAudioSnapshot() async {
    setState(() {
      _isAudioBusy = true;
    });

    final snapshot = await widget.audioService.loadSnapshot();

    if (!mounted) {
      return;
    }

    setState(() {
      _audioSnapshot = snapshot;
      _isAudioBusy = false;
    });

    _syncInputLevelMonitoring();
  }

  Future<void> _selectInput(String inputId) async {
    setState(() {
      _isAudioBusy = true;
    });

    final snapshot = await widget.audioService.setDefaultInput(inputId);

    if (!mounted) {
      return;
    }

    setState(() {
      _audioSnapshot = snapshot;
      _isAudioBusy = false;
    });

    _syncInputLevelMonitoring();
  }

  Future<void> _selectOutput(String outputId) async {
    setState(() {
      _isAudioBusy = true;
    });

    final snapshot = await widget.audioService.setDefaultOutput(outputId);

    if (!mounted) {
      return;
    }

    setState(() {
      _audioSnapshot = snapshot;
      _isAudioBusy = false;
    });

    _syncInputLevelMonitoring();
  }

  Future<void> _playBotTestAudio() async {
    if (_isBotPlaying || _isAudioBusy) {
      return;
    }

    setState(() {
      _isBotPlaying = true;
      _isAudioBusy = true;
    });

    try {
      await widget.audioService.playBotTestAudio(
        outputId: _audioSnapshot.defaultOutputId,
      );
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _audioSnapshot = _audioSnapshot.copyWith(error: error.toString());
      });
    } finally {
      if (mounted) {
        setState(() {
          _isBotPlaying = false;
          _isAudioBusy = false;
        });
      }
    }
  }

  void _toggleMute() {
    setState(() {
      _isMicMuted = !_isMicMuted;
      if (_isMicMuted) {
        _selfInputLevel = 0;
      }
    });

    _syncInputLevelMonitoring();
  }

  Future<void> _toggleSelfMonitoring() async {
    if (_audioSnapshot.defaultInputId == null ||
        _audioSnapshot.defaultOutputId == null) {
      return;
    }

    setState(() {
      _isAudioBusy = true;
    });

    try {
      if (_isSelfMonitoring) {
        await widget.audioService.stopInputMonitoring();
      } else {
        await widget.audioService.startInputMonitoring(
          inputId: _audioSnapshot.defaultInputId!,
          outputId: _audioSnapshot.defaultOutputId!,
        );
      }

      if (!mounted) {
        return;
      }

      setState(() {
        _isSelfMonitoring = !_isSelfMonitoring;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _audioSnapshot = _audioSnapshot.copyWith(error: error.toString());
      });
    } finally {
      if (mounted) {
        setState(() {
          _isAudioBusy = false;
        });
      }
    }
  }

  void _syncInputLevelMonitoring() {
    _inputLevelSubscription?.cancel();
    _inputLevelSubscription = null;

    if (_isMicMuted ||
        !_audioSnapshot.serverReachable ||
        _audioSnapshot.defaultInputId == null) {
      if (mounted && _selfInputLevel != 0) {
        setState(() {
          _selfInputLevel = 0;
        });
      }
      return;
    }

    _inputLevelSubscription = widget.audioService
        .watchInputLevels(inputId: _audioSnapshot.defaultInputId)
        .listen((level) {
          if (!mounted) {
            return;
          }

          final smoothed = (_selfInputLevel * 0.55) + (level * 0.45);

          setState(() {
            _selfInputLevel = smoothed < 0.015 ? 0 : smoothed;
          });
        });
  }

  void _queueBotReply() {
    Future<void>.delayed(const Duration(milliseconds: 450), () {
      if (!mounted) {
        return;
      }

      setState(() {
        _messages.add(const ChatMessage.text('Bot Teste', 'mensagem recebida'));
      });
    });
  }

  void _sendMessage(String text) {
    final cleanText = text.trim();

    if (cleanText.isEmpty || cleanText.length > MessageComposer.maxCharacters) {
      return;
    }

    setState(() {
      _messages.add(
        ChatMessage.text(widget.currentUser.userName, cleanText, self: true),
      );
    });

    _queueBotReply();
  }

  Future<void> _sendImage() async {
    if (_isPickingImage) {
      return;
    }

    setState(() {
      _isPickingImage = true;
    });

    try {
      final image = await widget.imagePicker();

      if (!mounted || image == null) {
        return;
      }

      setState(() {
        _messages.add(
          ChatMessage.image(
            widget.currentUser.userName,
            imageName: image.name,
            imageBytes: image.bytes,
            self: true,
          ),
        );
      });

      _queueBotReply();
    } finally {
      if (mounted) {
        setState(() {
          _isPickingImage = false;
        });
      }
    }
  }

  Future<void> _addSoundtrack() async {
    if (_isPickingTrack) {
      return;
    }

    setState(() {
      _isPickingTrack = true;
    });

    try {
      final selected = await widget.trackPicker();
      if (!mounted || selected == null) {
        return;
      }

      final track = LocalSoundtrackTrack(
        id: 'track-${DateTime.now().microsecondsSinceEpoch}',
        name: selected.name,
        path: selected.path,
      );

      setState(() {
        _soundtracks.insert(0, track);
        _selectedTrackId = track.id;
      });
    } finally {
      if (mounted) {
        setState(() {
          _isPickingTrack = false;
        });
      }
    }
  }

  void _selectTrack(String trackId) {
    setState(() {
      _selectedTrackId = trackId;
    });
  }

  LocalSoundtrackTrack? get _selectedTrack {
    final selectedId = _selectedTrackId;
    if (selectedId == null) {
      return _soundtracks.isNotEmpty ? _soundtracks.first : null;
    }
    return _soundtracks.where((track) => track.id == selectedId).firstOrNull;
  }

  Future<void> _previewTrack() async {
    final track = _selectedTrack;
    if (track == null || _isMusicBusy) {
      return;
    }
    await _runMusicAction(() => widget.musicPlaybackService.previewTrack(track));
  }

  Future<void> _playTrack() async {
    final track = _selectedTrack;
    if (track == null || _isMusicBusy) {
      return;
    }
    await _runMusicAction(() => widget.musicPlaybackService.playTrack(track));
  }

  Future<void> _pauseTrack() async {
    if (_isMusicBusy) {
      return;
    }
    await _runMusicAction(widget.musicPlaybackService.pause);
  }

  Future<void> _resumeTrack() async {
    if (_isMusicBusy) {
      return;
    }
    await _runMusicAction(widget.musicPlaybackService.resume);
  }

  Future<void> _stopTrack() async {
    if (_isMusicBusy) {
      return;
    }
    await _runMusicAction(widget.musicPlaybackService.stop);
  }

  Future<void> _toggleTrackLoop() async {
    if (_isMusicBusy) {
      return;
    }
    await _runMusicAction(
      () => widget.musicPlaybackService.setLoopEnabled(
        !_soundtrackSnapshot.isLoopEnabled,
      ),
    );
  }

  Future<void> _runMusicAction(Future<void> Function() action) async {
    setState(() {
      _isMusicBusy = true;
    });

    try {
      await action();
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _soundtrackSnapshot = _soundtrackSnapshot.copyWith(
          error: error.toString(),
        );
        _isMusicBusy = false;
      });
    }
  }

  DiceRollRecord _submitDiceRoll(String expression) {
    final record = widget.diceRoller.roll(
      expression,
      author: widget.currentUser.userName,
    );

    setState(() {
      _diceHistory.insert(0, record);
      _messages.add(
        ChatMessage.text(
          widget.currentUser.userName,
          record.chatMessage,
          self: true,
        ),
      );
    });

    return record;
  }

  void _clearDiceHistory() {
    setState(() {
      _diceHistory.clear();
    });
  }

  Future<void> _openProfileEditor() async {
    final draft = await showDialog<ProfileEditorDraft>(
      context: context,
      builder: (context) {
        return ProfileEditorDialog(
          user: widget.currentUser,
          imagePicker: widget.imagePicker,
        );
      },
    );

    if (draft == null) {
      return;
    }

    try {
      final updatedUser = await widget.authService.updateProfile(
        userId: widget.currentUser.userId,
        userName: draft.userName,
        avatar: draft.avatar,
        banner: draft.banner,
        bannerAlignmentY: draft.bannerAlignmentY,
      );

      if (!mounted) {
        return;
      }

      widget.onProfileUpdated(updatedUser);
    } on UserAuthException catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Row(
          children: [
            const AppRail(),
            Expanded(
              child: Column(
                children: [
                  SessionHeader(
                    currentUser: widget.currentUser,
                    onEditProfile: _openProfileEditor,
                    onLogout: widget.onLogout,
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          final compact = constraints.maxWidth < 1180;

                          if (compact) {
                            return CompactSessionLayout(
                              messages: _messages,
                              audioSnapshot: _audioSnapshot,
                              isAudioBusy: _isAudioBusy,
                              isBotPlaying: _isBotPlaying,
                              isMicMuted: _isMicMuted,
                              isSelfMonitoring: _isSelfMonitoring,
                              selfInputLevel: _selfInputLevel,
                              onMessageSubmitted: _sendMessage,
                              onImageRequested: _sendImage,
                              isPickingImage: _isPickingImage,
                              onRefreshAudio: _loadAudioSnapshot,
                              onPlayBotAudio: _playBotTestAudio,
                              onToggleSelfMonitoring: _toggleSelfMonitoring,
                              onInputSelected: _selectInput,
                              onOutputSelected: _selectOutput,
                              onToggleMute: _toggleMute,
                              currentUser: widget.currentUser,
                              onEditProfile: _openProfileEditor,
                              diceHistory: _diceHistory,
                              onDiceSubmitted: _submitDiceRoll,
                              onClearDiceHistory: _clearDiceHistory,
                              soundtracks: _soundtracks,
                              selectedTrackId: _selectedTrackId,
                              soundtrackSnapshot: _soundtrackSnapshot,
                              isMusicBusy: _isMusicBusy,
                              isPickingTrack: _isPickingTrack,
                              onAddTrack: _addSoundtrack,
                              onSelectTrack: _selectTrack,
                              onPreviewTrack: _previewTrack,
                              onPlayTrack: _playTrack,
                              onResumeTrack: _resumeTrack,
                              onPauseTrack: _pauseTrack,
                              onStopTrack: _stopTrack,
                              onToggleTrackLoop: _toggleTrackLoop,
                            );
                          }

                          return WideSessionLayout(
                            messages: _messages,
                            audioSnapshot: _audioSnapshot,
                            isAudioBusy: _isAudioBusy,
                            isBotPlaying: _isBotPlaying,
                            isMicMuted: _isMicMuted,
                            isSelfMonitoring: _isSelfMonitoring,
                            selfInputLevel: _selfInputLevel,
                            onMessageSubmitted: _sendMessage,
                            onImageRequested: _sendImage,
                            isPickingImage: _isPickingImage,
                            onRefreshAudio: _loadAudioSnapshot,
                            onPlayBotAudio: _playBotTestAudio,
                            onToggleSelfMonitoring: _toggleSelfMonitoring,
                            onInputSelected: _selectInput,
                            onOutputSelected: _selectOutput,
                            onToggleMute: _toggleMute,
                            currentUser: widget.currentUser,
                            onEditProfile: _openProfileEditor,
                            diceHistory: _diceHistory,
                            onDiceSubmitted: _submitDiceRoll,
                            onClearDiceHistory: _clearDiceHistory,
                            soundtracks: _soundtracks,
                            selectedTrackId: _selectedTrackId,
                            soundtrackSnapshot: _soundtrackSnapshot,
                            isMusicBusy: _isMusicBusy,
                            isPickingTrack: _isPickingTrack,
                            onAddTrack: _addSoundtrack,
                            onSelectTrack: _selectTrack,
                            onPreviewTrack: _previewTrack,
                            onPlayTrack: _playTrack,
                            onResumeTrack: _resumeTrack,
                            onPauseTrack: _pauseTrack,
                            onStopTrack: _stopTrack,
                            onToggleTrackLoop: _toggleTrackLoop,
                          );
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class WideSessionLayout extends StatelessWidget {
  const WideSessionLayout({
    required this.messages,
    required this.audioSnapshot,
    required this.isAudioBusy,
    required this.isBotPlaying,
    required this.isMicMuted,
    required this.isSelfMonitoring,
    required this.selfInputLevel,
    required this.onMessageSubmitted,
    required this.onImageRequested,
    required this.isPickingImage,
    required this.onRefreshAudio,
    required this.onPlayBotAudio,
    required this.onToggleSelfMonitoring,
    required this.onInputSelected,
    required this.onOutputSelected,
    required this.onToggleMute,
    required this.currentUser,
    required this.onEditProfile,
    required this.diceHistory,
    required this.onDiceSubmitted,
    required this.onClearDiceHistory,
    required this.soundtracks,
    required this.selectedTrackId,
    required this.soundtrackSnapshot,
    required this.isMusicBusy,
    required this.isPickingTrack,
    required this.onAddTrack,
    required this.onSelectTrack,
    required this.onPreviewTrack,
    required this.onPlayTrack,
    required this.onResumeTrack,
    required this.onPauseTrack,
    required this.onStopTrack,
    required this.onToggleTrackLoop,
    super.key,
  });

  final List<ChatMessage> messages;
  final AudioSnapshot audioSnapshot;
  final bool isAudioBusy;
  final bool isBotPlaying;
  final bool isMicMuted;
  final bool isSelfMonitoring;
  final double selfInputLevel;
  final ValueChanged<String> onMessageSubmitted;
  final Future<void> Function() onImageRequested;
  final bool isPickingImage;
  final Future<void> Function() onRefreshAudio;
  final Future<void> Function() onPlayBotAudio;
  final Future<void> Function() onToggleSelfMonitoring;
  final ValueChanged<String> onInputSelected;
  final ValueChanged<String> onOutputSelected;
  final VoidCallback onToggleMute;
  final CriticalUser currentUser;
  final Future<void> Function() onEditProfile;
  final List<DiceRollRecord> diceHistory;
  final DiceRollRecord Function(String expression) onDiceSubmitted;
  final VoidCallback onClearDiceHistory;
  final List<LocalSoundtrackTrack> soundtracks;
  final String? selectedTrackId;
  final SoundtrackPlaybackSnapshot soundtrackSnapshot;
  final bool isMusicBusy;
  final bool isPickingTrack;
  final Future<void> Function() onAddTrack;
  final ValueChanged<String> onSelectTrack;
  final Future<void> Function() onPreviewTrack;
  final Future<void> Function() onPlayTrack;
  final Future<void> Function() onResumeTrack;
  final Future<void> Function() onPauseTrack;
  final Future<void> Function() onStopTrack;
  final Future<void> Function() onToggleTrackLoop;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          width: 288,
          child: VoicePanel(
            snapshot: audioSnapshot,
            isAudioBusy: isAudioBusy,
            isBotPlaying: isBotPlaying,
            isMicMuted: isMicMuted,
            isSelfMonitoring: isSelfMonitoring,
            selfInputLevel: selfInputLevel,
            currentUser: currentUser,
            onRefreshAudio: onRefreshAudio,
            onPlayBotAudio: onPlayBotAudio,
            onToggleSelfMonitoring: onToggleSelfMonitoring,
            onInputSelected: onInputSelected,
            onOutputSelected: onOutputSelected,
            onToggleMute: onToggleMute,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: CenterColumn(
            messages: messages,
            onMessageSubmitted: onMessageSubmitted,
            onImageRequested: onImageRequested,
            isPickingImage: isPickingImage,
          ),
        ),
        const SizedBox(width: 12),
        SizedBox(
          width: 340,
          child: SideToolsPanel(
            currentUser: currentUser,
            onEditProfile: onEditProfile,
            soundtracks: soundtracks,
            selectedTrackId: selectedTrackId,
            soundtrackSnapshot: soundtrackSnapshot,
            isMusicBusy: isMusicBusy,
            isPickingTrack: isPickingTrack,
            onAddTrack: onAddTrack,
            onSelectTrack: onSelectTrack,
            onPreviewTrack: onPreviewTrack,
            onPlayTrack: onPlayTrack,
            onResumeTrack: onResumeTrack,
            onPauseTrack: onPauseTrack,
            onStopTrack: onStopTrack,
            onToggleTrackLoop: onToggleTrackLoop,
            diceHistory: diceHistory,
            onDiceSubmitted: onDiceSubmitted,
            onClearDiceHistory: onClearDiceHistory,
          ),
        ),
      ],
    );
  }
}

class CompactSessionLayout extends StatelessWidget {
  const CompactSessionLayout({
    required this.messages,
    required this.audioSnapshot,
    required this.isAudioBusy,
    required this.isBotPlaying,
    required this.isMicMuted,
    required this.isSelfMonitoring,
    required this.selfInputLevel,
    required this.onMessageSubmitted,
    required this.onImageRequested,
    required this.isPickingImage,
    required this.onRefreshAudio,
    required this.onPlayBotAudio,
    required this.onToggleSelfMonitoring,
    required this.onInputSelected,
    required this.onOutputSelected,
    required this.onToggleMute,
    required this.currentUser,
    required this.onEditProfile,
    required this.diceHistory,
    required this.onDiceSubmitted,
    required this.onClearDiceHistory,
    required this.soundtracks,
    required this.selectedTrackId,
    required this.soundtrackSnapshot,
    required this.isMusicBusy,
    required this.isPickingTrack,
    required this.onAddTrack,
    required this.onSelectTrack,
    required this.onPreviewTrack,
    required this.onPlayTrack,
    required this.onResumeTrack,
    required this.onPauseTrack,
    required this.onStopTrack,
    required this.onToggleTrackLoop,
    super.key,
  });

  final List<ChatMessage> messages;
  final AudioSnapshot audioSnapshot;
  final bool isAudioBusy;
  final bool isBotPlaying;
  final bool isMicMuted;
  final bool isSelfMonitoring;
  final double selfInputLevel;
  final ValueChanged<String> onMessageSubmitted;
  final Future<void> Function() onImageRequested;
  final bool isPickingImage;
  final Future<void> Function() onRefreshAudio;
  final Future<void> Function() onPlayBotAudio;
  final Future<void> Function() onToggleSelfMonitoring;
  final ValueChanged<String> onInputSelected;
  final ValueChanged<String> onOutputSelected;
  final VoidCallback onToggleMute;
  final CriticalUser currentUser;
  final Future<void> Function() onEditProfile;
  final List<DiceRollRecord> diceHistory;
  final DiceRollRecord Function(String expression) onDiceSubmitted;
  final VoidCallback onClearDiceHistory;
  final List<LocalSoundtrackTrack> soundtracks;
  final String? selectedTrackId;
  final SoundtrackPlaybackSnapshot soundtrackSnapshot;
  final bool isMusicBusy;
  final bool isPickingTrack;
  final Future<void> Function() onAddTrack;
  final ValueChanged<String> onSelectTrack;
  final Future<void> Function() onPreviewTrack;
  final Future<void> Function() onPlayTrack;
  final Future<void> Function() onResumeTrack;
  final Future<void> Function() onPauseTrack;
  final Future<void> Function() onStopTrack;
  final Future<void> Function() onToggleTrackLoop;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          height: 244,
          child: VoicePanel(
            snapshot: audioSnapshot,
            isAudioBusy: isAudioBusy,
            isBotPlaying: isBotPlaying,
            isMicMuted: isMicMuted,
            isSelfMonitoring: isSelfMonitoring,
            selfInputLevel: selfInputLevel,
            currentUser: currentUser,
            onRefreshAudio: onRefreshAudio,
            onPlayBotAudio: onPlayBotAudio,
            onToggleSelfMonitoring: onToggleSelfMonitoring,
            onInputSelected: onInputSelected,
            onOutputSelected: onOutputSelected,
            onToggleMute: onToggleMute,
          ),
        ),
        const SizedBox(height: 12),
        Expanded(
          child: Row(
            children: [
              Expanded(
                child: CenterColumn(
                  messages: messages,
                  onMessageSubmitted: onMessageSubmitted,
                  onImageRequested: onImageRequested,
                  isPickingImage: isPickingImage,
                ),
              ),
              const SizedBox(width: 12),
              SizedBox(
                width: 320,
                child: SideToolsPanel(
                  currentUser: currentUser,
                  onEditProfile: onEditProfile,
                  soundtracks: soundtracks,
                  selectedTrackId: selectedTrackId,
                  soundtrackSnapshot: soundtrackSnapshot,
                  isMusicBusy: isMusicBusy,
                  isPickingTrack: isPickingTrack,
                  onAddTrack: onAddTrack,
                  onSelectTrack: onSelectTrack,
                  onPreviewTrack: onPreviewTrack,
                  onPlayTrack: onPlayTrack,
                  onResumeTrack: onResumeTrack,
                  onPauseTrack: onPauseTrack,
                  onStopTrack: onStopTrack,
                  onToggleTrackLoop: onToggleTrackLoop,
                  diceHistory: diceHistory,
                  onDiceSubmitted: onDiceSubmitted,
                  onClearDiceHistory: onClearDiceHistory,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class AppRail extends StatelessWidget {
  const AppRail({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 72,
      color: const Color(0xFF0F1113),
      child: Column(
        children: [
          const SizedBox(height: 12),
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: const Color(0xFF2F7D6D),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.casino, color: Colors.white),
          ),
          const SizedBox(height: 22),
          const RailButton(
            icon: Icons.dashboard,
            selected: true,
            label: 'Sala',
          ),
          const RailButton(icon: Icons.chat_bubble, label: 'Chat'),
          const RailButton(icon: Icons.graphic_eq, label: 'Voz'),
          const RailButton(icon: Icons.music_note, label: 'Trilhas'),
          const RailButton(icon: Icons.shield, label: 'RPG'),
          const Spacer(),
          const RailButton(icon: Icons.settings, label: 'Ajustes'),
          const SizedBox(height: 12),
        ],
      ),
    );
  }
}

class RailButton extends StatelessWidget {
  const RailButton({
    required this.icon,
    required this.label,
    this.selected = false,
    super.key,
  });

  final IconData icon;
  final String label;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: label,
      child: Container(
        width: 44,
        height: 44,
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFF223D38) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: selected ? Border.all(color: const Color(0xFF55BCA4)) : null,
        ),
        child: Icon(
          icon,
          color: selected ? const Color(0xFF80DFC8) : const Color(0xFF9CA6A2),
          size: 22,
        ),
      ),
    );
  }
}

class SessionHeader extends StatelessWidget {
  const SessionHeader({
    required this.currentUser,
    required this.onEditProfile,
    required this.onLogout,
    super.key,
  });

  final CriticalUser currentUser;
  final Future<void> Function() onEditProfile;
  final Future<void> Function() onLogout;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 76,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Critical Talk',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Mesa: Ecos do Vale Cinzento',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: const Color(0xFFAEB8B5),
                  ),
                ),
              ],
            ),
          ),
          const HeaderPill(icon: Icons.lock, label: 'Sala privada'),
          const SizedBox(width: 8),
          const HeaderPill(icon: Icons.people, label: '5 online'),
          const SizedBox(width: 8),
          const IconToolButton(icon: Icons.copy, label: 'Copiar convite'),
          const SizedBox(width: 8),
          InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: onEditProfile,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              child: Row(
                children: [
                  AvatarBadge(
                    initials: currentUser.initials,
                    color: const Color(0xFF55BCA4),
                    size: 34,
                    imageBytes: currentUser.profile.avatar?.bytes,
                  ),
                  const SizedBox(width: 8),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 148),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          currentUser.userName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                        Text(
                          currentUser.maskedId,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFFAEB8B5),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          IconToolButton(
            icon: Icons.logout,
            label: 'Sair',
            onPressed: onLogout,
          ),
        ],
      ),
    );
  }
}

class HeaderPill extends StatelessWidget {
  const HeaderPill({required this.icon, required this.label, super.key});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 36,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF202326),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF30363A)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 17, color: const Color(0xFFA9CFC4)),
          const SizedBox(width: 8),
          Text(label, style: const TextStyle(fontSize: 13)),
        ],
      ),
    );
  }
}

class VoicePanel extends StatelessWidget {
  const VoicePanel({
    required this.snapshot,
    required this.isAudioBusy,
    required this.isBotPlaying,
    required this.isMicMuted,
    required this.isSelfMonitoring,
    required this.selfInputLevel,
    required this.currentUser,
    required this.onRefreshAudio,
    required this.onPlayBotAudio,
    required this.onToggleSelfMonitoring,
    required this.onInputSelected,
    required this.onOutputSelected,
    required this.onToggleMute,
    super.key,
  });

  final AudioSnapshot snapshot;
  final bool isAudioBusy;
  final bool isBotPlaying;
  final bool isMicMuted;
  final bool isSelfMonitoring;
  final double selfInputLevel;
  final CriticalUser currentUser;
  final Future<void> Function() onRefreshAudio;
  final Future<void> Function() onPlayBotAudio;
  final Future<void> Function() onToggleSelfMonitoring;
  final ValueChanged<String> onInputSelected;
  final ValueChanged<String> onOutputSelected;
  final VoidCallback onToggleMute;

  static const _partyMembers = [
    ParticipantView(
      name: 'Mestre',
      initials: 'ME',
      status: 'Na chamada',
      color: Color(0xFF55BCA4),
    ),
    ParticipantView(
      name: 'Mira',
      initials: 'MI',
      status: 'Microfone aberto',
      color: Color(0xFFE6B450),
    ),
    ParticipantView(
      name: 'Darian',
      initials: 'DA',
      status: 'Pronto para combate',
      color: Color(0xFF9BA7FF),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final participants = [
      ParticipantView(
        name: currentUser.userName,
        initials: currentUser.initials,
        status: isMicMuted
            ? 'Silenciado'
            : isSelfMonitoring
            ? 'Retorno local ativo'
            : selfInputLevel > 0.08
            ? 'Falando agora'
            : 'Microfone aberto',
        color: const Color(0xFF55BCA4),
        speaking: !isMicMuted && selfInputLevel > 0.08,
        level: isMicMuted ? 0 : selfInputLevel,
        isSelf: true,
        imageBytes: currentUser.profile.avatar?.bytes,
      ),
      ..._partyMembers,
      ParticipantView(
        name: 'Bot de Audio',
        initials: 'BT',
        status: isBotPlaying ? 'Emitindo teste' : 'Aguardando teste',
        color: const Color(0xFFDE706B),
        speaking: isBotPlaying,
        level: isBotPlaying ? 0.85 : 0,
      ),
    ];

    return Panel(
      title: 'Voz',
      trailing: IconToolButton(
        icon: Icons.refresh,
        label: 'Atualizar audio',
        onPressed: isAudioBusy ? null : onRefreshAudio,
      ),
      child: SingleChildScrollView(
        child: Column(
          children: [
            DevicePickerRow(
              icon: Icons.mic,
              label: 'Microfone',
              devices: snapshot.inputs,
              selectedId: snapshot.defaultInputId,
              enabled: snapshot.inputs.isNotEmpty && !isAudioBusy,
              emptyLabel: snapshot.serverReachable
                  ? 'Nenhum microfone disponivel'
                  : 'PulseAudio indisponivel',
              onChanged: onInputSelected,
            ),
            const SizedBox(height: 8),
            DevicePickerRow(
              icon: Icons.volume_up,
              label: 'Saida',
              devices: snapshot.outputs,
              selectedId: snapshot.defaultOutputId,
              enabled: snapshot.outputs.isNotEmpty && !isAudioBusy,
              emptyLabel: snapshot.serverReachable
                  ? 'Nenhuma saida disponivel'
                  : 'PulseAudio indisponivel',
              onChanged: onOutputSelected,
            ),
            if (snapshot.error != null) ...[
              const SizedBox(height: 8),
              ErrorStrip(message: snapshot.error!),
            ],
            const SizedBox(height: 12),
            ...participants.map(
              (participant) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: ParticipantTile(participant: participant),
              ),
            ),
            const SizedBox(height: 4),
            VoiceControls(
              isMicMuted: isMicMuted,
              isAudioBusy: isAudioBusy,
              isBotPlaying: isBotPlaying,
              isSelfMonitoring: isSelfMonitoring,
              onToggleMute: onToggleMute,
              onPlayBotAudio: onPlayBotAudio,
              onToggleSelfMonitoring: onToggleSelfMonitoring,
            ),
          ],
        ),
      ),
    );
  }
}

class DevicePickerRow extends StatelessWidget {
  const DevicePickerRow({
    required this.icon,
    required this.label,
    required this.devices,
    required this.selectedId,
    required this.enabled,
    required this.emptyLabel,
    required this.onChanged,
    super.key,
  });

  final IconData icon;
  final String label;
  final List<AudioDevice> devices;
  final String? selectedId;
  final bool enabled;
  final String emptyLabel;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 50,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1D20),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: const Color(0xFF9FC5BA)),
          const SizedBox(width: 10),
          SizedBox(
            width: 84,
            child: Text(label, style: const TextStyle(fontSize: 13)),
          ),
          Expanded(
            child: enabled
                ? DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: devices.any((device) => device.id == selectedId)
                          ? selectedId
                          : devices.first.id,
                      isExpanded: true,
                      dropdownColor: const Color(0xFF202326),
                      items: devices
                          .map(
                            (device) => DropdownMenuItem<String>(
                              value: device.id,
                              child: Text(
                                device.summary,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: (value) {
                        if (value != null) {
                          onChanged(value);
                        }
                      },
                    ),
                  )
                : Text(
                    emptyLabel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFF8E9996),
                      fontSize: 13,
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class ErrorStrip extends StatelessWidget {
  const ErrorStrip({required this.message, super.key});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF4A2323),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        message,
        maxLines: 3,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(color: Color(0xFFFFC0BA), fontSize: 12),
      ),
    );
  }
}

class SpeakingMeter extends StatelessWidget {
  const SpeakingMeter({required this.level, super.key});

  final double level;

  @override
  Widget build(BuildContext context) {
    final normalized = level.clamp(0.0, 1.0);

    return SizedBox(
      height: 28,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisAlignment: MainAxisAlignment.end,
        children: List.generate(4, (index) {
          final threshold = (index + 1) / 4;
          final active = normalized >= threshold - 0.12;
          final baseHeight = 7.0 + (index * 4);

          return Container(
            width: 4,
            height: active ? baseHeight + 4 : baseHeight,
            margin: EdgeInsets.only(left: index == 0 ? 0 : 2),
            decoration: BoxDecoration(
              color: active ? const Color(0xFF80DFC8) : const Color(0xFF42514C),
              borderRadius: BorderRadius.circular(99),
            ),
          );
        }),
      ),
    );
  }
}

class ParticipantTile extends StatelessWidget {
  const ParticipantTile({required this.participant, super.key});

  final ParticipantView participant;

  @override
  Widget build(BuildContext context) {
    final tileColor = participant.speaking
        ? const Color(0xFF203B36)
        : const Color(0xFF1A1D20);
    final borderColor = participant.speaking
        ? const Color(0xFF55BCA4)
        : const Color(0xFF2A2F33);

    return Container(
      height: 62,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: tileColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: borderColor),
        boxShadow: participant.speaking
            ? const [
                BoxShadow(
                  color: Color(0x4439C7A6),
                  blurRadius: 12,
                  spreadRadius: 1,
                ),
              ]
            : null,
      ),
      child: Row(
        children: [
          AvatarBadge(
            initials: participant.initials,
            color: participant.color,
            size: 42,
            imageBytes: participant.imageBytes,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        participant.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                    if (participant.isSelf) ...[
                      const SizedBox(width: 8),
                      const Text(
                        'VOCE',
                        style: TextStyle(
                          fontSize: 10,
                          color: Color(0xFFBFE9DD),
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  participant.status,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFFAEB8B5),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(width: 26, child: SpeakingMeter(level: participant.level)),
        ],
      ),
    );
  }
}

class VoiceControls extends StatelessWidget {
  const VoiceControls({
    required this.isMicMuted,
    required this.isAudioBusy,
    required this.isBotPlaying,
    required this.isSelfMonitoring,
    required this.onToggleMute,
    required this.onPlayBotAudio,
    required this.onToggleSelfMonitoring,
    super.key,
  });

  final bool isMicMuted;
  final bool isAudioBusy;
  final bool isBotPlaying;
  final bool isSelfMonitoring;
  final VoidCallback onToggleMute;
  final Future<void> Function() onPlayBotAudio;
  final Future<void> Function() onToggleSelfMonitoring;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: FilledButton.icon(
            onPressed: onToggleMute,
            icon: Icon(isMicMuted ? Icons.mic_off : Icons.mic),
            label: Text(isMicMuted ? 'Silenciado' : 'Aberto'),
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(42),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Tooltip(
          message: isSelfMonitoring
              ? 'Desligar retorno local'
              : 'Ouvir minha propria voz',
          child: SizedBox(
            width: 44,
            height: 42,
            child: FilledButton(
              onPressed: isAudioBusy ? null : onToggleSelfMonitoring,
              style: FilledButton.styleFrom(
                padding: EdgeInsets.zero,
                backgroundColor: isSelfMonitoring
                    ? const Color(0xFF55BCA4)
                    : const Color(0xFF2B3135),
                foregroundColor: isSelfMonitoring
                    ? const Color(0xFF10211D)
                    : Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: Icon(
                isSelfMonitoring ? Icons.hearing_disabled : Icons.hearing,
                size: 20,
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          height: 42,
          child: FilledButton.icon(
            onPressed: isAudioBusy || isBotPlaying ? null : onPlayBotAudio,
            icon: const Icon(Icons.play_circle),
            label: const Text('Bot'),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFE6B450),
              foregroundColor: const Color(0xFF1A1D20),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class CenterColumn extends StatelessWidget {
  const CenterColumn({
    required this.messages,
    required this.onMessageSubmitted,
    required this.onImageRequested,
    required this.isPickingImage,
    super.key,
  });

  final List<ChatMessage> messages;
  final ValueChanged<String> onMessageSubmitted;
  final Future<void> Function() onImageRequested;
  final bool isPickingImage;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const SizedBox(height: 164, child: SceneBanner()),
        const SizedBox(height: 12),
        Expanded(
          child: ChatPanel(
            messages: messages,
            onImageRequested: onImageRequested,
            isPickingImage: isPickingImage,
          ),
        ),
        const SizedBox(height: 12),
        MessageComposer(
          onSubmitted: onMessageSubmitted,
          onImageRequested: onImageRequested,
          isPickingImage: isPickingImage,
        ),
      ],
    );
  }
}

class SceneBanner extends StatelessWidget {
  const SceneBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF30363A)),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Color(0xFF233934),
                  Color(0xFF292622),
                  Color(0xFF3B3338),
                ],
              ),
            ),
          ),
          Positioned(
            left: 18,
            bottom: 18,
            right: 18,
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Ruinas de Eldora',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.headlineSmall
                            ?.copyWith(
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0,
                            ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Noite chuvosa - tensao media',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: Color(0xFFD7DDD9)),
                      ),
                    ],
                  ),
                ),
                IconToolButton(icon: Icons.image, label: 'Trocar cena'),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class ChatPanel extends StatefulWidget {
  const ChatPanel({
    required this.messages,
    required this.onImageRequested,
    required this.isPickingImage,
    super.key,
  });

  final List<ChatMessage> messages;
  final Future<void> Function() onImageRequested;
  final bool isPickingImage;

  @override
  State<ChatPanel> createState() => _ChatPanelState();
}

class _ChatPanelState extends State<ChatPanel> {
  late final ScrollController _scrollController;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
  }

  @override
  void didUpdateWidget(covariant ChatPanel oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.messages.length != oldWidget.messages.length) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    if (!_scrollController.hasClients) {
      return;
    }

    _scrollController.jumpTo(_scrollController.position.minScrollExtent);
  }

  @override
  Widget build(BuildContext context) {
    return Panel(
      title: 'Chat',
      trailing: Row(
        children: [
          CounterBadge(text: '${widget.messages.length} mensagens'),
          const SizedBox(width: 8),
          IconToolButton(
            icon: Icons.image,
            label: 'Enviar imagem',
            onPressed: widget.isPickingImage ? null : widget.onImageRequested,
          ),
        ],
      ),
      child: ListView.separated(
        controller: _scrollController,
        reverse: true,
        itemCount: widget.messages.length,
        separatorBuilder: (_, _) => const SizedBox(height: 10),
        itemBuilder: (context, index) {
          final message = widget.messages[widget.messages.length - index - 1];

          return ChatBubble(message: message);
        },
      ),
    );
  }
}

class ChatBubble extends StatelessWidget {
  const ChatBubble({required this.message, super.key});

  final ChatMessage message;

  @override
  Widget build(BuildContext context) {
    final initials = message.author.characters
        .take(2)
        .toString()
        .toUpperCase()
        .padRight(2, ' ');
    final bubbleColor = message.self
        ? const Color(0xFF223D38)
        : const Color(0xFF1A1D20);
    final borderColor = message.self
        ? const Color(0xFF356F62)
        : const Color(0xFF2A2F33);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      textDirection: message.self ? TextDirection.rtl : TextDirection.ltr,
      children: [
        AvatarBadge(
          initials: initials,
          color: message.self ? const Color(0xFF55BCA4) : message.color,
          size: 34,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: bubbleColor,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: borderColor),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  message.author,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    color: Color(0xFFBFE9DD),
                  ),
                ),
                const SizedBox(height: 6),
                if (message.text != null)
                  ObsidianMarkdownBody(markdown: message.text!)
                else if (message.imageBytes != null)
                  ChatImageBubble(
                    imageName: message.imageName ?? 'imagem',
                    imageBytes: message.imageBytes!,
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class ObsidianMarkdownBody extends StatelessWidget {
  const ObsidianMarkdownBody({required this.markdown, super.key});

  final String markdown;

  @override
  Widget build(BuildContext context) {
    return MarkdownBody(
      data: sanitizeObsidianMarkdown(markdown),
      selectable: false,
      shrinkWrap: true,
      onTapLink: (_, _, _) {},
      styleSheet: MarkdownStyleSheet.fromTheme(Theme.of(context)).copyWith(
        p: const TextStyle(height: 1.45, fontSize: 14),
        code: TextStyle(
          backgroundColor: const Color(0xFF151719),
          color: Theme.of(context).colorScheme.secondary,
          fontFamily: 'monospace',
          fontSize: 13,
        ),
        codeblockDecoration: BoxDecoration(
          color: const Color(0xFF151719),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFF2A2F33)),
        ),
        blockquoteDecoration: BoxDecoration(
          color: const Color(0xFF171A1C),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFF2A2F33)),
        ),
        listBullet: const TextStyle(
          color: Color(0xFFBFE9DD),
          fontWeight: FontWeight.w700,
        ),
        a: const TextStyle(
          color: Color(0xFFBFE9DD),
          decoration: TextDecoration.none,
        ),
      ),
    );
  }
}

class ChatImageBubble extends StatelessWidget {
  const ChatImageBubble({
    required this.imageName,
    required this.imageBytes,
    super.key,
  });

  final String imageName;
  final Uint8List imageBytes;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxHeight: 220,
              minHeight: 72,
              maxWidth: 360,
            ),
            child: Image.memory(
              imageBytes,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) {
                return Container(
                  height: 96,
                  alignment: Alignment.center,
                  color: const Color(0xFF151719),
                  child: const Text('Falha ao carregar imagem'),
                );
              },
            ),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.photo, size: 16, color: Color(0xFF9FC5BA)),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                imageName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Color(0xFFAEB8B5), fontSize: 12),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class MessageComposer extends StatelessWidget {
  const MessageComposer({
    required this.onSubmitted,
    required this.onImageRequested,
    required this.isPickingImage,
    super.key,
  });

  static const maxCharacters = 2000;

  final ValueChanged<String> onSubmitted;
  final Future<void> Function() onImageRequested;
  final bool isPickingImage;

  @override
  Widget build(BuildContext context) {
    return _MessageComposerBody(
      onSubmitted: onSubmitted,
      onImageRequested: onImageRequested,
      isPickingImage: isPickingImage,
    );
  }
}

class _MessageComposerBody extends StatefulWidget {
  const _MessageComposerBody({
    required this.onSubmitted,
    required this.onImageRequested,
    required this.isPickingImage,
  });

  final ValueChanged<String> onSubmitted;
  final Future<void> Function() onImageRequested;
  final bool isPickingImage;

  @override
  State<_MessageComposerBody> createState() => _MessageComposerBodyState();
}

class _MessageComposerBodyState extends State<_MessageComposerBody> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController()..addListener(_handleTextChanged);
  }

  @override
  void dispose() {
    _controller
      ..removeListener(_handleTextChanged)
      ..dispose();
    super.dispose();
  }

  void _handleTextChanged() {
    setState(() {});
  }

  void _submit() {
    final text = _controller.text;
    final trimmed = text.trim();

    if (trimmed.isEmpty || trimmed.length > MessageComposer.maxCharacters) {
      return;
    }

    widget.onSubmitted(text);
    _controller.clear();
  }

  @override
  Widget build(BuildContext context) {
    final currentLength = _controller.text.trim().length;
    final overLimit = currentLength > MessageComposer.maxCharacters;

    return Container(
      height: 58,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: const Color(0xFF202326),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF30363A)),
      ),
      child: Row(
        children: [
          IconToolButton(
            icon: Icons.add_photo_alternate,
            label: 'Anexar imagem',
            onPressed: widget.isPickingImage ? null : widget.onImageRequested,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: _controller,
              maxLines: 1,
              maxLength: MessageComposer.maxCharacters,
              onSubmitted: (_) => _submit(),
              textInputAction: TextInputAction.send,
              decoration: InputDecoration(
                hintText: 'Mensagem para a mesa',
                counterText: '',
                filled: true,
                fillColor: const Color(0xFF151719),
                contentPadding: const EdgeInsets.symmetric(horizontal: 14),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          CounterBadge(
            text: '$currentLength/${MessageComposer.maxCharacters}',
            danger: overLimit,
          ),
          const SizedBox(width: 8),
          IconToolButton(
            icon: Icons.send,
            label: 'Enviar',
            onPressed: overLimit || currentLength == 0 ? null : _submit,
          ),
        ],
      ),
    );
  }
}

class SideToolsPanel extends StatelessWidget {
  const SideToolsPanel({
    required this.currentUser,
    required this.onEditProfile,
    required this.soundtracks,
    required this.selectedTrackId,
    required this.soundtrackSnapshot,
    required this.isMusicBusy,
    required this.isPickingTrack,
    required this.onAddTrack,
    required this.onSelectTrack,
    required this.onPreviewTrack,
    required this.onPlayTrack,
    required this.onResumeTrack,
    required this.onPauseTrack,
    required this.onStopTrack,
    required this.onToggleTrackLoop,
    required this.diceHistory,
    required this.onDiceSubmitted,
    required this.onClearDiceHistory,
    super.key,
  });

  final CriticalUser currentUser;
  final Future<void> Function() onEditProfile;
  final List<LocalSoundtrackTrack> soundtracks;
  final String? selectedTrackId;
  final SoundtrackPlaybackSnapshot soundtrackSnapshot;
  final bool isMusicBusy;
  final bool isPickingTrack;
  final Future<void> Function() onAddTrack;
  final ValueChanged<String> onSelectTrack;
  final Future<void> Function() onPreviewTrack;
  final Future<void> Function() onPlayTrack;
  final Future<void> Function() onResumeTrack;
  final Future<void> Function() onPauseTrack;
  final Future<void> Function() onStopTrack;
  final Future<void> Function() onToggleTrackLoop;
  final List<DiceRollRecord> diceHistory;
  final DiceRollRecord Function(String expression) onDiceSubmitted;
  final VoidCallback onClearDiceHistory;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          flex: 3,
          child: MusicPanel(
            tracks: soundtracks,
            selectedTrackId: selectedTrackId,
            snapshot: soundtrackSnapshot,
            isBusy: isMusicBusy,
            isPickingTrack: isPickingTrack,
            onAddTrack: onAddTrack,
            onSelectTrack: onSelectTrack,
            onPreviewTrack: onPreviewTrack,
            onPlayTrack: onPlayTrack,
            onResumeTrack: onResumeTrack,
            onPauseTrack: onPauseTrack,
            onStopTrack: onStopTrack,
            onToggleTrackLoop: onToggleTrackLoop,
          ),
        ),
        const SizedBox(height: 12),
        Expanded(
          flex: 2,
          child: DicePanel(
            history: diceHistory,
            onSubmitted: onDiceSubmitted,
            onClearHistory: onClearDiceHistory,
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 164,
          child: ProfilePanel(
            currentUser: currentUser,
            onEditProfile: onEditProfile,
          ),
        ),
      ],
    );
  }
}

class MusicPanel extends StatelessWidget {
  const MusicPanel({
    required this.tracks,
    required this.selectedTrackId,
    required this.snapshot,
    required this.isBusy,
    required this.isPickingTrack,
    required this.onAddTrack,
    required this.onSelectTrack,
    required this.onPreviewTrack,
    required this.onPlayTrack,
    required this.onResumeTrack,
    required this.onPauseTrack,
    required this.onStopTrack,
    required this.onToggleTrackLoop,
    super.key,
  });

  final List<LocalSoundtrackTrack> tracks;
  final String? selectedTrackId;
  final SoundtrackPlaybackSnapshot snapshot;
  final bool isBusy;
  final bool isPickingTrack;
  final Future<void> Function() onAddTrack;
  final ValueChanged<String> onSelectTrack;
  final Future<void> Function() onPreviewTrack;
  final Future<void> Function() onPlayTrack;
  final Future<void> Function() onResumeTrack;
  final Future<void> Function() onPauseTrack;
  final Future<void> Function() onStopTrack;
  final Future<void> Function() onToggleTrackLoop;

  @override
  Widget build(BuildContext context) {
    final activeTrack = tracks
        .where((track) => track.id == snapshot.activeTrackId)
        .firstOrNull;
    final selectedTrack = tracks
        .where((track) => track.id == selectedTrackId)
        .firstOrNull;

    return Panel(
      title: 'Trilha',
      trailing: IconToolButton(
        icon: Icons.playlist_add,
        label: 'Adicionar trilha',
        onPressed: isPickingTrack ? null : onAddTrack,
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF1A1D20),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFF2A2F33)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    activeTrack?.name ?? selectedTrack?.name ?? 'Nenhuma trilha',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 6),
                  LinearProgressIndicator(
                    value: snapshot.progress,
                    minHeight: 5,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${snapshot.scopeLabel}  ${formatDuration(snapshot.position)} / ${formatDuration(snapshot.duration)}',
                    style: const TextStyle(fontSize: 12),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                IconToolButton(
                  icon: Icons.headphones,
                  label: 'Preview',
                  onPressed: tracks.isEmpty || isBusy ? null : onPreviewTrack,
                ),
                const SizedBox(width: 8),
                IconToolButton(
                  icon: snapshot.isPaused ? Icons.play_arrow : Icons.campaign,
                  label: snapshot.isPaused ? 'Retomar' : 'Tocar na sala',
                  onPressed: tracks.isEmpty || isBusy
                      ? null
                      : snapshot.isPaused
                      ? onResumeTrack
                      : onPlayTrack,
                ),
                const SizedBox(width: 8),
                IconToolButton(
                  icon: Icons.pause,
                  label: 'Pausar',
                  onPressed: !snapshot.isPlaying || isBusy ? null : onPauseTrack,
                ),
                const SizedBox(width: 8),
                IconToolButton(
                  icon: Icons.stop,
                  label: 'Parar',
                  onPressed: !snapshot.hasActiveTrack || isBusy ? null : onStopTrack,
                ),
                const SizedBox(width: 8),
                IconToolButton(
                  icon: snapshot.isLoopEnabled ? Icons.repeat_one : Icons.repeat,
                  label: 'Loop simples',
                  onPressed: tracks.isEmpty || isBusy ? null : onToggleTrackLoop,
                ),
              ],
            ),
            if (snapshot.error != null) ...[
              const SizedBox(height: 10),
              ErrorStrip(message: snapshot.error!),
            ],
            const SizedBox(height: 12),
            if (tracks.isEmpty)
              const EmptyMusicLibrary()
            else
              Column(
                children: [
                  for (var index = 0; index < tracks.length; index++) ...[
                    TrackTile(
                      track: tracks[index],
                      selected: tracks[index].id == selectedTrackId,
                      active: tracks[index].id == snapshot.activeTrackId,
                      subtitle: tracks[index].id == snapshot.activeTrackId
                          ? snapshot.scopeLabel
                          : 'Arquivo local',
                      onTap: () => onSelectTrack(tracks[index].id),
                    ),
                    if (index != tracks.length - 1) const SizedBox(height: 8),
                  ],
                ],
              ),
          ],
        ),
      ),
    );
  }
}

class TrackTile extends StatelessWidget {
  const TrackTile({
    required this.track,
    required this.subtitle,
    required this.onTap,
    this.selected = false,
    this.active = false,
    super.key,
  });

  final LocalSoundtrackTrack track;
  final String subtitle;
  final VoidCallback onTap;
  final bool selected;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: onTap,
      child: Container(
        height: 54,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFF223D38) : const Color(0xFF1A1D20),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: selected ? const Color(0xFF356F62) : const Color(0xFF2A2F33),
          ),
        ),
        child: Row(
          children: [
            Icon(
              active ? Icons.graphic_eq : Icons.music_note,
              size: 18,
              color: active ? const Color(0xFF80DFC8) : const Color(0xFFE6B450),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    track.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFFAEB8B5),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class EmptyMusicLibrary extends StatelessWidget {
  const EmptyMusicLibrary({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 92,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: const Color(0xFF1A1D20),
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Padding(
        padding: EdgeInsets.symmetric(horizontal: 16),
        child: Text(
          'Adicione um arquivo local para habilitar preview, play, pause, stop e loop.',
          textAlign: TextAlign.center,
          style: TextStyle(color: Color(0xFFAEB8B5), height: 1.4),
        ),
      ),
    );
  }
}

class DicePanel extends StatelessWidget {
  const DicePanel({
    required this.history,
    required this.onSubmitted,
    required this.onClearHistory,
    super.key,
  });

  final List<DiceRollRecord> history;
  final DiceRollRecord Function(String expression) onSubmitted;
  final VoidCallback onClearHistory;

  @override
  Widget build(BuildContext context) {
    return Panel(
      title: 'Dados',
      trailing: IconToolButton(
        icon: Icons.delete_sweep,
        label: 'Limpar historico',
        onPressed: history.isEmpty ? null : onClearHistory,
      ),
      child: DicePanelBody(history: history, onSubmitted: onSubmitted),
    );
  }
}

class DicePanelBody extends StatefulWidget {
  const DicePanelBody({
    required this.history,
    required this.onSubmitted,
    super.key,
  });

  final List<DiceRollRecord> history;
  final DiceRollRecord Function(String expression) onSubmitted;

  @override
  State<DicePanelBody> createState() => _DicePanelBodyState();
}

class _DicePanelBodyState extends State<DicePanelBody> {
  late final TextEditingController _controller;
  String? _error;

  static const _shortcuts = ['d4', 'd6', 'd8', 'd20', '2d6+3', '4d6kh3'];

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit([String? shortcut]) {
    final expression = (shortcut ?? _controller.text).trim();
    if (expression.isEmpty) {
      return;
    }

    try {
      widget.onSubmitted(expression);
      setState(() {
        _error = null;
      });
      if (shortcut == null) {
        _controller.clear();
      }
    } on DiceRollException catch (error) {
      setState(() {
        _error = error.message;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final latest = widget.history.isNotEmpty ? widget.history.first : null;

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: _shortcuts
                .map(
                  (shortcut) => DiceChip(
                    label: shortcut,
                    onPressed: () {
                      _controller.text = shortcut;
                      _submit(shortcut);
                    },
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _controller,
                  onSubmitted: (_) => _submit(),
                  decoration: InputDecoration(
                    hintText: '1d20+5',
                    filled: true,
                    fillColor: const Color(0xFF151719),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                height: 48,
                child: FilledButton.icon(
                  onPressed: () => _submit(),
                  icon: const Icon(Icons.casino),
                  label: const Text('Rolar'),
                  style: FilledButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
            ],
          ),
          if (_error != null) ...[
            const SizedBox(height: 10),
            ErrorStrip(message: _error!),
          ],
          if (latest != null) ...[
            const SizedBox(height: 10),
            DiceResultCard(record: latest, highlight: true),
          ],
          const SizedBox(height: 10),
          Row(
            children: [
              const Text(
                'Historico',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12),
              ),
              const Spacer(),
              CounterBadge(text: '${widget.history.length} rolagens'),
            ],
          ),
          const SizedBox(height: 8),
          if (widget.history.isEmpty)
            Container(
              height: 72,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: const Color(0xFF1A1D20),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                'Sem rolagens ainda',
                style: TextStyle(color: Color(0xFFAEB8B5)),
              ),
            )
          else
            Column(
              children: [
                for (var index = 0; index < widget.history.length; index++) ...[
                  DiceResultCard(record: widget.history[index]),
                  if (index != widget.history.length - 1)
                    const SizedBox(height: 8),
                ],
              ],
            ),
        ],
      ),
    );
  }
}

class DiceChip extends StatelessWidget {
  const DiceChip({required this.label, required this.onPressed, super.key});

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 62,
      height: 34,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          padding: EdgeInsets.zero,
          backgroundColor: const Color(0xFF223D38),
          foregroundColor: Colors.white,
          side: const BorderSide(color: Color(0xFF356F62)),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        child: Text(label, style: const TextStyle(fontWeight: FontWeight.w800)),
      ),
    );
  }
}

class DiceResultCard extends StatelessWidget {
  const DiceResultCard({
    required this.record,
    this.highlight = false,
    super.key,
  });

  final DiceRollRecord record;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: highlight ? const Color(0xFF223D38) : const Color(0xFF1A1D20),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: highlight ? const Color(0xFF356F62) : const Color(0xFF2A2F33),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '${record.author} rolou ${record.total}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
              Text(
                record.timestampLabel,
                style: const TextStyle(color: Color(0xFFAEB8B5), fontSize: 11),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            record.summaryLabel,
            style: const TextStyle(color: Color(0xFFBFE9DD), fontSize: 12),
          ),
          const SizedBox(height: 4),
          Text(
            record.breakdownLabel,
            style: const TextStyle(color: Color(0xFFAEB8B5), fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class ProfilePanel extends StatelessWidget {
  const ProfilePanel({
    required this.currentUser,
    required this.onEditProfile,
    super.key,
  });

  final CriticalUser currentUser;
  final Future<void> Function() onEditProfile;

  @override
  Widget build(BuildContext context) {
    return Panel(
      title: 'Perfil',
      trailing: IconToolButton(
        icon: Icons.edit,
        label: 'Editar perfil',
        onPressed: onEditProfile,
      ),
      child: Column(
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (currentUser.profile.banner?.bytes != null)
                    Image.memory(
                      currentUser.profile.banner!.bytes,
                      fit: BoxFit.cover,
                      alignment: Alignment(
                        0,
                        currentUser.profile.bannerAlignmentY,
                      ),
                      errorBuilder: (_, _, _) => _profileBannerFallback(),
                    )
                  else
                    _profileBannerFallback(),
                  Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Colors.transparent, Color(0xCC151719)],
                      ),
                    ),
                  ),
                  Positioned(
                    left: 10,
                    right: 10,
                    bottom: 10,
                    child: Row(
                      children: [
                        AvatarBadge(
                          initials: currentUser.initials,
                          color: const Color(0xFF55BCA4),
                          size: 54,
                          imageBytes: currentUser.profile.avatar?.bytes,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                currentUser.userName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 15,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                currentUser.maskedId,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Color(0xFFAEB8B5),
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CounterBadge(
                text:
                    'perfis futuros: ${currentUser.profile.profileIds.length}',
              ),
              const SizedBox(height: 6),
              Text(
                currentUser.profile.banner?.fileName ?? 'banner padrao',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Color(0xFFAEB8B5), fontSize: 12),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _profileBannerFallback() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF243B36), Color(0xFF1B2023), Color(0xFF3E3134)],
        ),
      ),
    );
  }
}

class ProfileEditorDraft {
  const ProfileEditorDraft({
    required this.userName,
    required this.avatar,
    required this.banner,
    required this.bannerAlignmentY,
  });

  final String userName;
  final UserMedia? avatar;
  final UserMedia? banner;
  final double bannerAlignmentY;
}

class ProfileEditorDialog extends StatefulWidget {
  const ProfileEditorDialog({
    required this.user,
    required this.imagePicker,
    super.key,
  });

  final CriticalUser user;
  final ChatImagePicker imagePicker;

  @override
  State<ProfileEditorDialog> createState() => _ProfileEditorDialogState();
}

class _ProfileEditorDialogState extends State<ProfileEditorDialog> {
  late final TextEditingController _userNameController;
  late UserMedia? _avatar;
  late UserMedia? _banner;
  late double _bannerAlignmentY;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _userNameController = TextEditingController(text: widget.user.userName);
    _avatar = widget.user.profile.avatar;
    _banner = widget.user.profile.banner;
    _bannerAlignmentY = widget.user.profile.bannerAlignmentY;
  }

  @override
  void dispose() {
    _userNameController.dispose();
    super.dispose();
  }

  Future<void> _pickAvatar() async {
    setState(() {
      _busy = true;
    });

    try {
      final selected = await widget.imagePicker();
      if (!mounted || selected == null) {
        return;
      }

      setState(() {
        _avatar = UserMedia(fileName: selected.name, bytes: selected.bytes);
      });
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
        });
      }
    }
  }

  Future<void> _pickBanner() async {
    setState(() {
      _busy = true;
    });

    try {
      final selected = await widget.imagePicker();
      if (!mounted || selected == null) {
        return;
      }

      setState(() {
        _banner = UserMedia(fileName: selected.name, bytes: selected.bytes);
      });
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Editar perfil'),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              LabeledTextField(
                controller: _userNameController,
                label: 'Nome de usuario',
                hintText: 'rogerin',
              ),
              const SizedBox(height: 16),
              const Text(
                'ID fixo mascarado',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              CounterBadge(text: widget.user.maskedId),
              const SizedBox(height: 16),
              const Text(
                'Avatar',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  AvatarBadge(
                    initials: _userNameController.text.trim().isEmpty
                        ? widget.user.initials
                        : _userNameController.text
                              .trim()
                              .substring(
                                0,
                                math.min(
                                  2,
                                  _userNameController.text.trim().length,
                                ),
                              )
                              .toUpperCase(),
                    color: const Color(0xFF55BCA4),
                    size: 58,
                    imageBytes: _avatar?.bytes,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _avatar?.fileName ?? 'Nenhum avatar selecionado',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconToolButton(
                    icon: Icons.image,
                    label: 'Trocar avatar',
                    onPressed: _busy ? null : _pickAvatar,
                  ),
                  const SizedBox(width: 8),
                  IconToolButton(
                    icon: Icons.delete_outline,
                    label: 'Remover avatar',
                    onPressed: _avatar == null
                        ? null
                        : () {
                            setState(() {
                              _avatar = null;
                            });
                          },
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Text(
                'Banner/GIF',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: SizedBox(
                  height: 120,
                  width: double.infinity,
                  child: _banner?.bytes != null
                      ? Image.memory(
                          _banner!.bytes,
                          fit: BoxFit.cover,
                          alignment: Alignment(0, _bannerAlignmentY),
                          errorBuilder: (_, _, _) => _profileBannerFallback(),
                        )
                      : _profileBannerFallback(),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _banner?.fileName ?? 'Nenhum banner selecionado',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  IconToolButton(
                    icon: Icons.image_search,
                    label: 'Trocar banner',
                    onPressed: _busy ? null : _pickBanner,
                  ),
                  const SizedBox(width: 8),
                  IconToolButton(
                    icon: Icons.delete_outline,
                    label: 'Remover banner',
                    onPressed: _banner == null
                        ? null
                        : () {
                            setState(() {
                              _banner = null;
                            });
                          },
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    'Crop vertical',
                    style: TextStyle(color: Color(0xFFAEB8B5), fontSize: 12),
                  ),
                ],
              ),
              Slider(
                value: _bannerAlignmentY,
                min: -1,
                max: 1,
                divisions: 20,
                onChanged: (value) {
                  setState(() {
                    _bannerAlignmentY = value;
                  });
                },
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.of(context).pop();
          },
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: () {
            Navigator.of(context).pop(
              ProfileEditorDraft(
                userName: _userNameController.text,
                avatar: _avatar,
                banner: _banner,
                bannerAlignmentY: _bannerAlignmentY,
              ),
            );
          },
          child: const Text('Salvar'),
        ),
      ],
    );
  }

  Widget _profileBannerFallback() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF243B36), Color(0xFF1B2023), Color(0xFF3E3134)],
        ),
      ),
    );
  }
}

class Panel extends StatelessWidget {
  const Panel({
    required this.title,
    required this.child,
    this.trailing,
    super.key,
  });

  final String title;
  final Widget child;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF202326),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF30363A)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: 34,
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                ?trailing,
              ],
            ),
          ),
          const SizedBox(height: 8),
          Expanded(child: child),
        ],
      ),
    );
  }
}

class IconToolButton extends StatelessWidget {
  const IconToolButton({
    required this.icon,
    required this.label,
    this.onPressed,
    super.key,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final isDisabled = onPressed == null;

    return Tooltip(
      message: label,
      child: SizedBox(
        width: 38,
        height: 38,
        child: IconButton(
          onPressed: onPressed,
          icon: Icon(icon, size: 20),
          style: IconButton.styleFrom(
            backgroundColor: isDisabled
                ? const Color(0xFF171A1C)
                : const Color(0xFF1A1D20),
            foregroundColor: isDisabled
                ? const Color(0xFF6E7875)
                : const Color(0xFFDCE5E1),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
      ),
    );
  }
}

class CounterBadge extends StatelessWidget {
  const CounterBadge({required this.text, this.danger = false, super.key});

  final String text;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 28,
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: danger ? const Color(0xFF4A2323) : const Color(0xFF1A1D20),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: danger ? const Color(0xFFFFC0BA) : null,
          fontSize: 12,
        ),
      ),
    );
  }
}

class AvatarBadge extends StatelessWidget {
  const AvatarBadge({
    required this.initials,
    required this.color,
    required this.size,
    this.imageBytes,
    super.key,
  });

  final String initials;
  final Color color;
  final double size;
  final Uint8List? imageBytes;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(8),
      ),
      clipBehavior: Clip.antiAlias,
      child: imageBytes != null
          ? Image.memory(
              imageBytes!,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) {
                return _AvatarInitials(initials: initials);
              },
            )
          : _AvatarInitials(initials: initials),
    );
  }
}

class _AvatarInitials extends StatelessWidget {
  const _AvatarInitials({required this.initials});

  final String initials;

  @override
  Widget build(BuildContext context) {
    return Text(
      initials,
      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900),
    );
  }
}

class ParticipantView {
  const ParticipantView({
    required this.name,
    required this.initials,
    required this.status,
    required this.color,
    this.speaking = false,
    this.level = 0,
    this.isSelf = false,
    this.imageBytes,
  });

  final String name;
  final String initials;
  final String status;
  final Color color;
  final bool speaking;
  final double level;
  final bool isSelf;
  final Uint8List? imageBytes;
}

class AudioDevice {
  const AudioDevice({
    required this.id,
    required this.label,
    required this.state,
  });

  final String id;
  final String label;
  final String state;

  String get summary => '$label (${state.toLowerCase()})';
}

class AudioSnapshot {
  const AudioSnapshot({
    required this.inputs,
    required this.outputs,
    required this.defaultInputId,
    required this.defaultOutputId,
    required this.serverReachable,
    this.error,
  });

  factory AudioSnapshot.loading() {
    return const AudioSnapshot(
      inputs: [],
      outputs: [],
      defaultInputId: null,
      defaultOutputId: null,
      serverReachable: false,
    );
  }

  factory AudioSnapshot.unavailable({required String error}) {
    return AudioSnapshot(
      inputs: const [],
      outputs: const [],
      defaultInputId: null,
      defaultOutputId: null,
      serverReachable: false,
      error: error,
    );
  }

  final List<AudioDevice> inputs;
  final List<AudioDevice> outputs;
  final String? defaultInputId;
  final String? defaultOutputId;
  final bool serverReachable;
  final String? error;

  AudioSnapshot copyWith({
    List<AudioDevice>? inputs,
    List<AudioDevice>? outputs,
    String? defaultInputId,
    String? defaultOutputId,
    bool? serverReachable,
    String? error,
  }) {
    return AudioSnapshot(
      inputs: inputs ?? this.inputs,
      outputs: outputs ?? this.outputs,
      defaultInputId: defaultInputId ?? this.defaultInputId,
      defaultOutputId: defaultOutputId ?? this.defaultOutputId,
      serverReachable: serverReachable ?? this.serverReachable,
      error: error,
    );
  }
}

class AudioDefaults {
  const AudioDefaults({
    required this.defaultSinkId,
    required this.defaultSourceId,
  });

  final String? defaultSinkId;
  final String? defaultSourceId;
}

class AudioServiceException implements Exception {
  const AudioServiceException(this.message);

  final String message;

  @override
  String toString() => message;
}

enum DiceSelectionMode {
  none,
  keepHighest,
  keepLowest,
  dropHighest,
  dropLowest,
}

class DiceRollRequest {
  const DiceRollRequest({
    required this.diceCount,
    required this.sides,
    required this.selectionMode,
    required this.selectionCount,
    required this.modifier,
    required this.normalizedExpression,
  });

  final int diceCount;
  final int sides;
  final DiceSelectionMode selectionMode;
  final int? selectionCount;
  final int modifier;
  final String normalizedExpression;

  String? get selectionLabel {
    if (selectionMode == DiceSelectionMode.none || selectionCount == null) {
      return null;
    }

    final prefix = switch (selectionMode) {
      DiceSelectionMode.keepHighest => 'kh',
      DiceSelectionMode.keepLowest => 'kl',
      DiceSelectionMode.dropHighest => 'dh',
      DiceSelectionMode.dropLowest => 'dl',
      DiceSelectionMode.none => '',
    };
    return '$prefix$selectionCount';
  }
}

class DiceRollRecord {
  const DiceRollRecord({
    required this.author,
    required this.expression,
    required this.normalizedExpression,
    required this.total,
    required this.modifier,
    required this.rolls,
    required this.keptRolls,
    required this.selectionLabel,
    required this.rolledAt,
  });

  final String author;
  final String expression;
  final String normalizedExpression;
  final int total;
  final int modifier;
  final List<int> rolls;
  final List<int> keptRolls;
  final String? selectionLabel;
  final DateTime rolledAt;

  String get summaryLabel => '$normalizedExpression = $total';

  String get breakdownLabel {
    final buffer = StringBuffer('rolagens ${_formatList(rolls)}');
    if (selectionLabel != null) {
      buffer.write(' $selectionLabel -> ${_formatList(keptRolls)}');
    }
    if (modifier != 0) {
      buffer.write(modifier > 0 ? ' +$modifier' : ' $modifier');
    }
    return buffer.toString();
  }

  String get chatMessage =>
      '**$normalizedExpression = $total**\n$breakdownLabel';

  String get timestampLabel {
    final hour = rolledAt.hour.toString().padLeft(2, '0');
    final minute = rolledAt.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  String _formatList(List<int> values) {
    return '[${values.join(', ')}]';
  }
}

class DiceRollException implements Exception {
  const DiceRollException(this.message);

  final String message;

  @override
  String toString() => message;
}

DiceRollRequest parseDiceExpression(String input) {
  final trimmed = input.trim().toLowerCase().replaceAll(' ', '');
  final match = RegExp(
    r'^(\d*)d(\d+)(?:(k[hl]|d[hl])(\d+))?([+-]\d+)?$',
  ).firstMatch(trimmed);

  if (match == null) {
    throw const DiceRollException(
      'Use formatos como d20, 1d20, 2d6+3 ou 4d6kh3.',
    );
  }

  final diceCount = int.tryParse((match.group(1) ?? '').ifEmpty('1')) ?? 1;
  final sides = int.tryParse(match.group(2) ?? '') ?? 0;
  final selectionToken = match.group(3);
  final selectionCount = match.group(4) == null
      ? null
      : int.tryParse(match.group(4)!);
  final modifier = int.tryParse(match.group(5) ?? '0') ?? 0;

  if (diceCount < 1 || diceCount > 50) {
    throw const DiceRollException(
      'A quantidade de dados deve ficar entre 1 e 50.',
    );
  }
  if (sides < 2 || sides > 1000) {
    throw const DiceRollException(
      'O numero de faces deve ficar entre 2 e 1000.',
    );
  }
  if (selectionCount != null &&
      (selectionCount < 1 || selectionCount > diceCount)) {
    throw const DiceRollException(
      'O valor de keep/drop precisa ser pelo menos 1 e no maximo a quantidade de dados.',
    );
  }
  if (modifier.abs() > 1000) {
    throw const DiceRollException(
      'O modificador precisa ficar entre -1000 e 1000.',
    );
  }

  final selectionMode = switch (selectionToken) {
    'kh' => DiceSelectionMode.keepHighest,
    'kl' => DiceSelectionMode.keepLowest,
    'dh' => DiceSelectionMode.dropHighest,
    'dl' => DiceSelectionMode.dropLowest,
    _ => DiceSelectionMode.none,
  };

  final normalizedBuffer = StringBuffer('${diceCount}d$sides');
  if (selectionToken != null && selectionCount != null) {
    normalizedBuffer.write('$selectionToken$selectionCount');
  }
  if (modifier != 0) {
    normalizedBuffer.write(modifier > 0 ? '+$modifier' : '$modifier');
  }

  return DiceRollRequest(
    diceCount: diceCount,
    sides: sides,
    selectionMode: selectionMode,
    selectionCount: selectionCount,
    modifier: modifier,
    normalizedExpression: normalizedBuffer.toString(),
  );
}

class ChatMessage {
  const ChatMessage.text(
    this.author,
    this.text, {
    this.self = false,
    this.color = const Color(0xFF3E6B62),
  }) : imageBytes = null,
       imageName = null;

  const ChatMessage.image(
    this.author, {
    required this.imageName,
    required this.imageBytes,
    this.self = false,
    this.color = const Color(0xFF3E6B62),
  }) : text = null;

  final String author;
  final String? text;
  final String? imageName;
  final Uint8List? imageBytes;
  final bool self;
  final Color color;
}

class SelectedChatImage {
  const SelectedChatImage({required this.name, required this.bytes});

  final String name;
  final Uint8List bytes;
}

class SelectedAudioTrack {
  const SelectedAudioTrack({
    required this.name,
    required this.path,
  });

  final String name;
  final String path;
}

class LocalSoundtrackTrack {
  const LocalSoundtrackTrack({
    required this.id,
    required this.name,
    required this.path,
  });

  final String id;
  final String name;
  final String path;
}

String sanitizeObsidianMarkdown(String markdown) {
  final withoutMarkdownLinks = markdown.replaceAllMapped(
    RegExp(r'\[([^\]]+)\]\(([^)]+)\)'),
    (match) => match.group(1) ?? '',
  );
  final withoutWikiLinks = withoutMarkdownLinks.replaceAllMapped(
    RegExp(r'\[\[([^\]]+)\]\]'),
    (match) => match.group(1) ?? '',
  );

  return withoutWikiLinks;
}

const _soundtrackSentinel = Object();

extension on String {
  String ifEmpty(String fallback) {
    return trim().isEmpty ? fallback : this;
  }
}

String formatDuration(Duration value) {
  final minutes = value.inMinutes.remainder(60).toString().padLeft(2, '0');
  final seconds = value.inSeconds.remainder(60).toString().padLeft(2, '0');
  final hours = value.inHours;

  if (hours > 0) {
    return '${hours.toString().padLeft(2, '0')}:$minutes:$seconds';
  }

  return '$minutes:$seconds';
}

final Uint8List _demoImageBytes = Uint8List.fromList(<int>[
  137,
  80,
  78,
  71,
  13,
  10,
  26,
  10,
  0,
  0,
  0,
  13,
  73,
  72,
  68,
  82,
  0,
  0,
  0,
  1,
  0,
  0,
  0,
  1,
  8,
  4,
  0,
  0,
  0,
  181,
  28,
  12,
  2,
  0,
  0,
  0,
  11,
  73,
  68,
  65,
  84,
  120,
  218,
  99,
  252,
  255,
  31,
  0,
  3,
  3,
  2,
  0,
  239,
  166,
  226,
  91,
  0,
  0,
  0,
  0,
  73,
  69,
  78,
  68,
  174,
  66,
  96,
  130,
]);
