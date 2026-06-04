import 'package:flutter/material.dart';

void main() {
  runApp(const CriticalTalkApp());
}

class CriticalTalkApp extends StatelessWidget {
  const CriticalTalkApp({super.key});

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
      home: const SessionShell(),
    );
  }
}

class SessionShell extends StatelessWidget {
  const SessionShell({super.key});

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
                  const SessionHeader(),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          final compact = constraints.maxWidth < 1180;

                          if (compact) {
                            return const CompactSessionLayout();
                          }

                          return const WideSessionLayout();
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
  const WideSessionLayout({super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(width: 288, child: VoicePanel()),
        const SizedBox(width: 12),
        const Expanded(child: CenterColumn()),
        const SizedBox(width: 12),
        const SizedBox(width: 340, child: SideToolsPanel()),
      ],
    );
  }
}

class CompactSessionLayout extends StatelessWidget {
  const CompactSessionLayout({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const SizedBox(height: 180, child: VoicePanel()),
        const SizedBox(height: 12),
        Expanded(
          child: Row(
            children: [
              const Expanded(child: CenterColumn()),
              const SizedBox(width: 12),
              const SizedBox(width: 320, child: SideToolsPanel()),
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
  const SessionHeader({super.key});

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
          IconToolButton(icon: Icons.copy, label: 'Copiar convite'),
          const SizedBox(width: 8),
          IconToolButton(icon: Icons.more_horiz, label: 'Mais opcoes'),
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
  const VoicePanel({super.key});

  static const participants = [
    Participant('Mestre', 'RO', 'Falando', Color(0xFF55BCA4), true),
    Participant('Mira', 'MI', 'Microfone aberto', Color(0xFFE6B450), false),
    Participant('Darian', 'DA', 'Silenciado', Color(0xFF9BA7FF), false),
    Participant('Noctua', 'NO', 'Microfone aberto', Color(0xFFDE706B), false),
  ];

  @override
  Widget build(BuildContext context) {
    return Panel(
      title: 'Voz',
      trailing: IconToolButton(icon: Icons.tune, label: 'Dispositivos'),
      child: SingleChildScrollView(
        child: Column(
          children: [
            const DeviceStrip(),
            const SizedBox(height: 12),
            ...participants.map(
              (participant) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: ParticipantTile(participant: participant),
              ),
            ),
            const SizedBox(height: 4),
            const VoiceControls(),
          ],
        ),
      ),
    );
  }
}

class DeviceStrip extends StatelessWidget {
  const DeviceStrip({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: const [
        DeviceRow(icon: Icons.mic, label: 'Microfone', value: 'Yeti Nano'),
        SizedBox(height: 8),
        DeviceRow(icon: Icons.volume_up, label: 'Saida', value: 'Headset USB'),
      ],
    );
  }
}

class DeviceRow extends StatelessWidget {
  const DeviceRow({
    required this.icon,
    required this.label,
    required this.value,
    super.key,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 42,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1D20),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: const Color(0xFF9FC5BA)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              '$label: $value',
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 13),
            ),
          ),
          const Icon(Icons.expand_more, size: 18, color: Color(0xFF8E9996)),
        ],
      ),
    );
  }
}

class ParticipantTile extends StatelessWidget {
  const ParticipantTile({required this.participant, super.key});

  final Participant participant;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 62,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: participant.speaking
            ? const Color(0xFF203B36)
            : const Color(0xFF1A1D20),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: participant.speaking
              ? const Color(0xFF55BCA4)
              : const Color(0xFF2A2F33),
        ),
      ),
      child: Row(
        children: [
          AvatarBadge(
            initials: participant.initials,
            color: participant.color,
            size: 42,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  participant.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w700),
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
          Icon(
            participant.status == 'Silenciado' ? Icons.mic_off : Icons.mic,
            size: 18,
            color: participant.status == 'Silenciado'
                ? const Color(0xFFDE706B)
                : const Color(0xFF80DFC8),
          ),
        ],
      ),
    );
  }
}

class VoiceControls extends StatelessWidget {
  const VoiceControls({super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: FilledButton.icon(
            onPressed: () {},
            icon: const Icon(Icons.mic),
            label: const Text('Aberto'),
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(42),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        IconToolButton(icon: Icons.headphones, label: 'Monitorar audio'),
      ],
    );
  }
}

class CenterColumn extends StatelessWidget {
  const CenterColumn({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: const [
        SizedBox(height: 164, child: SceneBanner()),
        SizedBox(height: 12),
        Expanded(child: ChatPanel()),
        SizedBox(height: 12),
        MessageComposer(),
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

class ChatPanel extends StatelessWidget {
  const ChatPanel({super.key});

  static const messages = [
    ChatMessage('Mestre', 'As tochas tremem quando a porta de pedra range.'),
    ChatMessage('Mira', '**Percepcao** para escutar do outro lado.'),
    ChatMessage('Darian', '1d20+4 = 17'),
    ChatMessage('Noctua', 'Seguro a lanterna e fico atras do escudo.'),
  ];

  @override
  Widget build(BuildContext context) {
    return Panel(
      title: 'Chat',
      trailing: Row(
        children: [
          const CounterBadge(text: '0/2000'),
          const SizedBox(width: 8),
          IconToolButton(icon: Icons.image, label: 'Enviar imagem'),
        ],
      ),
      child: ListView.separated(
        itemCount: messages.length,
        separatorBuilder: (_, _) => const SizedBox(height: 10),
        itemBuilder: (context, index) {
          return ChatBubble(message: messages[index]);
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
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AvatarBadge(
          initials: message.author.substring(0, 2).toUpperCase(),
          color: const Color(0xFF3E6B62),
          size: 34,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFF1A1D20),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFF2A2F33)),
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
                const SizedBox(height: 5),
                Text(message.text, style: const TextStyle(height: 1.35)),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class MessageComposer extends StatelessWidget {
  const MessageComposer({super.key});

  @override
  Widget build(BuildContext context) {
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
          IconToolButton(icon: Icons.add_photo_alternate, label: 'Anexar'),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              maxLines: 1,
              decoration: InputDecoration(
                hintText: 'Mensagem para a mesa',
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
          IconToolButton(icon: Icons.send, label: 'Enviar'),
        ],
      ),
    );
  }
}

class SideToolsPanel extends StatelessWidget {
  const SideToolsPanel({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: const [
        Expanded(flex: 3, child: MusicPanel()),
        SizedBox(height: 12),
        Expanded(flex: 2, child: DicePanel()),
        SizedBox(height: 12),
        SizedBox(height: 132, child: ProfilePanel()),
      ],
    );
  }
}

class MusicPanel extends StatelessWidget {
  const MusicPanel({super.key});

  @override
  Widget build(BuildContext context) {
    return Panel(
      title: 'Trilha',
      trailing: IconToolButton(icon: Icons.playlist_add, label: 'Adicionar'),
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
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Chuva nas muralhas',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                  SizedBox(height: 6),
                  LinearProgressIndicator(value: .38, minHeight: 5),
                  SizedBox(height: 8),
                  Text('01:14 / 03:12', style: TextStyle(fontSize: 12)),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                IconToolButton(icon: Icons.play_arrow, label: 'Tocar'),
                const SizedBox(width: 8),
                IconToolButton(icon: Icons.pause, label: 'Pausar'),
                const SizedBox(width: 8),
                IconToolButton(icon: Icons.stop, label: 'Parar'),
                const SizedBox(width: 8),
                IconToolButton(icon: Icons.repeat, label: 'Loop'),
              ],
            ),
            const SizedBox(height: 12),
            const TrackTile(
              title: 'Preview privado',
              subtitle: 'Somente mestre',
            ),
            const SizedBox(height: 8),
            const TrackTile(title: 'Combate curto', subtitle: 'Pronta'),
          ],
        ),
      ),
    );
  }
}

class TrackTile extends StatelessWidget {
  const TrackTile({required this.title, required this.subtitle, super.key});

  final String title;
  final String subtitle;

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
          const Icon(Icons.music_note, size: 18, color: Color(0xFFE6B450)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
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
    );
  }
}

class DicePanel extends StatelessWidget {
  const DicePanel({super.key});

  @override
  Widget build(BuildContext context) {
    return Panel(
      title: 'Dados',
      trailing: IconToolButton(icon: Icons.visibility_off, label: 'Ocultar'),
      child: SingleChildScrollView(
        child: Column(
          children: [
            Row(
              children: const [
                DiceChip(label: 'd4'),
                DiceChip(label: 'd6'),
                DiceChip(label: 'd8'),
                DiceChip(label: 'd20'),
              ],
            ),
            const SizedBox(height: 10),
            TextField(
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
            const SizedBox(height: 10),
            Container(
              height: 56,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: const Color(0xFF1A1D20),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                'Darian rolou 17',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class DiceChip extends StatelessWidget {
  const DiceChip({required this.label, super.key});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        height: 34,
        margin: const EdgeInsets.only(right: 6),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: const Color(0xFF223D38),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFF356F62)),
        ),
        child: Text(label, style: const TextStyle(fontWeight: FontWeight.w800)),
      ),
    );
  }
}

class ProfilePanel extends StatelessWidget {
  const ProfilePanel({super.key});

  @override
  Widget build(BuildContext context) {
    return Panel(
      title: 'Perfil',
      trailing: IconToolButton(icon: Icons.edit, label: 'Editar perfil'),
      child: Row(
        children: [
          const AvatarBadge(initials: 'RO', color: Color(0xFF55BCA4), size: 58),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text(
                  'Rogerin',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
                SizedBox(height: 4),
                Text(
                  'Banner: Vale Cinzento',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: Color(0xFFAEB8B5), fontSize: 12),
                ),
              ],
            ),
          ),
        ],
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
  const IconToolButton({required this.icon, required this.label, super.key});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: label,
      child: SizedBox(
        width: 38,
        height: 38,
        child: IconButton(
          onPressed: () {},
          icon: Icon(icon, size: 20),
          style: IconButton.styleFrom(
            backgroundColor: const Color(0xFF1A1D20),
            foregroundColor: const Color(0xFFDCE5E1),
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
  const CounterBadge({required this.text, super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 28,
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1D20),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(text, style: const TextStyle(fontSize: 12)),
    );
  }
}

class AvatarBadge extends StatelessWidget {
  const AvatarBadge({
    required this.initials,
    required this.color,
    required this.size,
    super.key,
  });

  final String initials;
  final Color color;
  final double size;

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
      child: Text(
        initials,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class Participant {
  const Participant(
    this.name,
    this.initials,
    this.status,
    this.color,
    this.speaking,
  );

  final String name;
  final String initials;
  final String status;
  final Color color;
  final bool speaking;
}

class ChatMessage {
  const ChatMessage(this.author, this.text);

  final String author;
  final String text;
}
