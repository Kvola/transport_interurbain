import 'package:flutter/material.dart';

import '../../models/booking.dart';
import '../../theme/app_theme.dart';

/// Formulaire pour saisir les informations d'un passager tiers
/// Utilisé lors de l'achat d'un billet pour quelqu'un d'autre
class OtherPassengerForm extends StatefulWidget {
  final OtherPassenger? initialData;
  final Function(OtherPassenger) onSaved;
  final VoidCallback? onCancel;

  const OtherPassengerForm({
    super.key,
    this.initialData,
    required this.onSaved,
    this.onCancel,
  });

  @override
  State<OtherPassengerForm> createState() => _OtherPassengerFormState();
}

class _OtherPassengerFormState extends State<OtherPassengerForm> {
  final _formKey = GlobalKey<FormState>();
  
  late TextEditingController _nameController;
  late TextEditingController _phoneController;
  late TextEditingController _emailController;
  late TextEditingController _idNumberController;
  
  String? _selectedIdType;
  
  final List<Map<String, String>> _idTypes = [
    {'value': 'cni', 'label': 'Carte Nationale d\'Identité'},
    {'value': 'passport', 'label': 'Passeport'},
    {'value': 'permis', 'label': 'Permis de conduire'},
    {'value': 'other', 'label': 'Autre pièce'},
  ];

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.initialData?.name ?? '');
    _phoneController = TextEditingController(text: widget.initialData?.phone ?? '');
    _emailController = TextEditingController(text: widget.initialData?.email ?? '');
    _idNumberController = TextEditingController(text: widget.initialData?.idNumber ?? '');
    _selectedIdType = widget.initialData?.idType;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _idNumberController.dispose();
    super.dispose();
  }

  void _saveForm() {
    if (_formKey.currentState!.validate()) {
      final passenger = OtherPassenger(
        name: _nameController.text.trim(),
        phone: _phoneController.text.trim(),
        email: _emailController.text.trim().isEmpty ? null : _emailController.text.trim(),
        idType: _selectedIdType,
        idNumber: _idNumberController.text.trim().isEmpty ? null : _idNumberController.text.trim(),
      );
      
      widget.onSaved(passenger);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // En-tête
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.person_add,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Informations du passager',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Entrez les coordonnées de la personne qui voyagera',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 24),
          
          // Nom complet *
          TextFormField(
            controller: _nameController,
            decoration: const InputDecoration(
              labelText: 'Nom complet *',
              hintText: 'Ex: Kouadio Jean',
              prefixIcon: Icon(Icons.person_outline),
            ),
            textCapitalization: TextCapitalization.words,
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Le nom est requis';
              }
              if (value.trim().length < 3) {
                return 'Le nom doit contenir au moins 3 caractères';
              }
              return null;
            },
          ),
          
          const SizedBox(height: 16),
          
          // Téléphone *
          TextFormField(
            controller: _phoneController,
            decoration: const InputDecoration(
              labelText: 'Numéro de téléphone *',
              hintText: 'Ex: 07 12 34 56 78',
              prefixIcon: Icon(Icons.phone_outlined),
              prefixText: '+225 ',
            ),
            keyboardType: TextInputType.phone,
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Le téléphone est requis';
              }
              final cleaned = value.replaceAll(RegExp(r'[\s\-\.]'), '');
              if (cleaned.length < 8) {
                return 'Numéro de téléphone invalide';
              }
              return null;
            },
          ),
          
          const SizedBox(height: 16),
          
          // Email (optionnel)
          TextFormField(
            controller: _emailController,
            decoration: const InputDecoration(
              labelText: 'Email (optionnel)',
              hintText: 'Ex: jean@email.com',
              prefixIcon: Icon(Icons.email_outlined),
            ),
            keyboardType: TextInputType.emailAddress,
            validator: (value) {
              if (value != null && value.isNotEmpty) {
                if (!RegExp(r'^[\w\-\.]+@([\w\-]+\.)+[\w\-]{2,4}$').hasMatch(value)) {
                  return 'Email invalide';
                }
              }
              return null;
            },
          ),
          
          const SizedBox(height: 24),
          
          // Séparateur
          Row(
            children: [
              const Expanded(child: Divider()),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  'Pièce d\'identité (optionnel)',
                  style: TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 12,
                  ),
                ),
              ),
              const Expanded(child: Divider()),
            ],
          ),
          
          const SizedBox(height: 16),
          
          // Type de pièce d'identité
          DropdownButtonFormField<String>(
            value: _selectedIdType,
            decoration: const InputDecoration(
              labelText: 'Type de pièce',
              prefixIcon: Icon(Icons.badge_outlined),
            ),
            items: _idTypes.map((type) {
              return DropdownMenuItem<String>(
                value: type['value'],
                child: Text(type['label']!),
              );
            }).toList(),
            onChanged: (value) {
              setState(() {
                _selectedIdType = value;
              });
            },
          ),
          
          const SizedBox(height: 16),
          
          // Numéro de pièce
          TextFormField(
            controller: _idNumberController,
            decoration: const InputDecoration(
              labelText: 'Numéro de pièce',
              hintText: 'Ex: CI123456789',
              prefixIcon: Icon(Icons.numbers),
            ),
            textCapitalization: TextCapitalization.characters,
          ),
          
          const SizedBox(height: 32),
          
          // Boutons d'action
          Row(
            children: [
              if (widget.onCancel != null)
                Expanded(
                  child: OutlinedButton(
                    onPressed: widget.onCancel,
                    child: const Text('Annuler'),
                  ),
                ),
              if (widget.onCancel != null)
                const SizedBox(width: 16),
              Expanded(
                flex: widget.onCancel != null ? 2 : 1,
                child: ElevatedButton.icon(
                  onPressed: _saveForm,
                  icon: const Icon(Icons.check),
                  label: const Text('Confirmer le passager'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Bottom sheet pour sélectionner le type de réservation
class BookingTypeSheet extends StatelessWidget {
  final VoidCallback onForSelf;
  final VoidCallback onForOther;

  const BookingTypeSheet({
    super.key,
    required this.onForSelf,
    required this.onForOther,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Indicateur
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          
          const SizedBox(height: 24),
          
          const Text(
            'Pour qui est ce billet ?',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          
          const SizedBox(height: 8),
          
          Text(
            'Choisissez si vous voyagez ou si vous achetez pour quelqu\'un d\'autre',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppTheme.textSecondary,
            ),
          ),
          
          const SizedBox(height: 32),
          
          // Option : Pour moi
          _BookingTypeOption(
            icon: Icons.person,
            title: 'Pour moi',
            subtitle: 'Je suis le voyageur',
            color: AppTheme.primaryColor,
            onTap: () {
              Navigator.pop(context);
              onForSelf();
            },
          ),
          
          const SizedBox(height: 16),
          
          // Option : Pour quelqu'un d'autre
          _BookingTypeOption(
            icon: Icons.people,
            title: 'Pour quelqu\'un d\'autre',
            subtitle: 'Ami, famille, collègue...',
            color: AppTheme.accentColor,
            onTap: () {
              Navigator.pop(context);
              onForOther();
            },
          ),
          
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

class _BookingTypeOption extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  const _BookingTypeOption({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: Border.all(color: color.withOpacity(0.3)),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 28),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 13,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios,
              color: color,
              size: 18,
            ),
          ],
        ),
      ),
    );
  }
}

/// Badge pour indiquer un achat pour tiers
class ForOtherBadge extends StatelessWidget {
  final String? passengerName;

  const ForOtherBadge({super.key, this.passengerName});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: AppTheme.accentColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.accentColor.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.card_giftcard,
            color: AppTheme.accentColor,
            size: 16,
          ),
          const SizedBox(width: 6),
          Text(
            passengerName != null 
                ? 'Pour: $passengerName' 
                : 'Achat pour un tiers',
            style: TextStyle(
              color: AppTheme.accentColor,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
