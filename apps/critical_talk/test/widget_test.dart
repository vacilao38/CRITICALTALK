import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:critical_talk/main.dart';
import 'package:critical_talk/user_foundation.dart';

void main() {
  test('sanitizes obsidian links while preserving visible labels', () {
    expect(
      sanitizeObsidianMarkdown(
        '**ritual** [[arquivo]] [portal](https://obsidian.md)',
      ),
      '**ritual** arquivo portal',
    );
  });

  test('parses complex dice expressions with keep highest and modifier', () {
    final request = parseDiceExpression('4d6kh3+2');

    expect(request.diceCount, 4);
    expect(request.sides, 6);
    expect(request.selectionMode, DiceSelectionMode.keepHighest);
    expect(request.selectionCount, 3);
    expect(request.modifier, 2);
    expect(request.normalizedExpression, '4d6kh3+2');
  });

  test(
    'resolves direct remote audio links and rejects platform pages',
    () async {
      final directTrack = await resolveAudioTrackLink(
        'https://cdn.example.test/music/theme.mp3',
      );

      expect(directTrack?.name, 'theme.mp3');
      expect(directTrack?.source, AudioTrackSource.remoteUrl);

      expect(
        resolveAudioTrackLink('https://open.spotify.com/track/abc'),
        throwsA(isA<MusicLinkResolverException>()),
      );
    },
  );

  testWidgets('renders the base session layout', (WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(1366, 768));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(_buildApp());
    await tester.pump();

    expect(find.text('Critical Talk'), findsOneWidget);
    expect(find.text('Voz'), findsOneWidget);
    expect(find.text('Chat'), findsOneWidget);
    expect(find.text('Trilha'), findsOneWidget);
    expect(find.text('Dados'), findsOneWidget);
    expect(find.text('Perfil'), findsOneWidget);
  });

  testWidgets('shows the auth shell when there is no active user', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1366, 768));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      _buildApp(authService: FakeUserAuthService(startAuthenticated: false)),
    );
    await tester.pumpAndSettle();

    expect(find.text('Acesso'), findsOneWidget);
    expect(find.text('Criar usuario'), findsWidgets);
  });

  testWidgets('creates a local user and enters the session', (
    WidgetTester tester,
  ) async {
    final authService = FakeUserAuthService(startAuthenticated: false);

    await tester.binding.setSurfaceSize(const Size(1366, 768));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(_buildApp(authService: authService));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Criar usuario').last);
    await tester.pumpAndSettle();

    await tester.enterText(
      find.widgetWithText(TextField, 'rogerin'),
      'rog_test',
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'Minimo de 8 caracteres'),
      'Senha@123',
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'Repita a senha'),
      'Senha@123',
    );

    await tester.tap(find.widgetWithText(FilledButton, 'Criar usuario'));
    await tester.pumpAndSettle();

    expect(find.text('Chave inicial do usuario'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, 'Continuar'));
    await tester.pumpAndSettle();

    expect(authService.registerCount, 1);
    expect(find.text('Critical Talk'), findsOneWidget);
    expect(find.text('rog_test'), findsWidgets);
  });

  testWidgets('keeps the compact layout usable', (WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(1100, 820));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(_buildApp());
    await tester.pump();

    expect(find.text('Voz'), findsOneWidget);
    expect(find.text('Mensagem para a mesa'), findsOneWidget);
  });

  testWidgets('shows detected audio devices and allows switching output', (
    WidgetTester tester,
  ) async {
    final audioService = FakeAudioControlService();

    await tester.binding.setSurfaceSize(const Size(1366, 768));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(_buildApp(audioService: audioService));
    await tester.pumpAndSettle();

    expect(find.textContaining('usb headset'), findsOneWidget);

    await tester.tap(find.textContaining('usb headset').first);
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('analog speakers').last);
    await tester.pumpAndSettle();

    expect(audioService.selectedOutputId, 'alsa_output.analog-speakers');
  });

  testWidgets('plays the audio bot through the service', (
    WidgetTester tester,
  ) async {
    final audioService = FakeAudioControlService();

    await tester.binding.setSurfaceSize(const Size(1366, 768));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(_buildApp(audioService: audioService));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(FilledButton, 'Bot'));
    await tester.pump();

    expect(find.text('Emitindo teste'), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 650));
    await tester.pump();

    expect(audioService.playCount, 1);
    expect(find.text('Aguardando teste'), findsOneWidget);
  });

  testWidgets('toggles local self monitoring from the voice controls', (
    WidgetTester tester,
  ) async {
    final audioService = FakeAudioControlService();

    await tester.binding.setSurfaceSize(const Size(1366, 768));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(_buildApp(audioService: audioService));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.hearing), findsOneWidget);
    expect(find.text('Retorno local ativo'), findsNothing);

    await tester.tap(find.byIcon(Icons.hearing));
    await tester.pump();

    expect(audioService.startMonitoringCount, 1);
    expect(audioService.isMonitoring, isTrue);
    expect(find.text('Retorno local ativo'), findsOneWidget);
    expect(find.byIcon(Icons.hearing_disabled), findsOneWidget);

    await tester.tap(find.byIcon(Icons.hearing_disabled));
    await tester.pump();

    expect(audioService.stopMonitoringCount, 1);
    expect(audioService.isMonitoring, isFalse);
    expect(find.text('Retorno local ativo'), findsNothing);
    expect(find.byIcon(Icons.hearing), findsOneWidget);
  });

  testWidgets('highlights the local participant when input level rises', (
    WidgetTester tester,
  ) async {
    final audioService = FakeAudioControlService(
      inputLevels: const [0.02, 0.34, 0.09],
    );

    await tester.binding.setSurfaceSize(const Size(1366, 768));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(_buildApp(audioService: audioService));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 260));
    await tester.pump();

    expect(find.text('VOCE'), findsOneWidget);
    expect(find.text('Falando agora'), findsOneWidget);
    expect(find.byType(SpeakingMeter), findsWidgets);
  });

  testWidgets('sends a local message and receives the test bot reply', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1366, 768));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(_buildApp());
    await tester.pump();

    await tester.enterText(
      find.widgetWithText(TextField, 'Mensagem para a mesa'),
      'ola bot',
    );
    await tester.pump();

    await tester.tap(find.byIcon(Icons.send));
    await tester.pump();

    expect(find.text('ola bot'), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump();

    expect(find.text('mensagem recebida'), findsOneWidget);
  });

  testWidgets('renders obsidian-style markdown and strips link syntax', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1366, 768));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(_buildApp());
    await tester.pump();

    await tester.enterText(
      find.widgetWithText(TextField, 'Mensagem para a mesa'),
      '**ritual** [[arquivo]] [portal](https://obsidian.md)',
    );
    await tester.pump();

    await tester.tap(find.byIcon(Icons.send));
    await tester.pump();

    expect(find.byType(MarkdownBody), findsWidgets);
    expect(
      find.text('**ritual** [[arquivo]] [portal](https://obsidian.md)'),
      findsNothing,
    );

    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump();
  });

  testWidgets('sends an image through the picker and shows it in chat', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1366, 768));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      _buildApp(
        imagePicker: () async =>
            SelectedChatImage(name: 'mapa.png', bytes: _fakeImageBytes),
      ),
    );
    await tester.pump();

    await tester.tap(find.byIcon(Icons.add_photo_alternate));
    await tester.pump();

    expect(find.text('mapa.png'), findsOneWidget);
    expect(find.byType(Image), findsWidgets);

    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump();

    expect(find.text('mensagem recebida'), findsOneWidget);
  });

  testWidgets('adds a local soundtrack and controls playback queue', (
    WidgetTester tester,
  ) async {
    final musicService = FakeMusicPlaybackService();
    var pickerCallCount = 0;
    final selectedTracks = [
      const SelectedAudioTrack(name: 'campfire.mp3', path: '/tmp/campfire.mp3'),
      const SelectedAudioTrack(name: 'storm.ogg', path: '/tmp/storm.ogg'),
    ];

    await tester.binding.setSurfaceSize(const Size(1366, 768));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      _buildApp(
        trackPicker: () async => selectedTracks[pickerCallCount++],
        musicPlaybackService: musicService,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Adicionar trilha'));
    await tester.pumpAndSettle();

    expect(find.text('campfire.mp3'), findsWidgets);

    await tester.tap(find.byTooltip('Adicionar trilha'));
    await tester.pumpAndSettle();

    expect(find.text('storm.ogg'), findsWidgets);

    await tester.tap(find.byTooltip('Preview'));
    await tester.pumpAndSettle();
    expect(musicService.previewCount, 1);
    expect(find.text('Preview privado'), findsWidgets);

    await tester.tap(find.byTooltip('Tocar na sala'));
    await tester.pumpAndSettle();
    expect(musicService.playCount, 1);
    expect(find.text('Ao vivo na sala'), findsWidgets);

    await tester.tap(find.byTooltip('Adicionar a fila'));
    await tester.pumpAndSettle();
    expect(musicService.enqueueCount, 1);
    expect(find.text('1/2 na fila'), findsWidgets);

    await tester.tap(find.byTooltip('Pausar'));
    await tester.pumpAndSettle();
    expect(musicService.pauseCount, 1);

    await tester.tap(find.byTooltip('Retomar'));
    await tester.pumpAndSettle();
    expect(musicService.resumeCount, 1);

    await tester.tap(find.byTooltip('Loop da faixa'));
    await tester.pumpAndSettle();
    expect(musicService.loopToggleCount, 1);

    await tester.tap(find.byTooltip('Loop da fila'));
    await tester.pumpAndSettle();
    expect(musicService.queueLoopToggleCount, 1);

    await tester.tap(find.byTooltip('Limpar fila'));
    await tester.pumpAndSettle();
    expect(musicService.clearQueueCount, 1);

    await tester.tap(find.byTooltip('Pular'));
    await tester.pumpAndSettle();
    expect(musicService.skipCount, 1);

    await tester.tap(find.byTooltip('Parar'));
    await tester.pumpAndSettle();
    expect(musicService.stopCount, 1);
  });

  testWidgets('adds a remote soundtrack through a link resolver', (
    WidgetTester tester,
  ) async {
    String? resolvedLink;

    await tester.binding.setSurfaceSize(const Size(1366, 768));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      _buildApp(
        trackLinkResolver: (link) async {
          resolvedLink = link;
          return SelectedAudioTrack(
            name: 'theme.ogg',
            path: link,
            source: AudioTrackSource.remoteUrl,
          );
        },
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Adicionar link'));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.widgetWithText(TextField, 'https://servidor/audio.mp3'),
      'https://example.test/theme.ogg',
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Adicionar'));
    await tester.pumpAndSettle();

    expect(resolvedLink, 'https://example.test/theme.ogg');
    expect(find.text('theme.ogg'), findsWidgets);
    expect(find.text('Link remoto'), findsOneWidget);
  });

  testWidgets(
    'rolls dice functionally and appends the result to history and chat',
    (WidgetTester tester) async {
      final diceRoller = FakeDiceRoller();

      await tester.binding.setSurfaceSize(const Size(1366, 768));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(_buildApp(diceRoller: diceRoller));
      await tester.pumpAndSettle();

      await tester.enterText(find.widgetWithText(TextField, '1d20+5'), '2d6+3');
      await tester.tap(find.widgetWithText(FilledButton, 'Rolar'));
      await tester.pump();

      expect(find.text('Rogerin rolou 11'), findsWidgets);
      expect(find.text('2d6+3 = 11'), findsWidgets);
      expect(find.textContaining('rolagens [4, 4] +3'), findsWidgets);
      expect(diceRoller.rollCount, 1);
    },
  );
}

Widget _buildApp({
  ChatImagePicker imagePicker = _defaultImagePicker,
  AudioTrackPicker trackPicker = _defaultTrackPicker,
  AudioControlService? audioService,
  UserAuthService? authService,
  DiceRoller? diceRoller,
  MusicPlaybackService? musicPlaybackService,
  AudioTrackLinkResolver trackLinkResolver = resolveAudioTrackLink,
}) {
  return CriticalTalkApp(
    imagePicker: imagePicker,
    trackPicker: trackPicker,
    trackLinkResolver: trackLinkResolver,
    audioService: audioService ?? FakeAudioControlService(),
    musicPlaybackService: musicPlaybackService ?? FakeMusicPlaybackService(),
    userAuthService: authService ?? FakeUserAuthService(),
    diceRoller: diceRoller ?? const RandomDiceRoller(),
  );
}

Future<SelectedChatImage?> _defaultImagePicker() async => null;
Future<SelectedAudioTrack?> _defaultTrackPicker() async => null;

class FakeAudioControlService extends AudioControlService {
  FakeAudioControlService({
    this.snapshot = const AudioSnapshot(
      inputs: [
        AudioDevice(
          id: 'alsa_input.usb-mic',
          label: 'usb mic',
          state: 'RUNNING',
        ),
      ],
      outputs: [
        AudioDevice(
          id: 'alsa_output.usb-headset',
          label: 'usb headset',
          state: 'SUSPENDED',
        ),
        AudioDevice(
          id: 'alsa_output.analog-speakers',
          label: 'analog speakers',
          state: 'RUNNING',
        ),
      ],
      defaultInputId: 'alsa_input.usb-mic',
      defaultOutputId: 'alsa_output.usb-headset',
      serverReachable: true,
    ),
    this.inputLevels = const [0.01, 0.01, 0.01],
  });

  final AudioSnapshot snapshot;
  final List<double> inputLevels;
  int _playCounter = 0;
  String? _selectedOutputId;
  bool _isMonitoring = false;
  int _startMonitoringCount = 0;
  int _stopMonitoringCount = 0;

  int get playCount => _playCounter;
  String? get selectedOutputId => _selectedOutputId;
  bool get isMonitoring => _isMonitoring;
  int get startMonitoringCount => _startMonitoringCount;
  int get stopMonitoringCount => _stopMonitoringCount;

  @override
  Future<AudioSnapshot> loadSnapshot() async {
    _selectedOutputId = snapshot.defaultOutputId;
    return snapshot;
  }

  @override
  Future<void> playBotTestAudio({String? outputId}) async {
    _playCounter++;
    _selectedOutputId = outputId;
    await Future<void>.delayed(const Duration(milliseconds: 600));
  }

  @override
  Stream<double> watchInputLevels({String? inputId}) {
    return Stream<double>.periodic(
      const Duration(milliseconds: 120),
      (index) => inputLevels[index % inputLevels.length],
    );
  }

  @override
  Future<AudioSnapshot> setDefaultInput(String inputId) async {
    return snapshot.copyWith(defaultInputId: inputId);
  }

  @override
  Future<AudioSnapshot> setDefaultOutput(String outputId) async {
    _selectedOutputId = outputId;
    return snapshot.copyWith(defaultOutputId: outputId);
  }

  @override
  Future<void> startInputMonitoring({
    required String inputId,
    required String outputId,
  }) async {
    _startMonitoringCount++;
    _isMonitoring = true;
    _selectedOutputId = outputId;
  }

  @override
  Future<void> stopInputMonitoring() async {
    _stopMonitoringCount++;
    _isMonitoring = false;
  }
}

class FakeUserAuthService extends UserAuthService {
  FakeUserAuthService({this.startAuthenticated = true}) {
    if (startAuthenticated) {
      _users[_seedUser.userName.toLowerCase()] = _seedUser;
      _passwords[_seedUser.userName.toLowerCase()] = 'Senha@123';
      _currentUser = _seedUser;
    }
  }

  final bool startAuthenticated;
  final Map<String, CriticalUser> _users = {};
  final Map<String, String> _passwords = {};
  CriticalUser? _currentUser;
  int registerCount = 0;

  static final _seedUser = CriticalUser(
    userId: 'ctu-seed-0001',
    userName: 'Rogerin',
    createdAt: DateTime(2026, 1, 1),
    profile: const UserProfile(profileIds: [], bannerAlignmentY: 0),
  );

  @override
  Future<AuthSession> loadSession() async {
    return AuthSession(currentUser: _currentUser);
  }

  @override
  Future<CriticalUser> login({
    required String userName,
    required String password,
  }) async {
    final normalized = userName.trim().toLowerCase();
    final user = _users[normalized];
    if (user == null || _passwords[normalized] != password) {
      throw const UserAuthException('Usuario ou senha invalidos.');
    }

    _currentUser = user;
    return user;
  }

  @override
  Future<UserRegistrationResult> register({
    required String userName,
    required String password,
    required List<int> organicEntropy,
  }) async {
    registerCount++;
    final normalized = userName.trim().toLowerCase();
    final user = CriticalUser(
      userId: 'ctu-test-${registerCount.toString().padLeft(4, '0')}',
      userName: userName.trim(),
      createdAt: DateTime(2026, 6, 4),
      profile: const UserProfile(profileIds: [], bannerAlignmentY: 0),
    );
    _users[normalized] = user;
    _passwords[normalized] = password;
    _currentUser = user;
    return UserRegistrationResult(user: user, firstTimeKey: user.userId);
  }

  @override
  Future<void> logout() async {
    _currentUser = null;
  }

  @override
  Future<CriticalUser> updateProfile({
    required String userId,
    required String userName,
    UserMedia? avatar,
    UserMedia? banner,
    required double bannerAlignmentY,
  }) async {
    final current = _currentUser!;
    final updated = current.copyWith(
      userName: userName.trim(),
      profile: current.profile.copyWith(
        avatar: avatar,
        clearAvatar: avatar == null,
        banner: banner,
        clearBanner: banner == null,
        bannerAlignmentY: bannerAlignmentY,
      ),
    );
    _users.remove(current.userName.toLowerCase());
    _users[updated.userName.toLowerCase()] = updated;
    _passwords[updated.userName.toLowerCase()] =
        _passwords.remove(current.userName.toLowerCase()) ?? 'Senha@123';
    _currentUser = updated;
    return updated;
  }
}

class FakeDiceRoller extends DiceRoller {
  int rollCount = 0;

  @override
  DiceRollRecord roll(String expression, {required String author}) {
    rollCount++;
    return DiceRollRecord(
      author: author,
      expression: expression,
      normalizedExpression: '2d6+3',
      total: 11,
      modifier: 3,
      rolls: const [4, 4],
      keptRolls: const [4, 4],
      selectionLabel: null,
      rolledAt: DateTime(2026, 6, 4, 21, 30),
    );
  }
}

class FakeMusicPlaybackService extends MusicPlaybackService {
  final StreamController<SoundtrackPlaybackSnapshot> _controller =
      StreamController<SoundtrackPlaybackSnapshot>.broadcast();
  SoundtrackPlaybackSnapshot _snapshot = SoundtrackPlaybackSnapshot.idle();

  int previewCount = 0;
  int playCount = 0;
  int pauseCount = 0;
  int resumeCount = 0;
  int stopCount = 0;
  int enqueueCount = 0;
  int skipCount = 0;
  int clearQueueCount = 0;
  int loopToggleCount = 0;
  int queueLoopToggleCount = 0;
  final List<LocalSoundtrackTrack> _queue = [];
  int _activeQueueIndex = -1;

  @override
  Stream<SoundtrackPlaybackSnapshot> get changes => _controller.stream;

  @override
  SoundtrackPlaybackSnapshot get snapshot => _snapshot;

  @override
  Future<void> dispose() async {
    await _controller.close();
  }

  @override
  Future<void> pause() async {
    pauseCount++;
    _emit(_snapshot.copyWith(isPlaying: false, isPaused: true));
  }

  @override
  Future<void> playTrack(LocalSoundtrackTrack track) async {
    playCount++;
    _queue
      ..clear()
      ..add(track);
    _activeQueueIndex = 0;
    _emit(
      _snapshot.copyWith(
        activeTrackId: track.id,
        scope: SoundtrackPlaybackScope.room,
        isPlaying: true,
        isPaused: false,
        duration: const Duration(minutes: 3, seconds: 12),
        position: const Duration(minutes: 1, seconds: 14),
        queueTrackIds: _queueIds(),
        activeQueueIndex: _activeQueueIndex,
      ),
    );
  }

  @override
  Future<void> enqueueTrack(LocalSoundtrackTrack track) async {
    enqueueCount++;
    if (_queue.isEmpty) {
      await playTrack(track);
      return;
    }

    _queue.add(track);
    _emit(_snapshot.copyWith(queueTrackIds: _queueIds()));
  }

  @override
  Future<void> previewTrack(LocalSoundtrackTrack track) async {
    previewCount++;
    _emit(
      _snapshot.copyWith(
        activeTrackId: track.id,
        scope: SoundtrackPlaybackScope.preview,
        isPlaying: true,
        isPaused: false,
        duration: const Duration(minutes: 3, seconds: 12),
        position: const Duration(seconds: 24),
      ),
    );
  }

  @override
  Future<void> resume() async {
    resumeCount++;
    _emit(_snapshot.copyWith(isPlaying: true, isPaused: false));
  }

  @override
  Future<void> setLoopEnabled(bool enabled) async {
    loopToggleCount++;
    _emit(_snapshot.copyWith(isLoopEnabled: enabled));
  }

  @override
  Future<void> setQueueLoopEnabled(bool enabled) async {
    queueLoopToggleCount++;
    _emit(_snapshot.copyWith(isQueueLoopEnabled: enabled));
  }

  @override
  Future<void> skip() async {
    skipCount++;
    if (_activeQueueIndex + 1 >= _queue.length) {
      await stop();
      return;
    }

    _activeQueueIndex++;
    final nextTrack = _queue[_activeQueueIndex];
    _emit(
      _snapshot.copyWith(
        activeTrackId: nextTrack.id,
        isPlaying: true,
        isPaused: false,
        queueTrackIds: _queueIds(),
        activeQueueIndex: _activeQueueIndex,
      ),
    );
  }

  @override
  Future<void> clearQueue() async {
    clearQueueCount++;
    if (_activeQueueIndex >= 0 && _activeQueueIndex < _queue.length) {
      final currentTrack = _queue[_activeQueueIndex];
      _queue
        ..clear()
        ..add(currentTrack);
      _activeQueueIndex = 0;
    } else {
      _queue.clear();
      _activeQueueIndex = -1;
    }
    _emit(
      _snapshot.copyWith(
        queueTrackIds: _queueIds(),
        activeQueueIndex: _activeQueueIndex,
      ),
    );
  }

  @override
  Future<void> stop() async {
    stopCount++;
    _queue.clear();
    _activeQueueIndex = -1;
    _emit(
      _snapshot.copyWith(
        activeTrackId: null,
        isPlaying: false,
        isPaused: false,
        position: Duration.zero,
        scope: SoundtrackPlaybackScope.idle,
        queueTrackIds: <String>[],
        activeQueueIndex: -1,
      ),
    );
  }

  void _emit(SoundtrackPlaybackSnapshot snapshot) {
    _snapshot = snapshot;
    if (!_controller.isClosed) {
      _controller.add(snapshot);
    }
  }

  List<String> _queueIds() => [for (final track in _queue) track.id];
}

final Uint8List _fakeImageBytes = Uint8List.fromList(<int>[
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
