# -*- coding: utf-8 -*-
{
    'name': 'Transport Interurbain',
    'version': '17.0.1.0.1',
    'category': 'Transportation',
    'summary': 'Gestion des transports interurbains - Côte d\'Ivoire',
    'description': """
Transport Interurbain - Plateforme de Gestion
==============================================

Module complet de gestion des transports interurbains avec les fonctionnalités suivantes:

**Fonctionnalités Administrateurs:**
* Création et gestion des itinéraires de voyage
* Gestion des villes et arrêts intermédiaires
* Configuration des paramètres système

**Fonctionnalités Compagnies de Transport:**
* Programmation des voyages sur les itinéraires
* Gestion de la flotte de bus (places, capacité bagages)
* Définition des lieux de rassemblement
* Gestion des bagages (poids, type, volume)
* Tableau de bord et statistiques

**Fonctionnalités Usagers (Portail):**
* Consultation des compagnies et voyages disponibles
* Recherche par date et itinéraire
* Réservation temporaire (24h max)
* Achat de tickets (paiement Wave)
* Gestion des allers-retours
* Historique des voyages

**Calcul Dynamique des Places:**
* Disponibilité en temps réel selon les arrêts
* Optimisation du remplissage par segment

**Intégrations:**
* Paiement Wave
* Notifications SMS/Email
* QR Code pour validation embarquement
    """,
    'author': 'ICP',
    'website': 'https://www.icp.ci',
    'license': 'LGPL-3',
    'depends': [
        'base',
        'mail',
        'portal',
        'contacts',
        'web',
        'web_responsive',
        'website',
    ],
    'post_init_hook': 'post_init_hook',
    'uninstall_hook': 'uninstall_hook',
    'data': [
        # Security
        'security/transport_security.xml',
        'security/ir.model.access.csv',
        
        # Data
        'data/transport_sequence.xml',
        'data/transport_data.xml',
        'data/transport_demo_data.xml',
        
        # Views - Configuration
        'views/transport_city_views.xml',
        'views/transport_route_views.xml',
        
        # Views - Companies & Fleet
        'views/transport_company_views.xml',
        'views/transport_bus_views.xml',
        
        # Views - Operations
        'views/transport_trip_views.xml',
        'views/transport_booking_views.xml',
        'views/transport_passenger_views.xml',
        
        # Views - Schedules (Programmes)
        'views/transport_schedule_views.xml',
        
        # Views - Dashboard & Menus
        'views/transport_dashboard_views.xml',
        'views/transport_menus.xml',
        
        # Settings
        'views/res_config_settings_views.xml',
        
        # Portal
        'views/portal_templates.xml',
        
        # Ticket Share Templates
        'views/ticket_share_templates.xml',
        
        # Reports
        'reports/ticket_report.xml',
    ],
    'assets': {
        'web.assets_backend': [
            'transport_interurbain/static/src/css/transport_backend.css',
            'transport_interurbain/static/src/js/transport_admin_dashboard.js',
            'transport_interurbain/static/src/js/transport_company_dashboard.js',
            'transport_interurbain/static/src/xml/transport_dashboards.xml',
        ],
        'web.assets_frontend': [
            'transport_interurbain/static/src/css/transport_portal.css',
            'transport_interurbain/static/src/js/transport_portal.js',
        ],
    },
    'installable': True,
    'application': True,
    'auto_install': False,
    'sequence': 100,
}
