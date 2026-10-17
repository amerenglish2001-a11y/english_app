import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_tts/flutter_tts.dart';
import 'package:shared_preferences/shared_preferences.dart';

final FlutterTts tts = FlutterTts();
late SharedPreferences prefs;

Future<void> speak(String text) async {
  await tts.stop();
  await tts.setLanguage('en-US');
  await tts.setSpeechRate(0.45);
  await tts.speak(text);
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  prefs = await SharedPreferences.getInstance();
  runApp(const App());
}

// ---------- Data ----------
class Item {
  final String en, ku;
  Item(this.en, this.ku);
}

class Lesson {
  final String id, title;
  final List<Item> items;
  Lesson(this.id, this.title, this.items);
}

class Level {
  final String name;
  final List<Lesson> lessons;
  Level(this.name, this.lessons);
}

Future<List<Level>> loadLevels() async {
  final raw = jsonDecode(await rootBundle.loadString('assets/lessons.json'));
  return (raw['levels'] as List)
      .map((l) => Level(
            l['name'],
            (l['lessons'] as List)
                .map((s) => Lesson(
                      s['id'],
                      s['title'],
                      (s['items'] as List)
                          .map((i) => Item(i['en'], i['ku']))
                          .toList(),
                    ))
                .toList(),
          ))
      .toList();
}

// ---------- App ----------
class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'English',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(colorSchemeSeed: Colors.indigo, useMaterial3: true),
        builder: (c, w) =>
            Directionality(textDirection: TextDirection.rtl, child: w!),
        home: const Home(),
      );
}

// ---------- Home: levels and lessons ----------
class Home extends StatefulWidget {
  const Home({super.key});

  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> {
  late final Future<List<Level>> future = loadLevels();

  Widget score(Lesson ls) {
    final sc = prefs.getInt('score_${ls.id}');
    if (sc == null) return const Icon(Icons.chevron_left);
    return Text('⭐ $sc/${ls.items.length}');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('فێربوونی ئینگلیزی')),
      body: FutureBuilder<List<Level>>(
        future: future,
        builder: (c, s) {
          if (s.hasError) {
            return Center(child: Text('هەڵە لە lessons.json:\n${s.error}'));
          }
          if (!s.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final levels = s.data!;
          return ListView(
            children: [
              for (final lv in levels)
                ExpansionTile(
                  initiallyExpanded: lv == levels.first,
                  title: Text(lv.name,
                      style: const TextStyle(
                          fontSize: 18, fontWeight: FontWeight.bold)),
                  children: [
                    for (final ls in lv.lessons)
                      ListTile(
                        title: Text(ls.title),
                        subtitle: Text('${ls.items.length} وشە و ڕستە'),
                        trailing: score(ls),
                        onTap: () async {
                          await Navigator.push(
                              c,
                              MaterialPageRoute(
                                  builder: (_) => LessonPage(ls)));
                          setState(() {});
                        },
                      ),
                  ],
                ),
            ],
          );
        },
      ),
    );
  }
}

// ---------- Flashcards ----------
class LessonPage extends StatefulWidget {
  final Lesson lesson;
  const LessonPage(this.lesson, {super.key});

  @override
  State<LessonPage> createState() => _LessonPageState();
}

class _LessonPageState extends State<LessonPage> {
  int i = 0;
  bool show = false;

  @override
  Widget build(BuildContext context) {
    final items = widget.lesson.items;
    final it = items[i];
    final last = i == items.length - 1;
    return Scaffold(
      appBar: AppBar(title: Text(widget.lesson.title)),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            LinearProgressIndicator(value: (i + 1) / items.length),
            const SizedBox(height: 20),
            Expanded(
              child: GestureDetector(
                onTap: () => setState(() => show = !show),
                child: Card(
                  child: SizedBox(
                    width: double.infinity,
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(it.en,
                              textDirection: TextDirection.ltr,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                  fontSize: 30, fontWeight: FontWeight.bold)),
                          IconButton(
                              iconSize: 40,
                              icon: const Icon(Icons.volume_up),
                              onPressed: () => speak(it.en)),
                          const SizedBox(height: 16),
                          Text(show ? it.ku : 'دەستم لێ بدە بۆ واتا',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                  fontSize: 24,
                                  color: show ? null : Colors.grey)),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: i == 0
                        ? null
                        : () => setState(() {
                              i--;
                              show = false;
                            }),
                    child: const Text('پێشوو'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: () {
                      if (last) {
                        Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(
                                builder: (_) => QuizPage(widget.lesson)));
                      } else {
                        setState(() {
                          i++;
                          show = false;
                        });
                      }
                    },
                    child: Text(last ? 'تاقیکردنەوە' : 'دواتر'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ---------- Quiz ----------
class QuizPage extends StatefulWidget {
  final Lesson lesson;
  const QuizPage(this.lesson, {super.key});

  @override
  State<QuizPage> createState() => _QuizPageState();
}

class _QuizPageState extends State<QuizPage> {
  late final List<Item> qs = [...widget.lesson.items]..shuffle();
  int q = 0, score = 0;
  String? picked;
  late List<String> opts = makeOptions();

  List<String> makeOptions() {
    final right = qs[q].ku;
    final others = widget.lesson.items
        .map((e) => e.ku)
        .where((k) => k != right)
        .toList()
      ..shuffle();
    return [right, ...others.take(3)]..shuffle();
  }

  void pick(String o) {
    if (picked != null) return;
    setState(() {
      picked = o;
      if (o == qs[q].ku) score++;
    });
  }

  void next() {
    if (q == qs.length - 1) {
      final key = 'score_${widget.lesson.id}';
      if (score > (prefs.getInt(key) ?? 0)) prefs.setInt(key, score);
      setState(() => q = qs.length);
      return;
    }
    setState(() {
      q++;
      picked = null;
      opts = makeOptions();
    });
  }

  @override
  Widget build(BuildContext context) {
    if (q >= qs.length) {
      return Scaffold(
        appBar: AppBar(title: const Text('ئەنجام')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('$score / ${qs.length}',
                  textDirection: TextDirection.ltr,
                  style: const TextStyle(
                      fontSize: 48, fontWeight: FontWeight.bold)),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: () => Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                        builder: (_) => QuizPage(widget.lesson))),
                child: const Text('دووبارە'),
              ),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: () => Navigator.popUntil(context, (r) => r.isFirst),
                child: const Text('گەڕانەوە'),
              ),
            ],
          ),
        ),
      );
    }
    final item = qs[q];
    return Scaffold(
      appBar: AppBar(title: Text('پرسیار ${q + 1} / ${qs.length}')),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 12),
            Text(item.en,
                textDirection: TextDirection.ltr,
                textAlign: TextAlign.center,
                style:
                    const TextStyle(fontSize: 26, fontWeight: FontWeight.bold)),
            IconButton(
                iconSize: 36,
                icon: const Icon(Icons.volume_up),
                onPressed: () => speak(item.en)),
            const SizedBox(height: 12),
            for (final o in opts)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: FilledButton.tonal(
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.all(16),
                    backgroundColor: picked == null
                        ? null
                        : o == item.ku
                            ? Colors.green.shade200
                            : o == picked
                                ? Colors.red.shade200
                                : null,
                  ),
                  onPressed: () => pick(o),
                  child: Text(o, style: const TextStyle(fontSize: 18)),
                ),
              ),
            const Spacer(),
            if (picked != null)
              FilledButton(
                onPressed: next,
                child: Text(q == qs.length - 1 ? 'ئەنجام' : 'دواتر'),
              ),
          ],
        ),
      ),
    );
  }
}
