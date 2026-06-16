import 'package:flutter/material.dart';
import '../models/user_event.dart';
import '../services/events_service.dart';
import '../services/settings_service.dart';

class EventsScreen extends StatefulWidget {
  const EventsScreen({super.key});

  @override
  State<EventsScreen> createState() => _EventsScreenState();
}

class _EventsScreenState extends State<EventsScreen> {
  final _eventsService = EventsService();
  List<UserEvent> _events = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadEvents();
  }

  Future<void> _loadEvents() async {
    setState(() => _isLoading = true);
    final events = await _eventsService.getEvents();
    setState(() {
      _events = events;
      _isLoading = false;
    });
  }

  void _showEventForm([UserEvent? existingEvent]) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: _EventForm(
          existingEvent: existingEvent,
          onSaved: (event) async {
            if (existingEvent == null) {
              await _eventsService.saveEvent(event);
            } else {
              await _eventsService.updateEvent(event);
            }
            _loadEvents();
          },
        ),
      ),
    );
  }

  Future<void> _deleteEvent(String id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Usuń zdarzenie"),
        content: const Text("Czy na pewno chcesz usunąć ten wpis?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("Anuluj")),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text("Usuń", style: TextStyle(color: Colors.red))),
        ],
      ),
    );

    if (confirm == true) {
      await _eventsService.deleteEvent(id);
      _loadEvents();
    }
  }

  Widget _buildEventIcon(EventType type) {
    switch (type) {
      case EventType.bg: return const CircleAvatar(backgroundColor: Colors.teal, child: Icon(Icons.water_drop, color: Colors.white));
      case EventType.insulin: return const CircleAvatar(backgroundColor: Colors.blueAccent, child: Icon(Icons.vaccines, color: Colors.white));
      case EventType.carbs: return const CircleAvatar(backgroundColor: Colors.orangeAccent, child: Icon(Icons.restaurant, color: Colors.white));
      case EventType.note: return const CircleAvatar(backgroundColor: Colors.grey, child: Icon(Icons.notes, color: Colors.white));
      case EventType.hypo: return const CircleAvatar(backgroundColor: Colors.red, child: Icon(Icons.warning_amber_rounded, color: Colors.white));
      case EventType.hyper: return const CircleAvatar(backgroundColor: Colors.amber, child: Icon(Icons.trending_up, color: Colors.white));
    }
  }

  String _getEventTitle(UserEvent e, bool isMmol) {
    if (e.type == EventType.note) return "Notatka";
    if (e.type == EventType.hypo) return "Epizod Hipoglikemii";
    if (e.type == EventType.hyper) return "Epizod Hiperglikemii";
    if (e.value == null) return "Brak danych";
    
    switch (e.type) {
      case EventType.bg: 
        if (isMmol) return "${(e.value! / 18.0).toStringAsFixed(1)} mmol/L";
        return "${e.value!.toInt()} mg/dL";
      case EventType.insulin: return "${e.value} j.";
      case EventType.carbs: return "${e.value!.toInt()} g";
      default: return "";
    }
  }

  String _formatDateStr(UserEvent e) {
    final startStr = "${e.timestamp.day.toString().padLeft(2,'0')}.${e.timestamp.month.toString().padLeft(2,'0')} ${e.timestamp.hour.toString().padLeft(2,'0')}:${e.timestamp.minute.toString().padLeft(2,'0')}";
    
    if (e.type == EventType.hypo || e.type == EventType.hyper) {
      if (e.endTime != null) {
        final endStr = "${e.endTime!.hour.toString().padLeft(2,'0')}:${e.endTime!.minute.toString().padLeft(2,'0')}";
        return "Od: $startStr  Do: $endStr";
      } else {
        return "Od: $startStr";
      }
    }
    return startStr;
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: SettingsService().isMmolLNotifier,
      builder: (context, isMmol, child) {
        return Scaffold(
          appBar: AppBar(
            title: const Text("Wydarzenia i notatki"),
            centerTitle: true,
            actions: [
              IconButton(icon: const Icon(Icons.add, size: 28), onPressed: () => _showEventForm()),
            ],
          ),
          body: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _events.isEmpty
                  ? const Center(child: Text("Brak wpisów z ostatnich 30 dni.", style: TextStyle(color: Colors.grey)))
                  : ListView.builder(
                      itemCount: _events.length,
                      itemBuilder: (context, index) {
                        final e = _events[index];
                        return Card(
                          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          color: (e.type == EventType.hypo || e.type == EventType.hyper) && e.endTime == null 
                              ? Colors.red.withOpacity(0.05) : Colors.white,
                          child: ListTile(
                            leading: _buildEventIcon(e.type),
                            title: Text(_getEventTitle(e, isMmol), style: const TextStyle(fontWeight: FontWeight.bold)),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(_formatDateStr(e), style: TextStyle(
                                  fontSize: 12, 
                                  color: e.endTime == null && (e.type == EventType.hypo || e.type == EventType.hyper) ? Colors.redAccent : Colors.grey,
                                  fontWeight: e.endTime == null ? FontWeight.bold : FontWeight.normal,
                                )),
                                if (e.note != null && e.note!.isNotEmpty)
                                  Text(e.note!, style: const TextStyle(fontStyle: FontStyle.italic)),
                              ],
                            ),
                            trailing: e.isEditable ? PopupMenuButton<String>(
                              onSelected: (val) {
                                if (val == 'edit') _showEventForm(e);
                                if (val == 'delete') _deleteEvent(e.id);
                              },
                              itemBuilder: (ctx) => [
                                const PopupMenuItem(value: 'edit', child: Text("Edytuj")),
                                const PopupMenuItem(value: 'delete', child: Text("Usuń", style: TextStyle(color: Colors.red))),
                              ],
                            ) : const SizedBox.shrink(),
                          ),
                        );
                      },
                    ),
        );
      }
    );
  }
}

class _EventForm extends StatefulWidget {
  final UserEvent? existingEvent;
  final Function(UserEvent) onSaved;

  const _EventForm({this.existingEvent, required this.onSaved});

  @override
  State<_EventForm> createState() => _EventFormState();
}

class _EventFormState extends State<_EventForm> {
  late EventType _selectedType;
  late DateTime _selectedTime;
  final _valueController = TextEditingController();
  final _noteController = TextEditingController();

  @override
  void initState() {
    super.initState();
    final isMmol = SettingsService().isMmolL;

    if (widget.existingEvent != null) {
      _selectedType = widget.existingEvent!.type;
      _selectedTime = widget.existingEvent!.timestamp;
      
      if (_selectedType == EventType.bg && widget.existingEvent!.value != null) {
        if (isMmol) {
          _valueController.text = (widget.existingEvent!.value! / 18.0).toStringAsFixed(1);
        } else {
          _valueController.text = widget.existingEvent!.value!.toInt().toString();
        }
      } else {
        _valueController.text = widget.existingEvent!.value?.toString() ?? "";
      }
      _noteController.text = widget.existingEvent!.note ?? "";
    } else {
      _selectedType = EventType.bg;
      _selectedTime = DateTime.now();
    }
  }

  Future<void> _pickDateTime() async {
    final now = DateTime.now();
    final DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: _selectedTime.isBefore(now) ? _selectedTime : now,
      firstDate: now.subtract(const Duration(days: 30)),
      lastDate: now,
    );

    if (pickedDate == null || !context.mounted) return;

    final TimeOfDay? pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_selectedTime),
    );

    if (pickedTime == null) return;

    final selectedDateTime = DateTime(pickedDate.year, pickedDate.month, pickedDate.day, pickedTime.hour, pickedTime.minute);

    if (selectedDateTime.isAfter(now)) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Nie możesz zapisać zdarzenia z przyszłości!"), backgroundColor: Colors.redAccent));
      return;
    }

    setState(() => _selectedTime = selectedDateTime);
  }

  void _submit() {
    double? val = double.tryParse(_valueController.text.replaceAll(',', '.'));
    
    if (val != null && _selectedType == EventType.bg && SettingsService().isMmolL) {
      val = val * 18.0; 
    }

    final newEvent = UserEvent(
      id: widget.existingEvent?.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
      timestamp: _selectedTime,
      type: _selectedType,
      value: val,
      note: _noteController.text.trim(),
      isEditable: true,
    );

    widget.onSaved(newEvent);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final isMmol = SettingsService().isMmolL;

    return Padding(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(widget.existingEvent == null ? "Nowe zdarzenie" : "Edytuj zdarzenie", style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          DropdownButtonFormField<EventType>(
            value: _selectedType,
            decoration: const InputDecoration(labelText: "Rodzaj wpisu", border: OutlineInputBorder()),
            items: const [
              DropdownMenuItem(value: EventType.bg, child: Text("Glikemia (Glukometr)")),
              DropdownMenuItem(value: EventType.insulin, child: Text("Insulina")),
              DropdownMenuItem(value: EventType.carbs, child: Text("Posiłek (Węglowodany)")),
              DropdownMenuItem(value: EventType.note, child: Text("Tylko notatka")),
            ],
            onChanged: (val) => setState(() {
              _selectedType = val!;
              _valueController.clear();
            }),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Text(
                  "Data: ${_selectedTime.day.toString().padLeft(2,'0')}.${_selectedTime.month.toString().padLeft(2,'0')} "
                  "${_selectedTime.hour.toString().padLeft(2,'0')}:${_selectedTime.minute.toString().padLeft(2,'0')}",
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
                ),
              ),
              OutlinedButton.icon(onPressed: _pickDateTime, icon: const Icon(Icons.calendar_month, size: 18), label: const Text("Zmień")),
            ],
          ),
          const SizedBox(height: 12),
          if (_selectedType != EventType.note)
            TextField(
              controller: _valueController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: "Wartość",
                hintText: _selectedType == EventType.bg ? (isMmol ? "np. 5.5" : "np. 120") : _selectedType == EventType.carbs ? "np. 45" : "np. 6.5",
                border: const OutlineInputBorder(),
              ),
            ),
          const SizedBox(height: 16),
          TextField(
            controller: _noteController,
            textCapitalization: TextCapitalization.sentences,
            maxLength: 300,
            decoration: const InputDecoration(labelText: "Notatka (Opcjonalna)", border: OutlineInputBorder()),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            height: 45,
            child: ElevatedButton(
              onPressed: _submit,
              style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent, foregroundColor: Colors.white),
              child: const Text("ZAPISZ"),
            ),
          )
        ],
      ),
    );
  }
}