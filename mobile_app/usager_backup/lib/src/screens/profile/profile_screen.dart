import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../providers/auth_provider.dart';
import '../../theme/app_theme.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _notificationsEnabled = true;
  bool _smsNotifications = true;

  @override
  void initState() {
    super.initState();
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _notificationsEnabled = prefs.getBool('notifications_enabled') ?? true;
      _smsNotifications = prefs.getBool('sms_notifications') ?? true;
    });
  }

  Future<void> _savePreference(String key, bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(key, value);
  }

  Future<void> _logout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Déconnexion'),
        content: const Text('Êtes-vous sûr de vouloir vous déconnecter?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.errorColor,
            ),
            child: const Text('Déconnecter'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      await authProvider.logout();
      
      if (mounted) {
        Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mon profil'),
      ),
      body: Consumer<AuthProvider>(
        builder: (context, authProvider, _) {
          final passenger = authProvider.currentPassenger;

          if (passenger == null) {
            return const Center(
              child: Text('Veuillez vous connecter'),
            );
          }

          return SingleChildScrollView(
            child: Column(
              children: [
                // En-tête du profil
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(24),
                  decoration: const BoxDecoration(
                    color: AppTheme.primaryColor,
                  ),
                  child: Column(
                    children: [
                      CircleAvatar(
                        radius: 50,
                        backgroundColor: Colors.white,
                        child: Text(
                          passenger.name.isNotEmpty
                              ? passenger.name.substring(0, 1).toUpperCase()
                              : '?',
                          style: const TextStyle(
                            fontSize: 40,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.primaryColor,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        passenger.name,
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        passenger.phone,
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.8),
                          fontSize: 16,
                        ),
                      ),
                      if (passenger.email != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          passenger.email!,
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.8),
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),

                // Sections
                const SizedBox(height: 16),

                // Informations personnelles
                _SectionCard(
                  title: 'Informations personnelles',
                  children: [
                    _ProfileItem(
                      icon: Icons.person,
                      title: 'Nom complet',
                      value: passenger.name,
                      onTap: () => _editField(context, 'name', passenger.name),
                    ),
                    _ProfileItem(
                      icon: Icons.phone,
                      title: 'Téléphone',
                      value: passenger.phone,
                      showArrow: false,
                    ),
                    _ProfileItem(
                      icon: Icons.email,
                      title: 'Email',
                      value: passenger.email ?? 'Non renseigné',
                      onTap: () => _editField(context, 'email', passenger.email ?? ''),
                    ),
                    if (passenger.idNumber != null)
                      _ProfileItem(
                        icon: Icons.badge,
                        title: 'N° Pièce d\'identité',
                        value: passenger.idNumber!,
                        showArrow: false,
                      ),
                  ],
                ),

                // Statistiques
                _SectionCard(
                  title: 'Mes statistiques',
                  children: [
                    _ProfileItem(
                      icon: Icons.confirmation_number,
                      title: 'Total voyages',
                      value: '${passenger.totalTrips ?? 0} voyage(s)',
                      showArrow: false,
                    ),
                    _ProfileItem(
                      icon: Icons.calendar_today,
                      title: 'Membre depuis',
                      value: passenger.memberSince ?? '-',
                      showArrow: false,
                    ),
                  ],
                ),

                // Notifications
                _SectionCard(
                  title: 'Notifications',
                  children: [
                    _SwitchItem(
                      icon: Icons.notifications,
                      title: 'Notifications push',
                      value: _notificationsEnabled,
                      onChanged: (value) {
                        setState(() => _notificationsEnabled = value);
                        _savePreference('notifications_enabled', value);
                      },
                    ),
                    _SwitchItem(
                      icon: Icons.sms,
                      title: 'Notifications SMS',
                      value: _smsNotifications,
                      onChanged: (value) {
                        setState(() => _smsNotifications = value);
                        _savePreference('sms_notifications', value);
                      },
                    ),
                  ],
                ),

                // Sécurité
                _SectionCard(
                  title: 'Sécurité',
                  children: [
                    _ProfileItem(
                      icon: Icons.lock,
                      title: 'Modifier mon code PIN',
                      onTap: () => _changePin(context),
                    ),
                  ],
                ),

                // Support
                _SectionCard(
                  title: 'Support',
                  children: [
                    _ProfileItem(
                      icon: Icons.help,
                      title: 'Aide et FAQ',
                      onTap: () {
                        Navigator.pushNamed(context, '/help');
                      },
                    ),
                    _ProfileItem(
                      icon: Icons.description,
                      title: 'Conditions d\'utilisation',
                      onTap: () {
                        Navigator.pushNamed(context, '/terms');
                      },
                    ),
                    _ProfileItem(
                      icon: Icons.privacy_tip,
                      title: 'Politique de confidentialité',
                      onTap: () {
                        Navigator.pushNamed(context, '/privacy');
                      },
                    ),
                    _ProfileItem(
                      icon: Icons.info,
                      title: 'À propos',
                      value: 'Version 1.0.0',
                      showArrow: false,
                    ),
                  ],
                ),

                // Bouton de déconnexion
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _logout,
                      icon: const Icon(Icons.logout, color: AppTheme.errorColor),
                      label: const Text(
                        'Déconnexion',
                        style: TextStyle(color: AppTheme.errorColor),
                      ),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        side: const BorderSide(color: AppTheme.errorColor),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 32),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _editField(BuildContext context, String field, String currentValue) async {
    final controller = TextEditingController(text: currentValue);
    
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Modifier ${field == 'name' ? 'le nom' : 'l\'email'}'),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(
            labelText: field == 'name' ? 'Nom complet' : 'Email',
          ),
          keyboardType: field == 'email' ? TextInputType.emailAddress : TextInputType.text,
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('Enregistrer'),
          ),
        ],
      ),
    );

    if (result != null && result.isNotEmpty && mounted) {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final success = await authProvider.updateProfile({field: result});
      
      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profil mis à jour'),
            backgroundColor: Colors.green,
          ),
        );
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(authProvider.error ?? 'Erreur lors de la mise à jour'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    }
  }

  Future<void> _changePin(BuildContext context) async {
    final currentPinController = TextEditingController();
    final newPinController = TextEditingController();
    final confirmPinController = TextEditingController();

    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Modifier le code PIN'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: currentPinController,
              decoration: const InputDecoration(
                labelText: 'Code PIN actuel',
              ),
              obscureText: true,
              keyboardType: TextInputType.number,
              maxLength: 4,
            ),
            TextField(
              controller: newPinController,
              decoration: const InputDecoration(
                labelText: 'Nouveau code PIN',
              ),
              obscureText: true,
              keyboardType: TextInputType.number,
              maxLength: 4,
            ),
            TextField(
              controller: confirmPinController,
              decoration: const InputDecoration(
                labelText: 'Confirmer le code PIN',
              ),
              obscureText: true,
              keyboardType: TextInputType.number,
              maxLength: 4,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () {
              if (newPinController.text != confirmPinController.text) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Les codes PIN ne correspondent pas'),
                    backgroundColor: AppTheme.errorColor,
                  ),
                );
                return;
              }
              Navigator.pop(context, {
                'current_pin': currentPinController.text,
                'new_pin': newPinController.text,
              });
            },
            child: const Text('Modifier'),
          ),
        ],
      ),
    );

    if (result != null && mounted) {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final success = await authProvider.changePin(
        result['current_pin']!,
        result['new_pin']!,
      );

      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Code PIN modifié avec succès'),
            backgroundColor: Colors.green,
          ),
        );
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(authProvider.error ?? 'Erreur lors de la modification'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    }
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const _SectionCard({
    required this.title,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text(
              title,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppTheme.primaryColor,
              ),
            ),
          ),
          ...children,
        ],
      ),
    );
  }
}

class _ProfileItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? value;
  final VoidCallback? onTap;
  final bool showArrow;

  const _ProfileItem({
    required this.icon,
    required this.title,
    this.value,
    this.onTap,
    this.showArrow = true,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: AppTheme.primaryColor),
      title: Text(title),
      subtitle: value != null ? Text(value!) : null,
      trailing: showArrow && onTap != null
          ? const Icon(Icons.chevron_right)
          : null,
      onTap: onTap,
    );
  }
}

class _SwitchItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _SwitchItem({
    required this.icon,
    required this.title,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: AppTheme.primaryColor),
      title: Text(title),
      trailing: Switch(
        value: value,
        onChanged: onChanged,
        activeColor: AppTheme.primaryColor,
      ),
    );
  }
}
