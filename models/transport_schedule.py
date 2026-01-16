# -*- coding: utf-8 -*-

from odoo import api, fields, models, _
from odoo.exceptions import ValidationError, UserError
from datetime import datetime, timedelta, time
import logging

_logger = logging.getLogger(__name__)


class TransportTripSchedule(models.Model):
    """Programme de voyages - Template pour générer des voyages récurrents"""
    _name = 'transport.trip.schedule'
    _description = 'Programme de voyages'
    _inherit = ['mail.thread', 'mail.activity.mixin']
    _order = 'name'

    name = fields.Char(
        string='Nom du programme',
        required=True,
        tracking=True,
        help="Ex: Ligne Express Abidjan-Bouaké",
    )
    code = fields.Char(
        string='Code',
        required=True,
        copy=False,
        readonly=True,
        default='/',
        index=True,
    )
    transport_company_id = fields.Many2one(
        'transport.company',
        string='Compagnie',
        required=True,
        tracking=True,
        ondelete='cascade',
    )
    route_id = fields.Many2one(
        'transport.route',
        string='Itinéraire',
        required=True,
        tracking=True,
        domain="[('state', '=', 'active')]",
    )
    
    # Bus par défaut
    default_bus_id = fields.Many2one(
        'transport.bus',
        string='Bus par défaut',
        tracking=True,
        domain="[('transport_company_id', '=', transport_company_id), ('state', '=', 'available')]",
        help="Bus utilisé par défaut pour les voyages générés",
    )
    
    # Lieu de rassemblement
    meeting_point = fields.Char(
        string='Lieu de rassemblement',
        required=True,
        tracking=True,
    )
    meeting_point_address = fields.Text(
        string='Adresse détaillée',
    )
    meeting_time_before = fields.Integer(
        string='Arrivée avant départ (min)',
        default=30,
    )
    
    # Tarification par défaut
    default_price = fields.Monetary(
        string='Prix standard',
        currency_field='currency_id',
        required=True,
        tracking=True,
    )
    default_vip_price = fields.Monetary(
        string='Prix VIP',
        currency_field='currency_id',
    )
    default_child_price = fields.Monetary(
        string='Prix enfant',
        currency_field='currency_id',
    )
    currency_id = fields.Many2one(
        related='transport_company_id.currency_id',
    )
    
    # Période de validité
    date_start = fields.Date(
        string='Date de début',
        required=True,
        default=fields.Date.today,
        tracking=True,
    )
    date_end = fields.Date(
        string='Date de fin',
        tracking=True,
        help="Laisser vide pour un programme permanent",
    )
    
    # Jours d'opération
    monday = fields.Boolean(string='Lundi', default=True)
    tuesday = fields.Boolean(string='Mardi', default=True)
    wednesday = fields.Boolean(string='Mercredi', default=True)
    thursday = fields.Boolean(string='Jeudi', default=True)
    friday = fields.Boolean(string='Vendredi', default=True)
    saturday = fields.Boolean(string='Samedi', default=True)
    sunday = fields.Boolean(string='Dimanche', default=True)
    
    # Type de récurrence
    schedule_type = fields.Selection([
        ('daily', 'Tous les jours sélectionnés'),
        ('weekly', 'Hebdomadaire'),
        ('custom', 'Personnalisé'),
    ], string='Type de programme', default='daily', required=True)
    
    # Lignes horaires
    line_ids = fields.One2many(
        'transport.trip.schedule.line',
        'schedule_id',
        string='Horaires de départ',
        copy=True,
    )
    
    # Gestion bagages
    manage_luggage = fields.Boolean(
        string='Gérer les bagages',
        default=True,
    )
    luggage_included_kg = fields.Float(
        string='Bagages inclus (kg)',
        default=25,
    )
    extra_luggage_price = fields.Monetary(
        string='Prix kg supplémentaire',
        currency_field='currency_id',
    )
    
    # Voyages générés
    trip_ids = fields.One2many(
        'transport.trip',
        'schedule_id',
        string='Voyages générés',
    )
    trip_count = fields.Integer(
        compute='_compute_trip_count',
        string='Nombre de voyages',
    )
    
    # État
    state = fields.Selection([
        ('draft', 'Brouillon'),
        ('active', 'Actif'),
        ('paused', 'En pause'),
        ('archived', 'Archivé'),
    ], string='État', default='draft', tracking=True, index=True)
    
    active = fields.Boolean(default=True)
    
    # Saisonnalité
    is_seasonal = fields.Boolean(
        string='Programme saisonnier',
        default=False,
    )
    season_type = fields.Selection([
        ('high', 'Haute saison'),
        ('low', 'Basse saison'),
        ('holiday', 'Vacances/Fêtes'),
    ], string='Type de saison')
    price_adjustment_percent = fields.Float(
        string='Ajustement prix (%)',
        default=0,
        help="Pourcentage d'ajustement du prix (positif = augmentation, négatif = réduction)",
    )
    
    # Notes
    notes = fields.Text(
        string='Notes internes',
    )
    passenger_info = fields.Html(
        string='Informations passagers',
    )
    
    # Statistiques
    last_generation_date = fields.Date(
        string='Dernière génération',
        readonly=True,
    )
    generated_trips_count = fields.Integer(
        string='Voyages générés (total)',
        readonly=True,
        default=0,
    )

    _sql_constraints = [
        ('code_uniq', 'UNIQUE(code)', 'Le code du programme doit être unique!'),
        ('date_check', 'CHECK(date_end IS NULL OR date_end >= date_start)',
         'La date de fin doit être postérieure à la date de début!'),
    ]

    @api.model_create_multi
    def create(self, vals_list):
        for vals in vals_list:
            if vals.get('code', '/') == '/':
                vals['code'] = self.env['ir.sequence'].next_by_code('transport.trip.schedule') or '/'
        return super().create(vals_list)

    @api.constrains('line_ids')
    def _check_lines(self):
        for schedule in self:
            if schedule.state == 'active' and not schedule.line_ids:
                raise ValidationError(_("Un programme actif doit avoir au moins un horaire de départ!"))

    @api.constrains('monday', 'tuesday', 'wednesday', 'thursday', 'friday', 'saturday', 'sunday')
    def _check_days(self):
        for schedule in self:
            if not any([schedule.monday, schedule.tuesday, schedule.wednesday, 
                       schedule.thursday, schedule.friday, schedule.saturday, schedule.sunday]):
                raise ValidationError(_("Vous devez sélectionner au moins un jour d'opération!"))

    def _compute_trip_count(self):
        for schedule in self:
            schedule.trip_count = len(schedule.trip_ids)

    def _get_operating_days(self):
        """Retourne la liste des jours d'opération (0=lundi, 6=dimanche)"""
        self.ensure_one()
        days = []
        if self.monday: days.append(0)
        if self.tuesday: days.append(1)
        if self.wednesday: days.append(2)
        if self.thursday: days.append(3)
        if self.friday: days.append(4)
        if self.saturday: days.append(5)
        if self.sunday: days.append(6)
        return days

    def _get_adjusted_price(self, base_price):
        """Calcule le prix ajusté selon la saisonnalité"""
        self.ensure_one()
        if self.is_seasonal and self.price_adjustment_percent:
            adjustment = base_price * (self.price_adjustment_percent / 100)
            return base_price + adjustment
        return base_price

    def action_activate(self):
        """Activer le programme"""
        for schedule in self:
            if not schedule.line_ids:
                raise UserError(_("Ajoutez au moins un horaire de départ avant d'activer le programme!"))
            if not schedule.default_bus_id:
                raise UserError(_("Sélectionnez un bus par défaut avant d'activer le programme!"))
        self.write({'state': 'active'})

    def action_pause(self):
        """Mettre en pause le programme"""
        self.write({'state': 'paused'})

    def action_archive(self):
        """Archiver le programme"""
        self.write({'state': 'archived', 'active': False})

    def action_draft(self):
        """Repasser en brouillon"""
        self.write({'state': 'draft'})

    def action_generate_trips_wizard(self):
        """Ouvrir le wizard de génération de voyages"""
        self.ensure_one()
        return {
            'type': 'ir.actions.act_window',
            'name': _('Générer les voyages'),
            'res_model': 'transport.trip.generate.wizard',
            'view_mode': 'form',
            'target': 'new',
            'context': {
                'default_schedule_id': self.id,
                'default_date_from': fields.Date.today(),
                'default_date_to': fields.Date.today() + timedelta(days=30),
            },
        }

    def generate_trips(self, date_from, date_to, skip_existing=True):
        """
        Générer les voyages pour la période donnée.
        
        :param date_from: Date de début de génération
        :param date_to: Date de fin de génération
        :param skip_existing: Si True, ne pas créer de voyage si un existe déjà pour ce créneau
        :return: Recordset des voyages créés
        """
        self.ensure_one()
        
        if self.state != 'active':
            raise UserError(_("Le programme doit être actif pour générer des voyages!"))
        
        Trip = self.env['transport.trip']
        created_trips = Trip
        operating_days = self._get_operating_days()
        
        current_date = date_from
        while current_date <= date_to:
            # Vérifier si ce jour est un jour d'opération
            if current_date.weekday() in operating_days:
                # Vérifier les limites du programme
                if self.date_start and current_date < self.date_start:
                    current_date += timedelta(days=1)
                    continue
                if self.date_end and current_date > self.date_end:
                    break
                
                # Générer un voyage pour chaque ligne horaire
                for line in self.line_ids:
                    # Calculer l'heure de départ
                    departure_datetime = datetime.combine(
                        current_date,
                        time(hour=int(line.departure_hour), minute=int((line.departure_hour % 1) * 60))
                    )
                    
                    # Vérifier si un voyage existe déjà
                    if skip_existing:
                        existing = Trip.search([
                            ('schedule_id', '=', self.id),
                            ('departure_datetime', '=', departure_datetime),
                        ], limit=1)
                        if existing:
                            continue
                    
                    # Déterminer le bus et le prix
                    bus = line.bus_id or self.default_bus_id
                    price = line.price or self._get_adjusted_price(self.default_price)
                    vip_price = line.vip_price or self._get_adjusted_price(self.default_vip_price or 0)
                    child_price = line.child_price or self._get_adjusted_price(self.default_child_price or 0)
                    
                    # Créer le voyage
                    trip = Trip.create({
                        'transport_company_id': self.transport_company_id.id,
                        'route_id': self.route_id.id,
                        'bus_id': bus.id,
                        'schedule_id': self.id,
                        'departure_datetime': departure_datetime,
                        'meeting_point': self.meeting_point,
                        'meeting_point_address': self.meeting_point_address,
                        'meeting_time_before': self.meeting_time_before,
                        'price': price,
                        'vip_price': vip_price,
                        'child_price': child_price,
                        'manage_luggage': self.manage_luggage,
                        'luggage_included_kg': self.luggage_included_kg,
                        'extra_luggage_price': self.extra_luggage_price,
                        'passenger_info': self.passenger_info,
                        'state': 'scheduled',
                        'is_published': True,
                        'driver_name': line.driver_name,
                        'driver_phone': line.driver_phone,
                    })
                    created_trips |= trip
            
            current_date += timedelta(days=1)
        
        # Mettre à jour les statistiques
        self.write({
            'last_generation_date': fields.Date.today(),
            'generated_trips_count': self.generated_trips_count + len(created_trips),
        })
        
        _logger.info("Programme %s: %d voyages générés du %s au %s", 
                     self.name, len(created_trips), date_from, date_to)
        
        return created_trips

    def action_view_trips(self):
        """Voir les voyages générés par ce programme"""
        self.ensure_one()
        return {
            'type': 'ir.actions.act_window',
            'name': _('Voyages - %s') % self.name,
            'res_model': 'transport.trip',
            'view_mode': 'tree,form,calendar',
            'domain': [('schedule_id', '=', self.id)],
            'context': {'default_schedule_id': self.id},
        }

    def copy(self, default=None):
        """Dupliquer le programme avec un nouveau nom"""
        self.ensure_one()
        default = dict(default or {})
        default['name'] = _('%s (copie)') % self.name
        default['state'] = 'draft'
        default['last_generation_date'] = False
        default['generated_trips_count'] = 0
        return super().copy(default)


class TransportTripScheduleLine(models.Model):
    """Ligne horaire d'un programme de voyages"""
    _name = 'transport.trip.schedule.line'
    _description = 'Horaire de départ'
    _order = 'departure_hour'

    schedule_id = fields.Many2one(
        'transport.trip.schedule',
        string='Programme',
        required=True,
        ondelete='cascade',
    )
    sequence = fields.Integer(
        string='Séquence',
        default=10,
    )
    
    # Heure de départ
    departure_hour = fields.Float(
        string='Heure de départ',
        required=True,
        help="Format décimal: 6.5 = 6h30, 14.25 = 14h15",
    )
    departure_time_display = fields.Char(
        string='Heure',
        compute='_compute_departure_time_display',
    )
    
    # Surcharges optionnelles
    bus_id = fields.Many2one(
        'transport.bus',
        string='Bus spécifique',
        domain="[('transport_company_id', '=', parent.transport_company_id), ('state', '=', 'available')]",
        help="Laisser vide pour utiliser le bus par défaut du programme",
    )
    price = fields.Monetary(
        string='Prix spécifique',
        currency_field='currency_id',
        help="Laisser vide pour utiliser le prix par défaut",
    )
    vip_price = fields.Monetary(
        string='Prix VIP spécifique',
        currency_field='currency_id',
    )
    child_price = fields.Monetary(
        string='Prix enfant spécifique',
        currency_field='currency_id',
    )
    currency_id = fields.Many2one(
        related='schedule_id.currency_id',
    )
    
    # Conducteur
    driver_name = fields.Char(
        string='Conducteur',
    )
    driver_phone = fields.Char(
        string='Téléphone conducteur',
    )
    
    # Libellé
    label = fields.Char(
        string='Libellé',
        help="Ex: Départ matinal, Express, etc.",
    )
    
    active = fields.Boolean(
        default=True,
    )

    _sql_constraints = [
        ('departure_hour_check', 'CHECK(departure_hour >= 0 AND departure_hour < 24)',
         "L'heure de départ doit être entre 0 et 24!"),
        ('unique_schedule_hour', 'UNIQUE(schedule_id, departure_hour)',
         "Cet horaire existe déjà dans ce programme!"),
    ]

    @api.depends('departure_hour')
    def _compute_departure_time_display(self):
        for line in self:
            hours = int(line.departure_hour)
            minutes = int((line.departure_hour % 1) * 60)
            line.departure_time_display = f"{hours:02d}:{minutes:02d}"

    @api.constrains('departure_hour')
    def _check_departure_hour(self):
        for line in self:
            if line.departure_hour < 0 or line.departure_hour >= 24:
                raise ValidationError(_("L'heure de départ doit être entre 00:00 et 23:59!"))

    def name_get(self):
        result = []
        for line in self:
            name = line.departure_time_display
            if line.label:
                name = f"{name} - {line.label}"
            result.append((line.id, name))
        return result
